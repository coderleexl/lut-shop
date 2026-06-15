import SwiftUI
import UniformTypeIdentifiers

struct LutsView: View {
    @EnvironmentObject private var state: LutShopAppState
    @State private var categoryGroupId: String?
    @State private var query = ""
    @State private var selectedLut: LutPreset?
    @State private var deletingLut: LutPreset?
    @State private var showDeleteConfirmation = false
    @State private var renameText = ""
    @State private var selectedDetailCategoryGroupId = ""
    @State private var importMessage: String?
    @State private var showAddLut = false
    @State private var showCategoryManager = false

    private var visibleLuts: [LutPreset] {
        state.luts.filter { lut in
            lut.hasRenderableSource
                && (categoryGroupId == nil || (lut.categoryGroupId ?? lut.category.rawValue) == categoryGroupId)
                && (query.isEmpty
                    || lut.name.localizedCaseInsensitiveContains(query)
                    || lut.tags.contains { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(String(localized: "LUT Library"))
                    .font(.system(size: 32, weight: .bold))
                Spacer()
                GlassButton(systemName: "folder.badge.plus") {
                    showCategoryManager = true
                }
                GlassButton(systemName: "plus") {
                    showAddLut = true
                }
            }

            if let importMessage {
                Label(importMessage, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentGreen.opacity(0.12), in: Capsule())
            }

            if let lutLoadMessage = state.lutLoadMessage, !lutLoadMessage.isEmpty {
                Label(lutLoadMessage, systemImage: "cpu.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }

            HStack {
                Image(systemName: "magnifyingglass")
                TextField(String(localized: "Search LUT"), text: $query)
            }
            .padding(13)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryButton(String(localized: "All"), nil)
                    ForEach(state.visibleLutCategories) { item in
                        categoryButton(item.title, item.id)
                    }
                }
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(visibleLuts) { lut in
                        LutLibraryRow(
                            lut: lut,
                            isActive: state.activeLutId == lut.id,
                            categoryTitle: categoryTitle(for: lut),
                            apply: { apply(lut) },
                            toggleFavorite: { state.toggleLutFavorite(lut.id) },
                            showDetails: {
                                selectedLut = lut
                                renameText = lut.name
                                selectedDetailCategoryGroupId = lut.categoryGroupId ?? lut.category.rawValue
                            }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 24)
        .padding(.bottom, 86)
        .background(Color.black.ignoresSafeArea())
        .sheet(item: $selectedLut) { lut in
            lutDetail(lut)
        }
        .sheet(isPresented: $showAddLut) {
            AddLutSheet(categories: state.visibleLutCategories) { name, path, categoryGroupId, fileURL in
                if let message = state.importUserLut(name: name, path: path, categoryGroupId: categoryGroupId, fileURL: fileURL) {
                    importMessage = message
                }
                showAddLut = false
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showCategoryManager) {
            LutCategoryManagerSheet(
                categories: state.visibleLutCategories,
                lutCount: { state.lutCount(inCategoryGroup: $0) },
                create: { name in
                    _ = state.createLutCategory(named: name)
                },
                delete: { groupId in
                    if categoryGroupId == groupId {
                        categoryGroupId = nil
                    }
                    _ = state.deleteLutCategory(groupId)
                }
            )
            .presentationDetents([.medium])
        }
        .confirmationDialog(String(localized: "Delete LUT?"), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "Delete"), role: .destructive) {
                if let deletingLut {
                    state.deleteLut(deletingLut.id)
                }
                selectedLut = nil
                deletingLut = nil
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                deletingLut = nil
            }
        } message: {
            Text(deletingLut?.name ?? "")
        }
    }

    private func categoryButton(_ title: String, _ value: String?) -> some View {
        Button {
            categoryGroupId = value
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(categoryGroupId == value ? Color.accentGreen.opacity(0.25) : .white.opacity(0.08), in: Capsule())
                .foregroundStyle(categoryGroupId == value ? Color.accentGreen : .white.opacity(0.72))
        }
        .buttonStyle(.plain)
    }

    private func apply(_ lut: LutPreset) {
        state.activeLutId = lut.id
        state.validateLutLoad(lut.id)
        if state.selectedPhotos.isEmpty {
            state.selectedTab = .preview
        } else {
            state.applyActiveLutToSelection()
        }
    }

    private func lutDetail(_ lut: LutPreset) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(.white.opacity(0.18))
                .frame(width: 42, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

            Text(String(localized: "LUT Details"))
                .font(.system(size: 26, weight: .bold))

            LutStrip(colors: lut.previewColors)
                .frame(height: 54)

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Name"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                TextField(String(localized: "LUT name"), text: $renameText)
                    .textFieldStyle(.roundedBorder)
            }

            Text("\(categoryTitle(for: lut)) · \(lut.usageCount) uses")
                .foregroundStyle(.white.opacity(0.62))

            Picker(String(localized: "Category"), selection: $selectedDetailCategoryGroupId) {
                ForEach(state.visibleLutCategories) { item in
                    Text(item.title).tag(item.id)
                }
            }
            .pickerStyle(.menu)

            if let metadata = lut.metadataSummary {
                Label(metadata, systemImage: "cube.transparent")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentGreen)
            }

            if let userPath = lut.userPath {
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(localized: "Path"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(userPath)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .textSelection(.enabled)
                }
            }

            Text(lut.tags.joined(separator: " · "))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.56))

