import Foundation
import SwiftUI

@MainActor
final class LutShopAppState: ObservableObject {
    @Published var selectedTab: MainTab = .gallery
    @Published var activeFilter: PhotoStatus?
    @Published var showFavoritesOnly = false
    @Published var searchText = ""
    @Published var isSelectionMode = false
    @Published var selectedSessionName: String?
    @Published var photoSortOption: PhotoSortOption = .fileName
    @Published var selectedPhotoId: String?
    @Published var activeLutId: String?
    @Published var lutIntensity = 0.72
    @Published var previewCompareEnabled = true
    @Published var previewComparePosition = 0.5
    @Published var exportSettings = ExportSettings()
    @Published var isImportingPhotos = false
    @Published var importMessage: String?
    @Published private(set) var sessions: [String]
    @Published private(set) var photos: [Photo]
    @Published private(set) var luts: [LutPreset]

    private let bridge: LutShopCoreBridge
    private var importedBatchCount = 0

    init(bridge: LutShopCoreBridge = MockLutShopCoreBridge()) {
        self.bridge = bridge
        let initialPhotos = bridge.loadInitialPhotos()
        self.photos = initialPhotos
        self.sessions = Array(Set(initialPhotos.map(\.sessionName))).sorted()
        self.luts = bridge.loadLuts()
        self.selectedPhotoId = photos.first?.id
        self.activeLutId = luts.first?.id
    }

    var filteredPhotos: [Photo] {
        let filtered = photos.filter { photo in
            let matchesFilter = activeFilter == nil || photo.status == activeFilter
            let matchesFavorite = !showFavoritesOnly || photo.isFavorite
            let matchesSession = selectedSessionName == nil || photo.sessionName == selectedSessionName
            let matchesSearch = searchText.isEmpty
                || photo.fileName.localizedCaseInsensitiveContains(searchText)
                || photo.sessionName.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesFavorite && matchesSession && matchesSearch
        }

        switch photoSortOption {
        case .fileName:
            return filtered.sorted { $0.fileName < $1.fileName }
        case .newest:
            return filtered.sorted { $0.id > $1.id }
        case .rating:
            return filtered.sorted {
                if $0.rating == $1.rating {
                    return $0.fileName < $1.fileName
                }
                return $0.rating > $1.rating
            }
        case .status:
            return filtered.sorted {
                if $0.status.rawValue == $1.status.rawValue {
                    return $0.fileName < $1.fileName
                }
                return $0.status.rawValue < $1.status.rawValue
            }
        }
    }

    var sessionNames: [String] {
        sessions
    }

    var selectedPhotos: [Photo] {
        photos.filter(\.isSelected)
    }

    var totalPhotoCount: Int {
        photos.count
    }

    var visiblePhotoCount: Int {
        filteredPhotos.count
    }

    var selectedSessionPhotoCount: Int {
        guard let selectedSessionName else { return photos.count }
        return photos.filter { $0.sessionName == selectedSessionName }.count
    }

    func photoCount(in sessionName: String) -> Int {
        photos.filter { $0.sessionName == sessionName }.count
    }

    func canDeleteSession(named sessionName: String) -> Bool {
        sessions.contains(sessionName) && photoCount(in: sessionName) == 0
    }

    var currentPhoto: Photo? {
        photos.first { $0.id == selectedPhotoId } ?? photos.first
    }

    var activeLut: LutPreset? {
        luts.first { $0.id == activeLutId } ?? luts.first
    }

    var recommendedLuts: [LutPreset] {
        guard let currentPhoto else { return [] }
        return bridge.recommendLuts(for: currentPhoto, from: luts)
    }

    func selectPhoto(_ id: String) {
        selectedPhotoId = id
        selectedTab = .preview
    }

    func openOrTogglePhoto(_ id: String) {
        if isSelectionMode {
            toggleSelection(id)
        } else {
            selectPhoto(id)
        }
    }

    func setPreviewComparePosition(_ value: Double) {
        previewComparePosition = min(max(value, 0.08), 0.92)
    }

