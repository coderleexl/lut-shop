import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct GalleryView: View {
    @EnvironmentObject private var state: LutShopAppState
    @State private var showSessionManager = false
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false
    @State private var showDeleteSelectionConfirmation = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var galleryColumnCount = 3

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: galleryColumnCount)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                cameraReceiveBanner
                controls
                selectionToolbar
                importStatusBanner
                cppSmokeBanner
                sessionBar
                filterTabs
                galleryScaleControls
                photoGrid
            }
            .padding(.horizontal, 14)
            .padding(.top, 24)
            .padding(.bottom, 152)
        }
        .background(
            LinearGradient(colors: [.black, Color(red: 0.05, green: 0.07, blue: 0.08)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .sheet(isPresented: $showSessionManager) {
            sessionManagerSheet
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 80,
            matching: .images
        )
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            Task {
                await importSelectedFileURLs(result)
            }
        }
        .onChange(of: selectedPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await importSelectedPhotoItems(items)
                selectedPhotoItems = []
            }
        }
        .fullScreenCover(isPresented: $state.showCameraConnection) {
            CameraImportView()
                .environmentObject(state)
        }
        .confirmationDialog(String(localized: "Delete Selected Photos?"), isPresented: $showDeleteSelectionConfirmation, titleVisibility: .visible) {
            Button(String(localized: "Delete"), role: .destructive) {
                state.deleteSelectedPhotos()
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(format: String(localized: "Delete %d selected photo(s). This cannot be undone."), state.selectedPhotos.count))
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
                Text("lut-shop")
                .font(.system(size: 38, weight: .bold))
                .tracking(-0.2)

            Spacer()

            HStack(spacing: 10) {
                Button {
                    state.openCameraConnection()
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(state.cameraSession?.status == .receiving ? Color.accentGreen : .green)
                            .frame(width: 8, height: 8)
                        Text(state.cameraConnectionTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(String(localized: "Open camera connection")))

                importMenu
            }
        }
    }

    private var importMenu: some View {
        Menu {
            Button {
                showPhotoPicker = true
            } label: {
                Label(String(localized: "Import from Photos"), systemImage: "photo.on.rectangle")
            }

            Button {
                showFileImporter = true
            } label: {
                Label(String(localized: "Import from Files"), systemImage: "folder")
            }

            Button {
                showPhotoPicker = true
            } label: {
                Label(String(localized: "Import to Current Session"), systemImage: "tray.and.arrow.down")
            }
        } label: {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(state.isImportingPhotos ? Color.accentGreen : .white)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .disabled(state.isImportingPhotos)
        .accessibilityLabel(Text(String(localized: "Import photos")))
    }

    @ViewBuilder
    private var cameraReceiveBanner: some View {
        if let session = state.cameraSession, session.status == .waiting || session.status == .receiving || session.receivedCount > 0 {
            Button {
                state.openCameraConnection()
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(session.status == .stopped ? .white.opacity(0.45) : Color.accentGreen)
                        .frame(width: 9, height: 9)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.status.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(state.ftpReceiverSummary) · \(String(localized: "received")) \(session.receivedCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(session.currentFileName ?? session.lastFileName ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 130, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
    }

    private func importSelectedPhotoItems(_ items: [PhotosPickerItem]) async {
        var payloads: [PhotoLibraryImportPayload] = []
        for (index, item) in items.enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                continue
            }

            let fileExtension = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
            payloads.append(PhotoLibraryImportPayload(
                data: data,
                suggestedFileName: String(format: "LIB_%04d.%@", index + 1, fileExtension.uppercased())
            ))
        }

        await state.importPhotoLibraryItems(payloads)
    }

    private func importSelectedFileURLs(_ result: Result<[URL], Error>) async {
        guard case let .success(urls) = result else { return }

        var payloads: [PhotoLibraryImportPayload] = []
        for url in urls {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            guard let data = try? Data(contentsOf: url) else {
                continue
            }
            payloads.append(PhotoLibraryImportPayload(data: data, suggestedFileName: url.lastPathComponent))
        }

        await state.importPhotoLibraryItems(payloads)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.62))
                TextField(String(localized: "Search"), text: $state.searchText)
                    .textInputAutocapitalization(.never)
            }
            .font(.system(size: 17))
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.06)))

            filterMenu
            sortMenu
            selectionModeButton
        }
    }

    @ViewBuilder
    private var importStatusBanner: some View {
        if state.isImportingPhotos || state.importMessage != nil {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentGreen.opacity(0.16))
                    if state.isImportingPhotos {
                        ProgressView()
                            .tint(Color.accentGreen)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.accentGreen)
                    }
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.isImportingPhotos ? String(localized: "Importing") : String(localized: "Import complete"))
                        .font(.system(size: 14, weight: .bold))
                    Text(state.importMessage ?? String(localized: "Preparing photos"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer()

                if !state.isImportingPhotos {
                    Button {
                        state.dismissImportMessage()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(String(localized: "Dismiss import message")))
                }
            }
            .padding(12)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.06)))
        }
    }

    private var cppSmokeBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: "cpu")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.accentGreen)
                .frame(width: 28, height: 28)
                .background(Color.accentGreen.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
            Text(state.cppSmokeSummary)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.05)))
        .accessibilityLabel(Text(String(localized: "C++ core smoke test")))
    }

    private var filterMenu: some View {
        Menu {
            Button(String(localized: "All")) {
                state.setStatusFilter(nil)
            }
            Button(String(localized: "New")) {
                state.setStatusFilter(.raw)
            }
            Button(String(localized: "Edited")) {
                state.setStatusFilter(.edited)
            }
            Button(String(localized: "Favorites")) {
                state.setStatusFilter(nil, favoritesOnly: true)
            }
            Button(String(localized: "Exported")) {
                state.setStatusFilter(.exported)
            }
            Divider()
            Button(String(localized: "Clear filters")) {
                state.clearGalleryFilters()
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(state.activeFilter != nil || state.showFavoritesOnly ? Color.accentGreen : .white)
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(localized: "Filter photos")))
    }

    private var sortMenu: some View {
        Menu {
            ForEach(PhotoSortOption.allCases) { option in
                Button {
                    state.photoSortOption = option
                } label: {
                    Label(option.title, systemImage: state.photoSortOption == option ? "checkmark" : "")
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(state.photoSortOption == .fileName ? .white : Color.accentGreen)
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(localized: "Sort photos")))
    }

    private var selectionModeButton: some View {
        Button {
            state.isSelectionMode.toggle()
        } label: {
            Label(selectionButtonTitle, systemImage: state.isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.system(size: 14, weight: .bold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(state.isSelectionMode ? Color.accentGreen : .white)
                .padding(.horizontal, 12)
                .frame(height: 48)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(state.isSelectionMode ? "Done selecting" : "Select photos"))
    }

    private var selectionButtonTitle: String {
        if state.isSelectionMode {
            return String(localized: "Done")
        }
        if !state.selectedPhotos.isEmpty {
            return String(format: String(localized: "Select (%d)"), state.selectedPhotos.count)
        }
        return String(localized: "Select")
    }

    @ViewBuilder
    private var selectionToolbar: some View {
        if state.isSelectionMode {
            HStack(spacing: 10) {
                Label(
                    String(format: String(localized: "%d selected"), state.selectedPhotos.count),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.accentGreen)

                Spacer()

                Button {
                    state.selectAllFilteredPhotos()
                } label: {
                    Label(String(localized: "Select All"), systemImage: "checkmark.circle")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.bordered)
                .disabled(state.filteredPhotos.isEmpty)

                Button {
                    state.clearSelection()
                } label: {
                    Label(String(localized: "Clear"), systemImage: "xmark.circle")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.bordered)
                .disabled(state.selectedPhotos.isEmpty)

                Button(role: .destructive) {
                    showDeleteSelectionConfirmation = true
                } label: {
                    Label(String(localized: "Delete"), systemImage: "trash")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(state.selectedPhotos.isEmpty)
            }
            .padding(12)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.06)))
        }
    }

    private var sessionBar: some View {
        Menu {
            Button(String(localized: "All Sessions")) {
                state.selectedSessionName = nil
            }
            ForEach(state.sessionNames, id: \.self) { session in
                Button {
                    state.selectedSessionName = session
                } label: {
                    Label(session, systemImage: state.selectedSessionName == session ? "checkmark" : "")
                }
            }
            Divider()
            Button(String(localized: "Manage Sessions")) {
                showSessionManager = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))

                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "Shoot Session"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                    Text(state.selectedSessionName ?? String(localized: "All Sessions"))
                        .font(.system(size: 16, weight: .semibold))
                }

                Spacer()

                Text(String(format: String(localized: "%d photos"), state.visiblePhotoCount))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.66))
                Text(String(localized: "Manage"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.accentGreen)
                Image(systemName: "chevron.down")
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(14)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(localized: "Manage shoot sessions")))
    }

    private var sessionManagerSheet: some View {
        SessionManagerSheet(isPresented: $showSessionManager)
            .environmentObject(state)
        .presentationDetents([.medium, .large])
    }

    private var filterTabs: some View {
        HStack {
            filterButton(String(localized: "All"), nil, favorites: false, count: nil)
            filterButton(String(localized: "New"), .raw, favorites: false, count: state.photos.filter { $0.status == .raw }.count)
            filterButton(String(localized: "Edited"), .edited, favorites: false, count: state.photos.filter { $0.status == .edited }.count)
            filterButton(String(localized: "Favorites"), nil, favorites: true, count: state.photos.filter(\.isFavorite).count)
            filterButton(String(localized: "Exported"), .exported, favorites: false, count: state.photos.filter { $0.status == .exported }.count)
        }
        .padding(.top, 4)
    }

    private var galleryScaleControls: some View {
        HStack(spacing: 10) {
            Label(String(localized: "Grid size"), systemImage: "rectangle.grid.2x2")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.68))

            Spacer()

            Button {
                galleryColumnCount = min(4, galleryColumnCount + 1)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 38, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(galleryColumnCount >= 4 ? .white.opacity(0.28) : .white)
            .disabled(galleryColumnCount >= 4)
            .accessibilityLabel(Text(String(localized: "Decrease grid size")))

            Text(String(format: String(localized: "%d columns"), galleryColumnCount))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 68)

            Button {
                galleryColumnCount = max(2, galleryColumnCount - 1)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 38, height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(galleryColumnCount <= 2 ? .white.opacity(0.28) : .white)
            .disabled(galleryColumnCount <= 2)
            .accessibilityLabel(Text(String(localized: "Increase grid size")))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.05)))
    }

    private func filterButton(_ title: String, _ status: PhotoStatus?, favorites: Bool, count: Int?) -> some View {
        let selected = state.activeFilter == status && state.showFavoritesOnly == favorites
        return Button {
            state.setStatusFilter(status, favoritesOnly: favorites)
        } label: {
            VStack(spacing: 7) {
                HStack(spacing: 5) {
                    Text(title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    if let count {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                }
                .font(.system(size: 14, weight: .medium))
                Rectangle()
                    .fill(selected ? .white : .clear)
                    .frame(width: 28, height: 2)
            }
            .foregroundStyle(selected ? .white : .white.opacity(0.62))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var photoGrid: some View {
        Group {
            if state.filteredPhotos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.accentGreen)
                    Text(String(localized: "No photos yet"))
                        .font(.system(size: 18, weight: .bold))
                    Text(String(localized: "Import from Photos to start a local shoot session."))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .multilineTextAlignment(.center)
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label(String(localized: "Import from Photos"), systemImage: "photo.badge.plus")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentGreen)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 54)
                .padding(.horizontal, 18)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.05)))
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(state.filteredPhotos) { photo in
                        PhotoTile(photo: photo)
                    }
                }
            }
        }
    }
}

