import Foundation
import Photos
import SwiftUI
import UIKit
import Darwin

struct PhotoLibraryImportPayload {
    var data: Data
    var suggestedFileName: String
}

private struct PersistedPhotoLibrary: Codable {
    var photos: [PersistedPhoto]
    var sessions: [String]
}

private struct PersistedPhoto: Codable {
    var id: String
    var fileName: String
    var imageName: String
    var imagePath: String?
    var sessionName: String
    var status: String
    var isFavorite: Bool
    var rating: Int
    var appliedLutId: String?
    var lutIntensity: Double
    var recommendedLutIds: [String]
    var exifSummary: PhotoExifSummary?
}

private struct PersistedLutLibrary: Codable {
    var luts: [PersistedLut]
    var userCategories: [LutCategoryGroup]?
}

private struct PersistedLut: Codable {
    var id: String
    var name: String
    var category: String
    var categoryGroupId: String?
    var tags: [String]
    var isFavorite: Bool
    var usageCount: Int
    var provider: String?
    var userPath: String?
}

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
    @Published var watermarkSettings = LutShopAppState.loadWatermarkSettings() {
        didSet {
            Self.persistWatermarkSettings(watermarkSettings)
        }
    }
    @Published var isImportingPhotos = false
    @Published var importMessage: String?
    @Published var cppSmokeSummary = ""
    @Published var lutLoadMessage: String?
    @Published var showCameraConnection = false
    @Published var cameraSettings = CameraImportSettings()
    @Published var ftpReceiverConfiguration = FtpReceiverConfiguration()
    @Published var ftpReceiverAddress = ""
    @Published var selectedCameraDeviceId: String?
    @Published var cameraSession: CameraSession?
    @Published var isDiscoveringCameras = false
    @Published var cameraDiscoveryMessage = ""
    @Published private(set) var cameraDevices: [CameraDevice]
    @Published private(set) var sessions: [String]
    @Published private(set) var photos: [Photo]
    @Published private(set) var luts: [LutPreset]
    @Published private(set) var lutCategories: [LutCategoryGroup]

    private let bridge: LutShopCoreBridge
    private let cameraDiscoveryService = CameraDiscoveryService()
    private let cameraReceiveService = CameraReceiveService()

    init(bridge: LutShopCoreBridge = MockLutShopCoreBridge()) {
        self.bridge = bridge
        let bridgePhotos = bridge.loadInitialPhotos()
        let initialLibrary = Self.loadPersistedPhotos()
            ?? (photos: bridgePhotos, sessions: Array(Set(bridgePhotos.map(\.sessionName))).sorted())
        self.photos = initialLibrary.photos
        self.sessions = initialLibrary.sessions
        let persistedLutLibrary = Self.loadPersistedLutLibrary()
        self.luts = Self.mergePersistedLuts(persistedLutLibrary.luts, into: bridge.loadLuts())
        self.lutCategories = Self.defaultLutCategories() + persistedLutLibrary.userCategories
        self.cameraDevices = Self.defaultCameraDevices()
        self.selectedPhotoId = photos.first?.id
        self.activeLutId = luts.first(where: \.hasRenderableSource)?.id
        self.cppSmokeSummary = Self.makeCppSmokeSummary()
        self.ftpReceiverAddress = Self.detectPreferredReceiverAddress() ?? ""
        self.selectedCameraDeviceId = cameraDevices.first?.id
        configureCameraReceiveService()
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

    var selectedPhotosExcludingCurrentCount: Int {
        guard let currentPhoto else { return selectedPhotos.count }
        return selectedPhotos.filter { $0.id != currentPhoto.id }.count
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
        luts.first { $0.id == activeLutId && $0.hasRenderableSource }
            ?? luts.first(where: \.hasRenderableSource)
    }

    func appliedLut(for photo: Photo) -> LutPreset? {
        guard let appliedLutId = photo.appliedLutId else { return nil }
        return luts.first { $0.id == appliedLutId }
    }

    func appliedLutFileName(for photo: Photo) -> String? {
        appliedLut(for: photo)?.sourceFileName
    }

    func appliedLutPath(for photo: Photo) -> String? {
        appliedLut(for: photo)?.userPath
    }

    var recommendedLuts: [LutPreset] {
        guard let currentPhoto else { return [] }
        return bridge.recommendLuts(for: currentPhoto, from: luts.filter(\.hasRenderableSource))
    }

    var visibleLutCategories: [LutCategoryGroup] {
        lutCategories
    }

    var selectedCameraDevice: CameraDevice? {
        guard let selectedCameraDeviceId else { return nil }
        return cameraDevices.first { $0.id == selectedCameraDeviceId }
    }

    var cameraConnectionTitle: String {
        if let cameraSession {
            return "\(cameraSession.deviceName) · \(cameraSession.status.title)"
        }
        return String(localized: "Sony FTP Receive · Ready")
    }

    var ftpReceiverAddressDisplay: String {
        ftpReceiverAddress.isEmpty ? String(localized: "Turn on Personal Hotspot to detect address") : ftpReceiverAddress
    }

    var ftpReceiverSummary: String {
        "\(ftpReceiverAddressDisplay):\(ftpReceiverConfiguration.port)"
    }

    func selectPhoto(_ id: String) {
        selectedPhotoId = id
        syncPreviewAdjustmentState(for: id)
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

    func selectAllFilteredPhotos() {
        let visibleIds = Set(filteredPhotos.map(\.id))
        guard !visibleIds.isEmpty else { return }
        for index in photos.indices where visibleIds.contains(photos[index].id) {
            photos[index].isSelected = true
        }
        selectedPhotoId = filteredPhotos.first?.id ?? selectedPhotoId
        isSelectionMode = true
    }

    func clearSelection() {
        for index in photos.indices {
            photos[index].isSelected = false
        }
        isSelectionMode = false
    }

    func deleteSelectedPhotos() {
        let ids = Set(selectedPhotos.map(\.id))
        guard !ids.isEmpty else { return }

        let deletedPhotos = photos.filter { ids.contains($0.id) }
        for photo in deletedPhotos {
            deletePhotoFileIfNeeded(photo)
        }

        photos.removeAll { ids.contains($0.id) }
        if let selectedPhotoId, ids.contains(selectedPhotoId) {
            self.selectedPhotoId = filteredPhotos.first?.id ?? photos.first?.id
        }
        isSelectionMode = false
        persistLibraryState()
        importMessage = String(
            format: String(localized: "Deleted %d photo(s)"),
            deletedPhotos.count
        )
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
        persistLibraryState()
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
        persistLibraryState()
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
        persistLibraryState()
    }

    func toggleFavorite(_ id: String) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        photos[index].isFavorite.toggle()
        persistLibraryState()
    }

    func rateCurrentPhoto(_ rating: Int) {
        guard let currentPhoto, let index = photos.firstIndex(of: currentPhoto) else { return }
        photos[index].rating = max(0, min(5, rating))
        persistLibraryState()
    }

    func rateSelectedPhotos(_ rating: Int) {
        let rated = bridge.rate(selectedPhotos, rating: rating)
        for photo in rated {
            if let index = photos.firstIndex(where: { $0.id == photo.id }) {
                photos[index] = photo
            }
        }
        persistLibraryState()
    }

    func applyActiveLutToCurrentPhoto() {
        guard let currentPhoto, let activeLut else { return }
        let edited = bridge.apply(lut: activeLut, intensity: lutIntensity, to: [currentPhoto])
        guard let first = edited.first, let index = photos.firstIndex(where: { $0.id == first.id }) else { return }
        photos[index] = first
        persistLibraryState()
        importMessage = String(localized: "Adjustment saved")
    }

    func applyActiveLutToSelection() {
        guard let activeLut else { return }
        let edited = bridge.apply(lut: activeLut, intensity: lutIntensity, to: selectedPhotos)
        for photo in edited {
            if let index = photos.firstIndex(where: { $0.id == photo.id }) {
                photos[index] = photo
            }
        }
        persistLibraryState()
    }

    func validateLutLoad(_ id: String) {
        guard let lut = luts.first(where: { $0.id == id }) else { return }
        guard lut.hasRenderableSource else {
            lutLoadMessage = String(localized: "This LUT has no source file")
            return
        }
        let loadSummary = bridge.loadSummary(for: lut)
        let pixelSummary = bridge.previewPixelSummary(for: lut)
        lutLoadMessage = [loadSummary, pixelSummary]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    func markSelectionExported() {
        let exported = bridge.markExported(selectedPhotos)
        for photo in exported {
            if let index = photos.firstIndex(where: { $0.id == photo.id }) {
                photos[index] = photo
            }
        }
        persistLibraryState()
    }

    func exportSelectedPhotosToLocalFiles(progressHandler: ((Int, Int) async -> Void)? = nil) async -> Int {
        let exportPhotos = selectedPhotos
        guard !exportPhotos.isEmpty else { return 0 }

        let directory: URL
        do {
            directory = try exportedPhotosDirectory()
        } catch {
            importMessage = String(localized: "Export failed")
            return 0
        }

        var exportedCount = 0
        let totalCount = exportPhotos.count
        for (offset, photo) in exportPhotos.enumerated() {
            defer {
                let completedCount = offset + 1
                if let progressHandler {
                    Task {
                        await progressHandler(completedCount, totalCount)
                    }
                }
            }
            guard let image = renderedImage(for: photo) else { continue }
            let resized = resizedImage(image, setting: exportSettings.size)
            let outputImage = WatermarkRenderer.render(
                image: resized,
                photo: photo,
                settings: watermarkSettings
            )
            let fileURL = directory.appendingPathComponent(exportFileName(for: photo))

            do {
                if exportSettings.format == "PNG" {
                    guard let data = outputImage.pngData() else { continue }
                    try data.write(to: fileURL, options: .atomic)
                } else {
                    guard let data = outputImage.jpegData(compressionQuality: exportQualityValue) else { continue }
                    try data.write(to: fileURL, options: .atomic)
                }
                if await saveImageToPhotoLibrary(outputImage) {
                    exportedCount += 1
                }
            } catch {
                continue
            }
        }

        if exportedCount > 0 {
            markSelectionExported()
            importMessage = String(
                format: String(localized: "Exported %d photo(s) to Photos"),
                exportedCount
            )
        } else {
            importMessage = String(localized: "Export failed")
        }
        return exportedCount
    }

    func resetCurrentPhotoAdjustment() {
        guard let currentPhoto, let index = photos.firstIndex(where: { $0.id == currentPhoto.id }) else { return }
        photos[index].appliedLutId = nil
        photos[index].status = .raw
        photos[index].lutIntensity = 0.55
        lutIntensity = photos[index].lutIntensity
        persistLibraryState()
        importMessage = String(localized: "Adjustment reset")
    }

    func syncCurrentAdjustmentToOtherSelectedPhotos() {
        guard let currentPhoto, let appliedLutId = currentPhoto.appliedLutId else {
            importMessage = String(localized: "Save an adjustment before syncing")
            return
        }

        var syncedCount = 0
        for index in photos.indices where photos[index].isSelected && photos[index].id != currentPhoto.id {
            photos[index].appliedLutId = appliedLutId
            photos[index].lutIntensity = currentPhoto.lutIntensity
            photos[index].status = .edited
            syncedCount += 1
        }

        guard syncedCount > 0 else { return }
        persistLibraryState()
        importMessage = String(
            format: String(localized: "Synced adjustment to %d selected photo(s)"),
            syncedCount
        )
    }

    func toggleLutFavorite(_ id: String) {
        guard let index = luts.firstIndex(where: { $0.id == id }) else { return }
        luts[index] = bridge.toggleFavorite(lut: luts[index])
        persistLutState()
    }

    func renameLut(_ id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = luts.firstIndex(where: { $0.id == id }) else { return }
        luts[index] = bridge.rename(lut: luts[index], to: trimmed)
        persistLutState()
    }

    func updateLutCategory(_ id: String, to groupId: String) {
        guard
            let index = luts.firstIndex(where: { $0.id == id }),
            let group = lutCategories.first(where: { $0.id == groupId })
        else {
            return
        }
        luts[index].category = group.category
        luts[index].categoryGroupId = group.id
        luts[index].previewColors = Self.previewColors(for: group.category)
        persistLutState()
    }

    func deleteLut(_ id: String) {
        let removed = luts.filter { $0.id == id }
        removed.forEach(deleteUserLutFileIfNeeded)
        luts.removeAll { $0.id == id }
        if activeLutId == id {
            activeLutId = luts.first(where: \.hasRenderableSource)?.id
        }
        for index in photos.indices where photos[index].appliedLutId == id {
            photos[index].appliedLutId = nil
            photos[index].status = .raw
        }
        persistLutState()
        persistLibraryState()
    }

    func lutCount(inCategoryGroup groupId: String) -> Int {
        luts.filter { ($0.categoryGroupId ?? $0.category.rawValue) == groupId }.count
    }

    func deleteLutCategory(_ groupId: String) -> Bool {
        guard let group = lutCategories.first(where: { $0.id == groupId }), !group.isSystem else {
            return false
        }

        let removedIds = Set(luts.filter { ($0.categoryGroupId ?? $0.category.rawValue) == groupId }.map(\.id))
        luts
            .filter { removedIds.contains($0.id) }
            .forEach(deleteUserLutFileIfNeeded)
        luts.removeAll { removedIds.contains($0.id) }
        lutCategories.removeAll { $0.id == groupId }

        if let activeLutId, removedIds.contains(activeLutId) {
            self.activeLutId = luts.first(where: \.hasRenderableSource)?.id
        }
        for index in photos.indices where photos[index].appliedLutId.map({ removedIds.contains($0) }) == true {
            photos[index].appliedLutId = nil
            photos[index].status = .raw
        }

        persistLutState()
        persistLibraryState()
        return true
    }

    func importPhotoLibraryItems(_ items: [PhotoLibraryImportPayload]) async {
        guard !items.isEmpty, !isImportingPhotos else { return }

        isImportingPhotos = true
        importMessage = String(localized: "Importing photos...")

        let targetSession = selectedSessionName ?? ensureDefaultImportSession()
        do {
            let importedPhotos = try savePhotoLibraryItems(items, sessionName: targetSession)
            photos.insert(contentsOf: importedPhotos, at: 0)
            selectedSessionName = targetSession
            selectedPhotoId = importedPhotos.first?.id ?? selectedPhotoId
            activeFilter = nil
            showFavoritesOnly = false
            searchText = ""
            photoSortOption = .newest
            persistLibraryState()
            isImportingPhotos = false
            importMessage = String(
                format: String(localized: "Imported %d photo(s) to %@"),
                importedPhotos.count,
                targetSession
            )
        } catch {
            isImportingPhotos = false
            importMessage = String(localized: "Photo import failed")
        }
    }

    func dismissImportMessage() {
        importMessage = nil
    }

    func importMockLut() {
        let lut = bridge.makeImportedLut(existingCount: luts.count)
        luts.insert(lut, at: 0)
        activeLutId = lut.id
    }

    func importUserLut(name: String, path: String, categoryGroupId: String, fileURL: URL?) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            (!trimmedName.isEmpty || fileURL != nil),
            (!trimmedPath.isEmpty || fileURL != nil),
            let group = lutCategories.first(where: { $0.id == categoryGroupId })
        else {
            return String(localized: "Could not add LUT")
        }

        guard let fileURL else {
            return addUserLut(name: trimmedName, path: trimmedPath, categoryGroupId: categoryGroupId)
                ? String(localized: "Added LUT")
                : String(localized: "Could not add LUT")
        }

        let hasSecurityScope = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let cubes = try ZipLutArchiveExtractor.extractCubeFiles(from: fileURL)
            let imported = try saveImportedUserLuts(cubes, preferredName: trimmedName, group: group)
            guard !imported.isEmpty else {
                return String(localized: "No CUBE files found")
            }
            luts.insert(contentsOf: imported, at: 0)
            activeLutId = imported.first?.id
            persistLutState()
            return String(
                format: String(localized: "Imported %d LUT(s)"),
                imported.count
            )
        } catch {
            return error.localizedDescription
        }
    }

    func addUserLut(name: String, path: String, categoryGroupId: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedName.isEmpty,
            !trimmedPath.isEmpty,
            let group = lutCategories.first(where: { $0.id == categoryGroupId })
        else {
            return false
        }

        let provider: String
        if let url = URL(string: trimmedPath), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) {
            provider = String(localized: "Remote")
        } else {
            provider = String(localized: "Local")
        }

        let lut = LutPreset(
            id: "user-lut-\(Int(Date().timeIntervalSince1970 * 1000))",
            name: trimmedName,
            category: group.category,
            categoryGroupId: group.id,
            tags: ["user", provider.lowercased()],
            previewColors: Self.previewColors(for: group.category),
            isFavorite: false,
            usageCount: 0,
            confidence: nil,
            sourceFileName: nil,
            cubeSize: nil,
            cubeEntryCount: nil,
            provider: provider,
            isBundled: false,
            userPath: trimmedPath
        )

        luts.insert(lut, at: 0)
        activeLutId = lut.id
        persistLutState()
        return true
    }

    private func saveImportedUserLuts(_ cubes: [ImportedCubeFile], preferredName: String, group: LutCategoryGroup) throws -> [LutPreset] {
        let directory = try Self.userLutDirectoryURL()
        let usePreferredName = cubes.count == 1 && !preferredName.isEmpty

        return try cubes.enumerated().map { index, cube in
            let fileName = uniqueUserLutFileName(for: cube.fileName)
            let fileURL = directory.appendingPathComponent(fileName)
            try cube.data.write(to: fileURL, options: .atomic)

            let fallbackName = URL(fileURLWithPath: cube.fileName).deletingPathExtension().lastPathComponent
            return LutPreset(
                id: "user-lut-\(Int(Date().timeIntervalSince1970 * 1000))-\(index)-\(UUID().uuidString.prefix(8))",
                name: usePreferredName ? preferredName : fallbackName,
                category: group.category,
                categoryGroupId: group.id,
                tags: ["user", "local", "cube"],
                previewColors: Self.previewColors(for: group.category),
                isFavorite: false,
                usageCount: 0,
                confidence: nil,
                sourceFileName: nil,
                cubeSize: nil,
                cubeEntryCount: nil,
                provider: String(localized: "Local"),
                isBundled: false,
                userPath: fileURL.path
            )
        }
    }

    func createLutCategory(named name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !lutCategories.contains(where: { $0.title.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) else {
            return false
        }

        let category = LutCategory.custom
        let group = LutCategoryGroup(
            id: "user-category-\(Int(Date().timeIntervalSince1970 * 1000))",
            title: trimmed,
            category: category,
            isSystem: false
        )
        lutCategories.append(group)
        persistLutState()
        return true
    }

    func openCameraConnection() {
        refreshFtpReceiverAddress()
        showCameraConnection = true
    }

    func selectCameraDevice(_ id: String) {
        guard cameraDevices.contains(where: { $0.id == id }) else { return }
        selectedCameraDeviceId = id
        if cameraSession?.status == .waiting || cameraSession?.status == .receiving {
            stopCameraReceive()
        }
    }

    func startCameraDiscovery() {
        isDiscoveringCameras = true
        cameraDiscoveryMessage = String(localized: "Searching local network for FTP cameras...")
        cameraDiscoveryService.start { [weak self] endpoints in
            Task { @MainActor in
                guard let self else { return }
                self.mergeDiscoveredCameraEndpoints(endpoints)
            }
        }
    }

    func stopCameraDiscovery() {
        cameraDiscoveryService.stop()
        isDiscoveringCameras = false
        if cameraDiscoveryMessage.isEmpty {
            cameraDiscoveryMessage = String(localized: "Discovery stopped")
        }
    }

    func startCameraReceive() {
        refreshFtpReceiverAddress()
        let receiverName = selectedCameraDevice?.model ?? String(localized: "Sony FTP Receive")
        let sessionName = makeCameraSessionName(for: receiverName)
        if cameraSettings.autoCreateSession && !sessions.contains(sessionName) {
            sessions.append(sessionName)
            sessions.sort()
        }
        selectedSessionName = sessionName
        cameraSession = CameraSession(
            id: "camera-\(Int(Date().timeIntervalSince1970))",
            name: sessionName,
            source: .ftpCamera,
            deviceName: receiverName,
            startedAt: Date(),
            status: .waiting,
            receivedCount: 0,
            currentFileName: nil,
            lastFileName: nil
        )
        do {
            try cameraReceiveService.start(configuration: ftpReceiverConfiguration, host: ftpReceiverAddress)
        } catch {
            var failedSession = cameraSession
            failedSession?.status = .stopped
            cameraSession = failedSession
            importMessage = String(localized: "FTP receiver failed to start")
        }
    }

    func stopCameraReceive() {
        guard var session = cameraSession else { return }
        session.status = .stopped
        cameraSession = session
        cameraReceiveService.stop()
    }

    private func configureCameraReceiveService() {
        cameraReceiveService.onTransferStarted = { [weak self] fileName in
            Task { @MainActor in
                guard var session = self?.cameraSession else { return }
                session.status = .receiving
                session.currentFileName = fileName
                self?.cameraSession = session
            }
        }
        cameraReceiveService.onFileReceived = { [weak self] receivedFile in
            Task { @MainActor in
                self?.importCameraReceivedFile(receivedFile)
            }
        }
        cameraReceiveService.onError = { [weak self] message in
            Task { @MainActor in
                self?.importMessage = message
                if var session = self?.cameraSession {
                    session.status = .stopped
                    self?.cameraSession = session
                }
            }
        }
    }

    private func importCameraReceivedFile(_ receivedFile: CameraReceivedFile) {
        let sessionName = cameraSession?.name ?? selectedSessionName ?? ensureDefaultImportSession()
        guard let photo = saveCameraReceivedFile(receivedFile, sessionName: sessionName) else {
            importMessage = String(localized: "Camera file import failed")
            return
        }

        if !sessions.contains(sessionName) {
            sessions.append(sessionName)
            sessions.sort()
        }
        photos.insert(photo, at: 0)
        selectedSessionName = sessionName
        selectedPhotoId = photo.id
        activeFilter = nil
        showFavoritesOnly = false
        searchText = ""
        photoSortOption = .newest

        if var session = cameraSession {
            session.status = .waiting
            session.receivedCount += 1
            session.currentFileName = nil
            session.lastFileName = receivedFile.originalFileName
            cameraSession = session
        }
        persistLibraryState()
        importMessage = String(
            format: String(localized: "Received %@ from camera"),
            receivedFile.originalFileName
        )
    }

    private static func makeCppSmokeSummary() -> String {
        let version = LutShopCppBridge.coreVersion()
        let importCount = LutShopCppBridge.sampleImportPhotoCount()
        let cubeEntries = LutShopCppBridge.sampleCubeEntryCount()
        return "\(version) · import \(importCount) · LUT \(cubeEntries)"
    }

    private static func defaultCameraDevices() -> [CameraDevice] {
        [
            CameraDevice(
                id: "sony-hotspot-receiver",
                name: String(localized: "iPhone FTP Receiver"),
                model: "Sony Auto Import",
                source: .ftpCamera,
                hostHint: "",
                port: 2121,
                username: "lee"
            )
        ]
    }

    func refreshFtpReceiverAddress() {
        ftpReceiverAddress = Self.detectPreferredReceiverAddress() ?? ""
        guard let index = cameraDevices.firstIndex(where: { $0.id == "sony-hotspot-receiver" }) else { return }
        cameraDevices[index].hostHint = ftpReceiverAddress
        cameraDevices[index].port = ftpReceiverConfiguration.port
        cameraDevices[index].username = ftpReceiverConfiguration.username
        selectedCameraDeviceId = cameraDevices[index].id
    }

    private static func loadPersistedPhotos() -> (photos: [Photo], sessions: [String])? {
        guard
            let url = try? libraryIndexURL(),
            let data = try? Data(contentsOf: url),
            let library = try? JSONDecoder().decode(PersistedPhotoLibrary.self, from: data)
        else {
            return nil
        }

        let restoredPhotos = library.photos.compactMap { persisted -> Photo? in
            let resolvedImagePath = resolvePersistedImagePath(persisted.imagePath)
            if persisted.imagePath != nil, resolvedImagePath == nil {
                return nil
            }
            let status = PhotoStatus(rawValue: persisted.status) ?? .raw
            return Photo(
                id: persisted.id,
                fileName: persisted.fileName,
                imageName: persisted.imageName,
                imagePath: resolvedImagePath,
                sessionName: persisted.sessionName,
                status: status,
                isFavorite: persisted.isFavorite,
                isSelected: false,
                rating: persisted.rating,
                appliedLutId: persisted.appliedLutId,
                lutIntensity: persisted.lutIntensity,
                recommendedLutIds: persisted.recommendedLutIds,
                palette: [.gray, .black],
                exifSummary: persisted.exifSummary
                    ?? WatermarkRenderer.exifSummary(fromImageAtPath: resolvedImagePath)
            )
        }

        let restoredSessions = Array(Set((library.sessions + restoredPhotos.map(\.sessionName)).filter { !$0.isEmpty })).sorted()
        return (restoredPhotos, restoredSessions)
    }

    private static func resolvePersistedImagePath(_ imagePath: String?) -> String? {
        guard let imagePath, !imagePath.isEmpty else { return nil }
        if FileManager.default.fileExists(atPath: imagePath) {
            return imagePath
        }

        let fileName = URL(fileURLWithPath: imagePath).lastPathComponent
        guard !fileName.isEmpty, let directory = try? importedPhotosDirectoryURL() else {
            return nil
        }

        let recoveredPath = directory.appendingPathComponent(fileName).path
        return FileManager.default.fileExists(atPath: recoveredPath) ? recoveredPath : nil
    }

    private func persistLibraryState() {
        let payload = PersistedPhotoLibrary(
            photos: photos.map { photo in
                PersistedPhoto(
                    id: photo.id,
                    fileName: photo.fileName,
                    imageName: photo.imageName,
                    imagePath: photo.imagePath,
                    sessionName: photo.sessionName,
                    status: photo.status.rawValue,
                    isFavorite: photo.isFavorite,
                    rating: photo.rating,
                    appliedLutId: photo.appliedLutId,
                    lutIntensity: photo.lutIntensity,
                    recommendedLutIds: photo.recommendedLutIds,
                    exifSummary: photo.exifSummary
                )
            },
            sessions: sessions
        )

        guard
            let data = try? JSONEncoder().encode(payload),
            let url = try? Self.libraryIndexURL()
        else {
            return
        }

        try? data.write(to: url, options: .atomic)
    }

    private func deletePhotoFileIfNeeded(_ photo: Photo) {
        guard let imagePath = photo.imagePath, !imagePath.isEmpty else { return }
        try? FileManager.default.removeItem(atPath: imagePath)
    }

    private func deleteUserLutFileIfNeeded(_ lut: LutPreset) {
        guard
            !lut.isBundled,
            let userPath = lut.userPath,
            !userPath.isEmpty,
            !userPath.lowercased().hasPrefix("http://"),
            !userPath.lowercased().hasPrefix("https://")
        else {
            return
        }

        guard let userDirectory = try? Self.userLutDirectoryURL() else { return }
        let fileURL = URL(fileURLWithPath: userPath)
        let standardizedPath = fileURL.standardizedFileURL.path
        let userDirectoryPath = userDirectory.standardizedFileURL.path
        guard standardizedPath.hasPrefix(userDirectoryPath + "/") else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func loadPersistedLutLibrary() -> (luts: [PersistedLut], userCategories: [LutCategoryGroup]) {
        guard
            let url = try? lutIndexURL(),
            let data = try? Data(contentsOf: url),
            let library = try? JSONDecoder().decode(PersistedLutLibrary.self, from: data)
        else {
            return ([], [])
        }
        return (library.luts, library.userCategories ?? [])
    }

    private static func mergePersistedLuts(_ persistedLuts: [PersistedLut], into baseLuts: [LutPreset]) -> [LutPreset] {
        var merged = baseLuts

        for persisted in persistedLuts {
            let category = LutCategory.allCases.first { $0.rawValue == persisted.category } ?? .custom
            if let index = merged.firstIndex(where: { $0.id == persisted.id }) {
                merged[index].name = persisted.name
                merged[index].category = category
                merged[index].categoryGroupId = persisted.categoryGroupId ?? persisted.category
                merged[index].tags = persisted.tags
                merged[index].isFavorite = persisted.isFavorite
                merged[index].usageCount = persisted.usageCount
                merged[index].provider = persisted.provider ?? merged[index].provider
                merged[index].userPath = persisted.userPath
            } else {
                guard persisted.userPath?.isEmpty == false else { continue }
                merged.insert(
                    LutPreset(
                        id: persisted.id,
                        name: persisted.name,
                        category: category,
                        categoryGroupId: persisted.categoryGroupId ?? persisted.category,
                        tags: persisted.tags,
                        previewColors: previewColors(for: category),
                        isFavorite: persisted.isFavorite,
                        usageCount: persisted.usageCount,
                        confidence: nil,
                        sourceFileName: nil,
                        cubeSize: nil,
                        cubeEntryCount: nil,
                        provider: persisted.provider,
                        isBundled: false,
                        userPath: persisted.userPath
                    ),
                    at: 0
                )
            }
        }

        return merged
    }

    private func persistLutState() {
        let payload = PersistedLutLibrary(
            luts: luts.map { lut in
                PersistedLut(
                    id: lut.id,
                    name: lut.name,
                    category: lut.category.rawValue,
                    categoryGroupId: lut.categoryGroupId ?? lut.category.rawValue,
                    tags: lut.tags,
                    isFavorite: lut.isFavorite,
                    usageCount: lut.usageCount,
                    provider: lut.provider,
                    userPath: lut.userPath
                )
            },
            userCategories: lutCategories.filter { !$0.isSystem }
        )

        guard
            let data = try? JSONEncoder().encode(payload),
            let url = try? Self.lutIndexURL()
        else {
            return
        }

        try? data.write(to: url, options: .atomic)
    }

    private func mergeDiscoveredCameraEndpoints(_ endpoints: [DiscoveredCameraEndpoint]) {
        let discoveredDevices = endpoints.map { endpoint in
            CameraDevice(
                id: "discovered-\(endpoint.serviceType)-\(endpoint.name)"
                    .replacingOccurrences(of: " ", with: "-")
                    .lowercased(),
                name: String(localized: "Discovered Camera"),
                model: endpoint.name,
                source: .ftpCamera,
                hostHint: endpoint.host,
                port: endpoint.port,
                username: "lee",
                isDiscovered: true
            )
        }

        for device in discoveredDevices {
            if let index = cameraDevices.firstIndex(where: { $0.id == device.id }) {
                cameraDevices[index] = device
            } else {
                cameraDevices.insert(device, at: 0)
            }
        }

        if discoveredDevices.isEmpty {
            cameraDiscoveryMessage = String(localized: "No advertised FTP cameras found yet")
        } else {
            cameraDiscoveryMessage = String(format: String(localized: "Found %d camera service(s)"), discoveredDevices.count)
            let selectedDevice = selectedCameraDeviceId.flatMap { id in
                cameraDevices.first { $0.id == id }
            }
            if selectedDevice == nil || selectedDevice?.isDiscovered == false {
                selectedCameraDeviceId = discoveredDevices[0].id
            }
        }
    }

    private func makeCameraSessionName(for deviceName: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return "\(deviceName) · \(formatter.string(from: Date()))"
    }

    private func ensureDefaultImportSession() -> String {
        let defaultSession = String(localized: "Quick Imports")
        if !sessions.contains(defaultSession) {
            sessions.append(defaultSession)
            sessions.sort()
        }
        return defaultSession
    }

    private func savePhotoLibraryItems(_ items: [PhotoLibraryImportPayload], sessionName: String) throws -> [Photo] {
        let directory = try importedPhotosDirectory()
        let timestamp = Int(Date().timeIntervalSince1970)

        return items.enumerated().compactMap { offset, item in
            guard let image = UIImage(data: item.data), let jpegData = image.jpegData(compressionQuality: 0.94) else {
                return nil
            }

            let baseName = sanitizedFileBaseName(item.suggestedFileName)
            let fileName = "\(baseName)-\(timestamp)-\(offset + 1).jpg"
            let fileURL = directory.appendingPathComponent(fileName)

            do {
                try jpegData.write(to: fileURL, options: .atomic)
            } catch {
                return nil
            }

            return Photo(
                id: "library-\(timestamp)-\(offset)",
                fileName: item.suggestedFileName.isEmpty ? fileName : item.suggestedFileName,
                imageName: "",
                imagePath: fileURL.path,
                sessionName: sessionName,
                status: .raw,
                isFavorite: false,
                isSelected: false,
                rating: 0,
                appliedLutId: nil,
                lutIntensity: 0.55,
                recommendedLutIds: luts.prefix(2).map(\.id),
                palette: [.gray, .black],
                exifSummary: WatermarkRenderer.exifSummary(fromImageData: item.data)
            )
        }
    }

    private func saveCameraReceivedFile(_ receivedFile: CameraReceivedFile, sessionName: String) -> Photo? {
        do {
            let directory = try importedPhotosDirectory()
            let fileName = uniqueImportedFileName(for: receivedFile.originalFileName)
            let targetURL = directory.appendingPathComponent(fileName)

            if FileManager.default.fileExists(atPath: targetURL.path), cameraSettings.skipDuplicateFiles {
                return nil
            }
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            try FileManager.default.copyItem(at: receivedFile.fileURL, to: targetURL)

            return Photo(
                id: "camera-\(Int(Date().timeIntervalSince1970 * 1000))",
                fileName: receivedFile.originalFileName,
                imageName: "",
                imagePath: targetURL.path,
                sessionName: sessionName,
                status: .raw,
                isFavorite: false,
                isSelected: false,
                rating: 0,
                appliedLutId: nil,
                lutIntensity: 0.55,
                recommendedLutIds: luts.prefix(2).map(\.id),
                palette: [.gray, .black],
                exifSummary: WatermarkRenderer.exifSummary(fromImageAtPath: targetURL.path)
            )
        } catch {
            return nil
        }
    }

    private func importedPhotosDirectory() throws -> URL {
        try Self.importedPhotosDirectoryURL()
    }

    private static func importedPhotosDirectoryURL() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent("ImportedPhotos", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func exportedPhotosDirectory() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private var exportQualityValue: CGFloat {
        switch exportSettings.quality {
        case "Low":
            return 0.62
        case "Medium":
            return 0.82
        default:
            return 0.94
        }
    }

    private func renderedImage(for photo: Photo) -> UIImage? {
        let lutFileName = appliedLutFileName(for: photo)
        let lutPath = appliedLutPath(for: photo)
        if photo.lutIntensity > 0, lutFileName != nil || lutPath != nil {
            if let lutPath,
               let imagePath = photo.imagePath,
               let image = CoreImageLutRenderer.shared.applyUserLut(
                atPath: lutPath,
                toImageAtPath: imagePath,
                intensity: photo.lutIntensity
               ) {
                return image
            }
            if let lutPath,
               let image = CoreImageLutRenderer.shared.applyUserLut(
                atPath: lutPath,
                toImageNamed: photo.imageName,
                intensity: photo.lutIntensity
               ) {
                return image
            }
            if let lutFileName,
               let imagePath = photo.imagePath,
               let image = CoreImageLutRenderer.shared.applyBundledLut(
                named: lutFileName,
                toImageAtPath: imagePath,
                intensity: photo.lutIntensity
               ) {
                return image
            }
            if let lutFileName,
               let image = CoreImageLutRenderer.shared.applyBundledLut(
                named: lutFileName,
                toImageNamed: photo.imageName,
                intensity: photo.lutIntensity
            ) {
                return image
            }
            if let lutPath,
               let imagePath = photo.imagePath,
               let image = LutShopCppBridge.applyUserLut(
                atPath: lutPath,
                toImageAtPath: imagePath,
                intensity: photo.lutIntensity
               ) {
                return image
            }
            if let lutPath,
               let image = LutShopCppBridge.applyUserLut(
                atPath: lutPath,
                toImageNamed: photo.imageName,
                intensity: photo.lutIntensity
               ) {
                return image
            }
            if let lutFileName,
               let imagePath = photo.imagePath,
               let image = LutShopCppBridge.previewImage(
                byApplyingBundledLutNamed: lutFileName,
                toImageAtPath: imagePath,
                intensity: photo.lutIntensity
               ) {
                return image
            }
            if let lutFileName,
               let image = LutShopCppBridge.previewImage(
                byApplyingBundledLutNamed: lutFileName,
                toImageNamed: photo.imageName,
                intensity: photo.lutIntensity
            ) {
                return image
            }
        }

        if let imagePath = photo.imagePath, let image = UIImage(contentsOfFile: imagePath) {
            return image
        }

        guard let url = Bundle.main.url(
            forResource: photo.imageName,
            withExtension: "jpg",
            subdirectory: "PrototypePhotos"
        ) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    private func resizedImage(_ image: UIImage, setting: String) -> UIImage {
        let maxDimension: CGFloat?
        switch setting {
        case "1080px":
            maxDimension = 1080
        case "2048px":
            maxDimension = 2048
        default:
            maxDimension = nil
        }
        guard let maxDimension else { return image }

        let width = image.size.width
        let height = image.size.height
        let longest = max(width, height)
        guard longest > maxDimension, longest > 0 else { return image }

        let scale = maxDimension / longest
        let targetSize = CGSize(width: width * scale, height: height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func exportFileName(for photo: Photo) -> String {
        let base = sanitizedFileBaseName(photo.fileName)
        let timestamp = Int(Date().timeIntervalSince1970)
        let ext = exportSettings.format.lowercased()
        return "\(base)-export-\(timestamp).\(ext)"
    }

    private func syncPreviewAdjustmentState(for photoId: String) {
        guard let photo = photos.first(where: { $0.id == photoId }) else { return }
        if let appliedLutId = photo.appliedLutId, luts.contains(where: { $0.id == appliedLutId }) {
            activeLutId = appliedLutId
        }
        lutIntensity = min(max(photo.lutIntensity, 0), 1)
    }

    private func saveImageToPhotoLibrary(_ image: UIImage) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            importMessage = String(localized: "Photo Library permission is required to export.")
            return false
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    private static func libraryIndexURL() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("PhotoLibraryIndex.json")
    }

    private static func loadWatermarkSettings() -> WatermarkSettings {
        guard
            let data = UserDefaults.standard.data(forKey: "lutshop.watermarkSettings"),
            let settings = try? JSONDecoder().decode(WatermarkSettings.self, from: data)
        else {
            return WatermarkSettings()
        }
        return settings
    }

    private static func persistWatermarkSettings(_ settings: WatermarkSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: "lutshop.watermarkSettings")
    }

    private static func lutIndexURL() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("LutLibraryIndex.json")
    }

    private static func userLutDirectoryURL() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent("UserLuts", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func detectPreferredReceiverAddress() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else {
            return nil
        }
        defer { freeifaddrs(interfaces) }

        var candidates: [(score: Int, address: String)] = []
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard let addressPointer = interface.ifa_addr else { continue }
            let family = addressPointer.pointee.sa_family
            guard family == UInt8(AF_INET) else { continue }

            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & Int32(IFF_UP)) != 0
            let isLoopback = (flags & Int32(IFF_LOOPBACK)) != 0
            guard isUp, !isLoopback else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let name = String(cString: interface.ifa_name)
            let result = getnameinfo(
                addressPointer,
                socklen_t(addressPointer.pointee.sa_len),
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard result == 0 else { continue }

            let address = String(cString: host)
            let score = receiverAddressScore(interfaceName: name, address: address)
            if score > 0 {
                candidates.append((score, address))
            }
        }

        return candidates.sorted { left, right in
            if left.score == right.score {
                return left.address < right.address
            }
            return left.score > right.score
        }.first?.address
    }

    private static func receiverAddressScore(interfaceName: String, address: String) -> Int {
        guard address.contains(".") else { return 0 }

        var score = 0
        if address.hasPrefix("172.20.") {
            score += 100
        } else if address.hasPrefix("192.168.") {
            score += 80
        } else if address.hasPrefix("10.") {
            score += 70
        } else if address.hasPrefix("172.") {
            score += 60
        } else {
            return 0
        }

        if interfaceName.hasPrefix("bridge") { score += 20 }
        if interfaceName.hasPrefix("ap") { score += 15 }
        if interfaceName == "en0" { score += 10 }
        return score
    }

    private static func defaultLutCategories() -> [LutCategoryGroup] {
        [
            LutCategoryGroup(id: LutCategory.portrait.rawValue, title: LutCategory.portrait.title, category: .portrait, isSystem: true),
            LutCategoryGroup(id: LutCategory.landscape.rawValue, title: LutCategory.landscape.title, category: .landscape, isSystem: true),
            LutCategoryGroup(id: LutCategory.film.rawValue, title: LutCategory.film.title, category: .film, isSystem: true),
            LutCategoryGroup(id: LutCategory.blackWhite.rawValue, title: LutCategory.blackWhite.title, category: .blackWhite, isSystem: true),
            LutCategoryGroup(id: LutCategory.commercial.rawValue, title: LutCategory.commercial.title, category: .commercial, isSystem: true)
        ]
    }

    private static func previewColors(for category: LutCategory) -> [Color] {
        switch category {
        case .portrait:
            return [.brown, .orange, .white]
        case .landscape:
            return [.blue, .cyan, .green]
        case .film:
            return [.black, .orange, .cyan]
        case .blackWhite:
            return [.black, .gray, .white]
        case .commercial:
            return [.black, .gray, .orange]
        case .custom:
            return [.accentGreen, .cyan, .white]
        }
    }

    private func sanitizedFileBaseName(_ fileName: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = String(base.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return sanitized.isEmpty ? "library-photo" : sanitized
    }

    private func uniqueImportedFileName(for originalFileName: String) -> String {
        let ext = (originalFileName as NSString).pathExtension
        let base = sanitizedFileBaseName(originalFileName)
        let timestamp = Int(Date().timeIntervalSince1970)
        if ext.isEmpty {
            return "\(base)-\(timestamp)"
        }
        return "\(base)-\(timestamp).\(ext.lowercased())"
    }

    private func uniqueUserLutFileName(for originalFileName: String) -> String {
        let base = sanitizedFileBaseName(originalFileName)
        let suffix = UUID().uuidString.prefix(8).lowercased()
        return "\(base)-\(suffix).cube"
    }
}