    func toggleSelection(_ id: String) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        photos[index].isSelected.toggle()
        selectedPhotoId = id
        isSelectionMode = true
    }

    func clearSelection() {
        for index in photos.indices {
            photos[index].isSelected = false
        }
        isSelectionMode = false
    }

    func setStatusFilter(_ status: PhotoStatus?, favoritesOnly: Bool = false) {
        activeFilter = status
        showFavoritesOnly = favoritesOnly
    }

    func clearGalleryFilters() {
        activeFilter = nil
        showFavoritesOnly = false
        selectedSessionName = nil
        searchText = ""
    }

    func createSession(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !sessions.contains(trimmed) else { return }
        sessions.append(trimmed)
        sessions.sort()
        selectedSessionName = trimmed
    }

    func renameSelectedSession(to name: String) {
        guard let selectedSessionName else { return }
        renameSession(named: selectedSessionName, to: name)
    }

    func renameSession(named sessionName: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, sessions.contains(sessionName) else { return }
        guard trimmed == sessionName || !sessions.contains(trimmed) else { return }

        for index in photos.indices where photos[index].sessionName == sessionName {
            photos[index].sessionName = trimmed
        }
        if let sessionIndex = sessions.firstIndex(of: sessionName) {
            sessions[sessionIndex] = trimmed
        }
        sessions.sort()
        if selectedSessionName == sessionName {
            selectedSessionName = trimmed
        }
    }

    func deleteSelectedSession() {
        guard let selectedSessionName else { return }
        deleteSession(named: selectedSessionName)
    }

    func deleteSession(named sessionName: String) {
        guard canDeleteSession(named: sessionName) else { return }
        sessions.removeAll { $0 == sessionName }
        if selectedSessionName == sessionName {
            selectedSessionName = nil
        }
    }

    func toggleFavorite(_ id: String) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        photos[index].isFavorite.toggle()
    }

    func rateCurrentPhoto(_ rating: Int) {
        guard let currentPhoto, let index = photos.firstIndex(of: currentPhoto) else { return }
        photos[index].rating = max(0, min(5, rating))
    }

    func rateSelectedPhotos(_ rating: Int) {
        let rated = bridge.rate(selectedPhotos, rating: rating)
        for photo in rated {
            if let index = photos.firstIndex(where: { $0.id == photo.id }) {
                photos[index] = photo
            }
        }
    }

    func applyActiveLutToCurrentPhoto() {
        guard let currentPhoto, let activeLut else { return }
        let edited = bridge.apply(lut: activeLut, intensity: lutIntensity, to: [currentPhoto])
        guard let first = edited.first, let index = photos.firstIndex(where: { $0.id == first.id }) else { return }
        photos[index] = first
    }

    func applyActiveLutToSelection() {
        guard let activeLut else { return }
        let edited = bridge.apply(lut: activeLut, intensity: lutIntensity, to: selectedPhotos)
        for photo in edited {
            if let index = photos.firstIndex(where: { $0.id == photo.id }) {
                photos[index] = photo
            }
        }
    }

    func markSelectionExported() {
        let exported = bridge.markExported(selectedPhotos)
        for photo in exported {
            if let index = photos.firstIndex(where: { $0.id == photo.id }) {
                photos[index] = photo
            }
        }
    }

    func toggleLutFavorite(_ id: String) {
        guard let index = luts.firstIndex(where: { $0.id == id }) else { return }
        luts[index] = bridge.toggleFavorite(lut: luts[index])
    }

    func renameLut(_ id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = luts.firstIndex(where: { $0.id == id }) else { return }
        luts[index] = bridge.rename(lut: luts[index], to: trimmed)
    }

    func deleteLut(_ id: String) {
        luts.removeAll { $0.id == id }
        if activeLutId == id {
            activeLutId = luts.first?.id
        }
    }

    func importMockPhotosFromLibrary() async {
        await importMockPhotos(sourceCode: "Photos")
    }

    func importMockPhotosFromFiles() async {
        await importMockPhotos(sourceCode: "Files")
    }

    func importMockPhotosToCurrentSession() async {
        await importMockPhotos(sourceCode: "Session")
    }

    func dismissImportMessage() {
        importMessage = nil
    }

    func importMockLut() {
        let lut = bridge.makeImportedLut(existingCount: luts.count)
        luts.insert(lut, at: 0)
        activeLutId = lut.id
    }

    private func importMockPhotos(sourceCode: String) async {
        guard !isImportingPhotos else { return }

        isImportingPhotos = true
        importMessage = String(localized: "Importing photos...")

        try? await Task.sleep(nanoseconds: 650_000_000)

        let targetSession = selectedSessionName ?? ensureDefaultImportSession()
        let importedPhotos = makeMockImportedPhotos(sessionName: targetSession, sourceCode: sourceCode)
        photos.insert(contentsOf: importedPhotos, at: 0)
        selectedSessionName = targetSession
        selectedPhotoId = importedPhotos.first?.id ?? selectedPhotoId
        activeFilter = nil
        showFavoritesOnly = false
        searchText = ""
        photoSortOption = .newest
        isImportingPhotos = false
        importMessage = String(format: String(localized: "Imported 3 photos to %@"), targetSession)
    }

    private func ensureDefaultImportSession() -> String {
        let defaultSession = String(localized: "Quick Imports")
        if !sessions.contains(defaultSession) {
            sessions.append(defaultSession)
            sessions.sort()
        }
        return defaultSession
    }

    private func makeMockImportedPhotos(sessionName: String, sourceCode: String) -> [Photo] {
        importedBatchCount += 1
        let imageNames = ["photo-forest", "photo-coast", "photo-girl"]
        let palettes: [[Color]] = [
            [.green, .yellow, .black],
            [.blue, .gray, .black],
            [.brown, .orange, .black]
        ]

        return imageNames.enumerated().map { offset, imageName in
            let sequence = photos.count + offset + 1
            return Photo(
                id: "import-\(importedBatchCount)-\(offset)",
                fileName: String(format: "IMPORT_%04d_%@.CR3", sequence, sourceCode),
                imageName: imageName,
                sessionName: sessionName,
                status: .raw,
                isFavorite: false,
                isSelected: false,
                rating: 0,
                appliedLutId: nil,
                lutIntensity: 0.55,
                recommendedLutIds: offset == 1 ? ["l2", "l4"] : ["l1", "l3"],
                palette: palettes[offset]
            )
        }
    }
}