struct PhotoTile: View {
    @EnvironmentObject private var state: LutShopAppState
    let photo: Photo

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.clear)
                .overlay {
                    PhotoAssetView(
                        imageName: photo.imageName,
                        imagePath: photo.imagePath,
                        fallbackColors: photo.palette,
                        lutFileName: state.appliedLutFileName(for: photo),
                        lutPath: state.appliedLutPath(for: photo),
                        lutIntensity: photo.lutIntensity,
                        contentMode: .fit,
                        imageScale: 1
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(.black.opacity(0.10))
                .aspectRatio(1, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    Text(photo.formatBadgeText)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 5))
                        .padding(7)
                }
                .overlay(alignment: .topTrailing) {
                    if state.isSelectionMode {
                        Button {
                            state.toggleSelection(photo.id)
                        } label: {
                            Image(systemName: photo.isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 23, weight: .bold))
                                .foregroundStyle(photo.isSelected ? Color.accentGreen : .white.opacity(0.78), .white)
                                .frame(width: 34, height: 34)
                                .background(.black.opacity(0.28), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                    } else if photo.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(.yellow)
                            .padding(8)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selectionBorderColor, lineWidth: photo.isSelected ? 2 : 1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    state.openOrTogglePhoto(photo.id)
                }
                .onLongPressGesture(minimumDuration: 0.35) {
                    if !state.isSelectionMode {
                        state.isSelectionMode = true
                    }
                    if !photo.isSelected {
                        state.toggleSelection(photo.id)
                    }
                }

            HStack(spacing: 6) {
                Text(photo.fileName)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 4)
                Text(photo.rating > 0 ? String(repeating: "★", count: photo.rating) : "•••")
                    .lineLimit(1)
                    .font(.system(size: photo.rating > 0 ? 10 : 12, weight: .bold))
                    .frame(width: photo.rating > 0 ? 34 : 20, alignment: .trailing)
            }
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .contextMenu {
            Button(String(localized: "Select")) {
                if !state.isSelectionMode {
                    state.isSelectionMode = true
                }
                if !photo.isSelected {
                    state.toggleSelection(photo.id)
                }
            }
            Button(photo.isFavorite ? String(localized: "Unfavorite") : String(localized: "Favorite")) { state.toggleFavorite(photo.id) }
        }
    }

    private var selectionBorderColor: Color {
        guard photo.isSelected else { return .white.opacity(0.05) }
        return state.isSelectionMode ? Color.accentGreen : .white
    }
}

