import SwiftUI

struct GlassButton: View {
    let systemName: String
    var isActive = false
    var accessibilityLabel: String?
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(isActive ? Color.accentGreen : .white)
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel ?? systemName))
    }
}

struct BottomTabBar: View {
    @EnvironmentObject private var state: LutShopAppState

    var body: some View {
        HStack {
            ForEach(MainTab.allCases) { tab in
                Button {
                    state.selectedTab = tab
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22, weight: .medium))
                        Text(tab.titleKey)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(state.selectedTab == tab ? Color.accentGreen : .white.opacity(0.64))
                    .frame(maxWidth: .infinity)
                    .frame(height: 66)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(tab.titleKey))
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .background(.black.opacity(0.86))
        .overlay(alignment: .top) {
            Divider().background(.white.opacity(0.12))
        }
    }
}

struct MessageToast: View {
    let message: String
    var dismiss: () -> Void

    var body: some View {
        Button(action: dismiss) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.accentGreen)
                Text(message)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(message))
    }
}

struct SelectionActionBar: View {
    @EnvironmentObject private var state: LutShopAppState
    let photo: Photo

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.clear)
                .overlay {
                    PhotoAssetView(
                        imageName: photo.imageName,
                        imagePath: photo.imagePath,
                        fallbackColors: photo.palette,
                        lutFileName: state.appliedLutFileName(for: photo),
                        lutPath: state.appliedLutPath(for: photo),
                        lutIntensity: photo.lutIntensity
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 42, height: 42)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.2)))

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: String(localized: "%d selected"), state.selectedPhotos.count))
                    .font(.system(size: 14, weight: .semibold))
                Text(photo.fileName)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }
            .frame(width: 104, alignment: .leading)

            Button {
                state.clearSelection()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.78))
            .accessibilityLabel(Text(String(localized: "Clear selection")))

            ActionButton(title: String(localized: "Apply LUT"), icon: "wand.and.stars") {
                state.selectedTab = .luts
            }
            Menu {
                ForEach(1...5, id: \.self) { rating in
                    Button(String(format: String(localized: "%d Star"), rating)) {
                        state.rateSelectedPhotos(rating)
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "star")
                        .font(.system(size: 21, weight: .medium))
                    Text(String(localized: "Rate"))
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 52)
            }
            .foregroundStyle(.white)
            .accessibilityLabel(Text(String(localized: "Rate selected photos")))
            ActionButton(title: String(localized: "Export"), icon: "square.and.arrow.up") {
                state.selectedTab = .export
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 68)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 6)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .medium))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 52)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel(Text(title))
    }
}

struct LutStrip: View {
    let colors: [Color]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                color
            }
        }
        .clipShape(Capsule())
    }
}

extension Color {
    static let accentGreen = Color(red: 0.56, green: 0.82, blue: 0.34)
}
