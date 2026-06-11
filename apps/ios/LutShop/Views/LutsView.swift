import SwiftUI

struct LutsView: View {
    @EnvironmentObject private var state: LutShopAppState
    @State private var category: LutCategory?
    @State private var query = ""
    @State private var selectedLut: LutPreset?
    @State private var deletingLut: LutPreset?
    @State private var showDeleteConfirmation = false
    @State private var renameText = ""
    @State private var importMessage: String?

    private var visibleLuts: [LutPreset] {
        state.luts.filter { lut in
            (category == nil || lut.category == category)
                && (query.isEmpty
                    || lut.name.localizedCaseInsensitiveContains(query)
                    || lut.tags.contains { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("LUT Library")
                    .font(.system(size: 32, weight: .bold))
                Spacer()
                GlassButton(systemName: "plus") {
                    state.importMockLut()
                    importMessage = String(localized: "Imported mock LUT")
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

            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search LUT", text: $query)
            }
            .padding(13)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryButton(String(localized: "All"), nil)
                    ForEach(LutCategory.allCases) { item in
                        categoryButton(item.title, item)
                    }
                }
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(visibleLuts) { lut in
                        LutLibraryRow(
                            lut: lut,
                            isActive: state.activeLutId == lut.id,
                            apply: { apply(lut) },
                            toggleFavorite: { state.toggleLutFavorite(lut.id) },
                            showDetails: {
                                selectedLut = lut
                                renameText = lut.name
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

    private func categoryButton(_ title: String, _ value: LutCategory?) -> some View {
        Button {
            category = value
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(category == value ? Color.accentGreen.opacity(0.25) : .white.opacity(0.08), in: Capsule())
                .foregroundStyle(category == value ? Color.accentGreen : .white.opacity(0.72))
        }
        .buttonStyle(.plain)
    }

    private func apply(_ lut: LutPreset) {
        state.activeLutId = lut.id
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

            Text("\(lut.category.title) · \(lut.usageCount) uses")
                .foregroundStyle(.white.opacity(0.62))

            Text(lut.tags.joined(separator: " · "))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.56))

            HStack {
                Button(String(localized: "Save")) {
                    state.renameLut(lut.id, to: renameText)
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
}

private struct LutLibraryRow: View {
    let lut: LutPreset
    let isActive: Bool
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
                Text("\(lut.category.title) · \(lut.usageCount) uses")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.56))
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