private struct SessionManagerSheet: View {
    @EnvironmentObject private var state: LutShopAppState
    @Binding var isPresented: Bool
    @State private var newSessionName = ""
    @State private var renameDraft = ""
    @State private var renamingSession: String?
    @State private var deleteCandidate: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summary
                    createSession
                    sessionList
                    footerNote
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(String(localized: "Sessions"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        isPresented = false
                    }
                }
            }
            .alert(String(localized: "Rename Session"), isPresented: Binding(
                get: { renamingSession != nil },
                set: { if !$0 { renamingSession = nil } }
            )) {
                TextField(String(localized: "Session name"), text: $renameDraft)
                Button(String(localized: "Cancel"), role: .cancel) {
                    renamingSession = nil
                }
                Button(String(localized: "Rename")) {
                    if let renamingSession {
                        state.renameSession(named: renamingSession, to: renameDraft)
                    }
                    renamingSession = nil
                }
                .disabled(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text(String(localized: "Rename this shoot session. Photos in the session keep their adjustments."))
            }
            .confirmationDialog(String(localized: "Delete Empty Session"), isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ), titleVisibility: .visible) {
                Button(String(localized: "Delete Empty Session"), role: .destructive) {
                    if let deleteCandidate {
                        state.deleteSession(named: deleteCandidate)
                    }
                    deleteCandidate = nil
                }
                Button(String(localized: "Cancel"), role: .cancel) {
                    deleteCandidate = nil
                }
            } message: {
                Text(String(localized: "Only empty sessions can be deleted. Photos are never removed from here."))
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(localized: "Shoot Sessions"))
                        .font(.system(size: 22, weight: .bold))
                    Text(String(localized: "Group imported photos by shoot, client, or delivery batch."))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(state.sessionNames.count)")
                        .font(.system(size: 24, weight: .bold))
                    Text(String(localized: "sessions"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.56))
                }
            }

            HStack(spacing: 10) {
                metric(value: "\(state.totalPhotoCount)", label: String(localized: "total photos"))
                metric(value: "\(state.selectedSessionPhotoCount)", label: String(localized: "visible session"))
            }
        }
        .padding(16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.06)))
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
    }

    private var createSession: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Create Session"))
                .font(.system(size: 15, weight: .bold))

            HStack(spacing: 10) {
                TextField(String(localized: "2026-06 Client Shoot"), text: $newSessionName)
                    .textInputAutocapitalization(.words)
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 12)
                    .frame(height: 46)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.07)))

                Button {
                    state.createSession(named: newSessionName)
                    newSessionName = ""
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 46, height: 46)
                        .background(Color.accentGreen, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                .disabled(newSessionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(newSessionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                .accessibilityLabel(Text(String(localized: "Create Session")))
            }
        }
    }

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Session Library"))
                .font(.system(size: 15, weight: .bold))

            SessionRow(
                title: String(localized: "All Sessions"),
                subtitle: String(localized: "Every imported photo"),
                count: state.totalPhotoCount,
                isSelected: state.selectedSessionName == nil,
                canDelete: false,
                selectAction: {
                    state.selectedSessionName = nil
                },
                renameAction: nil,
                deleteAction: nil
            )

            ForEach(state.sessionNames, id: \.self) { session in
                SessionRow(
                    title: session,
                    subtitle: state.photoCount(in: session) == 0 ? String(localized: "Empty session") : String(localized: "Ready for sorting and export"),
                    count: state.photoCount(in: session),
                    isSelected: state.selectedSessionName == session,
                    canDelete: state.canDeleteSession(named: session),
                    selectAction: {
                        state.selectedSessionName = session
                    },
                    renameAction: {
                        renameDraft = session
                        renamingSession = session
                    },
                    deleteAction: {
                        deleteCandidate = session
                    }
                )
            }
        }
    }

    private var footerNote: some View {
        Text(String(localized: "Import will later default to the active session, so sessions can become the project boundary for CV recommendations, batch LUT application, and export delivery."))
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.5))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SessionRow: View {
    let title: String
    let subtitle: String
    let count: Int
    let isSelected: Bool
    let canDelete: Bool
    let selectAction: () -> Void
    let renameAction: (() -> Void)?
    let deleteAction: (() -> Void)?

    var body: some View {
        Button(action: selectAction) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.accentGreen : .white.opacity(0.08))
                    Image(systemName: isSelected ? "checkmark" : "folder")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isSelected ? .black : .white.opacity(0.72))
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text("\(count)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isSelected ? Color.accentGreen : .white.opacity(0.72))
                    .frame(minWidth: 28, alignment: .trailing)

                Menu {
                    if let renameAction {
                        Button(String(localized: "Rename"), action: renameAction)
                    }
                    if let deleteAction {
                        Button(String(localized: "Delete Empty Session"), role: .destructive, action: deleteAction)
                            .disabled(!canDelete)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white.opacity(renameAction == nil && deleteAction == nil ? 0.22 : 0.72))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(renameAction == nil && deleteAction == nil)
                .accessibilityLabel(Text(String(localized: "Session actions")))
            }
            .padding(12)
            .background(.white.opacity(isSelected ? 0.11 : 0.06), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.accentGreen.opacity(0.72) : .white.opacity(0.05)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}