            HStack {
                Button(String(localized: "Save")) {
                    state.renameLut(lut.id, to: renameText)
                    state.updateLutCategory(lut.id, to: selectedDetailCategoryGroupId)
                    selectedLut = nil
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentGreen)

                Button(lut.isFavorite ? String(localized: "Unfavorite") : String(localized: "Favorite")) {
                    state.toggleLutFavorite(lut.id)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(String(localized: "Delete"), role: .destructive) {
                    deletingLut = lut
                    showDeleteConfirmation = true
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding(20)
        .presentationDetents([.medium])
        .background(Color.black.ignoresSafeArea())
    }

    private func categoryTitle(for lut: LutPreset) -> String {
        let groupId = lut.categoryGroupId ?? lut.category.rawValue
        return state.visibleLutCategories.first { $0.id == groupId }?.title ?? lut.category.title
    }
}

private struct AddLutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var path = ""
    @State private var categoryGroupId = ""
    @State private var selectedFileURL: URL?
    @State private var showFileImporter = false
    let categories: [LutCategoryGroup]
    let save: (String, String, String, URL?) -> Void

    private var canSave: Bool {
        (!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedFileURL != nil)
            && (!path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedFileURL != nil)
            && !categoryGroupId.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "LUT Info")) {
                    TextField(String(localized: "LUT name"), text: $name)
                    TextField(String(localized: "Local path or network URL"), text: $path, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(2...4)

                    Button {
                        showFileImporter = true
                    } label: {
                        Label(String(localized: "Choose Local File"), systemImage: "doc.badge.plus")
                    }

                    if let selectedFileURL {
                        Label(selectedFileURL.lastPathComponent, systemImage: "doc.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Section(String(localized: "Category")) {
                    Picker(String(localized: "Category"), selection: $categoryGroupId) {
                        ForEach(categories) { item in
                            Text(item.title).tag(item.id)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(String(localized: "Add LUT"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Save")) {
                        save(name, path, categoryGroupId, selectedFileURL)
                    }
                    .disabled(!canSave)
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                selectedFileURL = url
                path = url.path
                if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    name = url.deletingPathExtension().lastPathComponent
                }
            }
            .onAppear {
                if categoryGroupId.isEmpty {
                    categoryGroupId = categories.first?.id ?? ""
                }
            }
        }
    }
}

private struct LutCategoryManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newCategoryName = ""
    @State private var deletingCategory: LutCategoryGroup?
    @State private var showDeleteConfirmation = false
    let categories: [LutCategoryGroup]
    let lutCount: (String) -> Int
    let create: (String) -> Void
    let delete: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Create Group")) {
                    HStack {
                        TextField(String(localized: "Group name"), text: $newCategoryName)
                        Button(String(localized: "Add")) {
                            create(newCategoryName)
                            newCategoryName = ""
                        }
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section(String(localized: "Groups")) {
                    ForEach(categories) { category in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.title)
                                Text(String(
                                    format: String(localized: "%d LUT(s)"),
                                    lutCount(category.id)
                                ))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if category.isSystem {
                                Text(String(localized: "System"))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            } else {
                                Button(role: .destructive) {
                                    deletingCategory = category
                                    showDeleteConfirmation = true
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(String(localized: "LUT Groups"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                String(localized: "Delete LUT Group?"),
                isPresented: $showDeleteConfirmation
            ) {
                Button(String(localized: "Delete Group and LUTs"), role: .destructive) {
                    if let deletingCategory {
                        delete(deletingCategory.id)
                    }
                    deletingCategory = nil
                }
                Button(String(localized: "Cancel"), role: .cancel) {
                    deletingCategory = nil
                }
            } message: {
                if let deletingCategory {
                    Text(String(
                        format: String(localized: "This will delete %@ and %d LUT(s)."),
                        deletingCategory.title,
                        lutCount(deletingCategory.id)
                    ))
                }
            }
        }
    }
}

private struct LutLibraryRow: View {
    let lut: LutPreset
    let isActive: Bool
    let categoryTitle: String
    let apply: () -> Void
    let toggleFavorite: () -> Void
    let showDetails: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            LutStrip(colors: lut.previewColors)
                .frame(width: 72, height: 42)
                .onTapGesture(perform: apply)

            VStack(alignment: .leading, spacing: 5) {
                Text(lut.name)
                    .font(.system(size: 16, weight: .semibold))
                Text("\(categoryTitle) · \(lut.usageCount) uses")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.56))
                if let metadata = lut.metadataSummary {
                    Text(metadata)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentGreen.opacity(0.86))
                        .lineLimit(1)
                }
                Text(lut.tags.joined(separator: " · "))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: apply)

            Spacer()

            Button(action: toggleFavorite) {
                Image(systemName: lut.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(lut.isFavorite ? .yellow : .white.opacity(0.58))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)

            Button(action: showDetails) {
                Image(systemName: "info.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.white.opacity(isActive ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isActive ? Color.accentGreen : .white.opacity(0.06)))
    }
}

private extension LutPreset {
    var metadataSummary: String? {
        guard let cubeSize, let cubeEntryCount else { return nil }
        let owner = provider ?? String(localized: "Bundled")
        return "\(owner) CUBE · \(cubeSize)^3 · \(cubeEntryCount) entries"
    }
}
