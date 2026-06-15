import SwiftUI
import UIKit

struct WatermarkView: View {
    @EnvironmentObject private var state: LutShopAppState

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var sampleExif: PhotoExifSummary {
        PhotoExifSummary(
            cameraMake: "SONY",
            cameraModel: "ILCE-7M4",
            lensModel: "FE 35mm F1.4 GM",
            focalLength: "35mm",
            aperture: "f/2.8",
            shutterSpeed: "1/250s",
            iso: "ISO 100",
            capturedAt: "2026-06-15 18:24"
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                topBar
                previewCard
                templateGrid
                settingsPanel
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 98)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            GlassButton(systemName: "chevron.left") {
                state.selectedTab = .gallery
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Watermark"))
                    .font(.system(size: 17, weight: .semibold))
                Text(String(localized: "Camera brand and exposure data"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            statusPill
        }
    }

    private var statusPill: some View {
        Text(state.watermarkSettings.isEnabled ? String(localized: "Enabled") : String(localized: "Off"))
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(state.watermarkSettings.isEnabled ? .black : .white.opacity(0.6))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                state.watermarkSettings.isEnabled ? Color.accentGreen : Color.white.opacity(0.08),
                in: Capsule()
            )
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Sample Preview"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.62))

            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.05))
                .overlay {
                    watermarkPreview(style: state.watermarkSettings.style, large: true)
                        .padding(10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.12), lineWidth: 1))
                .frame(maxWidth: .infinity)
                .aspectRatio(0.78, contentMode: .fit)
        }
        .padding(12)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private var templateGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Watermark Templates"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.62))

            LazyVGrid(columns: columns, spacing: 12) {
                templateCard(
                    style: .none,
                    title: String(localized: "No Watermark"),
                    subtitle: String(localized: "Clean export")
                )
                templateCard(
                    style: .filmBorder,
                    title: String(localized: "Film Border"),
                    subtitle: String(localized: "Camera brand and exposure data")
                )
                templateCard(
                    style: .hasselbladMinimal,
                    title: String(localized: "Hasselblad Minimal"),
                    subtitle: String(localized: "Large border and centered brand")
                )
                templateCard(
                    style: .leicaMinimal,
                    title: String(localized: "Leica Minimal"),
                    subtitle: String(localized: "Red dot and clean metadata")
                )
                templateCard(
                    style: .appleMinimal,
                    title: String(localized: "Apple Minimal"),
                    subtitle: String(localized: "Small mark and clean metadata")
                )
            }
        }
    }

    private func templateCard(style: WatermarkStyle, title: String, subtitle: String) -> some View {
        let selected = state.watermarkSettings.style == style

        return Button {
            state.watermarkSettings.style = style
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.05))
                    .overlay {
                        watermarkPreview(style: style, large: false)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1.0, contentMode: .fit)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .background(.white.opacity(selected ? 0.12 : 0.07), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Color.white.opacity(0.88) : Color.white.opacity(0.08), lineWidth: selected ? 1.4 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.accentGreen)
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func watermarkPreview(style: WatermarkStyle, large: Bool) -> some View {
        Group {
            switch style {
            case .none:
                sampleImage
                    .clipShape(RoundedRectangle(cornerRadius: large ? 10 : 7))
            case .filmBorder:
                VStack(spacing: 0) {
                    sampleImage
                        .clipShape(RoundedRectangle(cornerRadius: CGFloat(state.watermarkSettings.cornerRadius) * (large ? 28 : 18)))
                        .padding(.horizontal, large ? 10 : 5)
                        .padding(.top, large ? 10 : 5)
                    filmFooterPreview(large: large)
                        .padding(.horizontal, large ? 10 : 5)
                        .padding(.vertical, large ? 8 : 5)
                }
                .background(.white, in: RoundedRectangle(cornerRadius: large ? 8 : 5))
            case .hasselbladMinimal:
                VStack(spacing: 0) {
                    sampleImage
                        .clipShape(RoundedRectangle(cornerRadius: CGFloat(state.watermarkSettings.cornerRadius) * (large ? 30 : 18)))
                        .padding(.horizontal, large ? 18 : 8)
                        .padding(.top, large ? 18 : 8)
                    hasselbladFooterPreview(large: large)
                        .padding(.horizontal, large ? 18 : 8)
                        .padding(.vertical, large ? 12 : 7)
                }
                .background(.white, in: RoundedRectangle(cornerRadius: large ? 8 : 5))
            case .leicaMinimal:
                VStack(spacing: 0) {
                    sampleImage
                        .clipShape(RoundedRectangle(cornerRadius: CGFloat(state.watermarkSettings.cornerRadius) * (large ? 28 : 16)))
                        .padding(.horizontal, large ? 16 : 7)
                        .padding(.top, large ? 16 : 7)
                    leicaFooterPreview(large: large)
                        .padding(.horizontal, large ? 16 : 7)
                        .padding(.vertical, large ? 10 : 6)
                }
                .background(.white, in: RoundedRectangle(cornerRadius: large ? 8 : 5))
            case .appleMinimal:
                VStack(spacing: 0) {
                    sampleImage
                        .clipShape(RoundedRectangle(cornerRadius: CGFloat(state.watermarkSettings.cornerRadius) * (large ? 24 : 14)))
                        .padding(.horizontal, large ? 12 : 6)
                        .padding(.top, large ? 12 : 6)
                    appleFooterPreview(large: large)
                        .padding(.horizontal, large ? 12 : 6)
                        .padding(.vertical, large ? 8 : 5)
                }
                .background(Color(red: 0.972, green: 0.972, blue: 0.96), in: RoundedRectangle(cornerRadius: large ? 8 : 5))
            }
        }
    }

    private var sampleImage: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.13, green: 0.2, blue: 0.21),
                        Color(red: 0.44, green: 0.56, blue: 0.49),
                        Color(red: 0.9, green: 0.76, blue: 0.52)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [7, 7]))
                    .padding(18)
            }
    }

    private func filmFooterPreview(large: Bool) -> some View {
        HStack(spacing: large ? 10 : 5) {
            VStack(alignment: .leading, spacing: large ? 3 : 1) {
                Text(sampleExif.cameraDisplayName ?? "SONY ILCE-7M4")
                    .font(.system(size: large ? 13 : 7, weight: .bold))
                    .lineLimit(1)
                Text(sampleExif.lensModel ?? "FE 35mm F1.4 GM")
                    .font(.system(size: large ? 10 : 5, weight: .medium))
                    .foregroundStyle(.black.opacity(0.58))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            brandLogoView(large: large)

            Rectangle()
                .fill(Color.black.opacity(0.14))
                .frame(width: 1, height: large ? 34 : 18)

            if state.watermarkSettings.showExif {
                VStack(alignment: .trailing, spacing: large ? 3 : 1) {
                    Text(sampleExif.exposureDisplayText ?? "35mm f/2.8 1/250s ISO 100")
                        .font(.system(size: large ? 12 : 6, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                    Text("2026-06-15 18:24")
                        .font(.system(size: large ? 9 : 5, weight: .medium))
                        .foregroundStyle(.black.opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
    }

    private func hasselbladFooterPreview(large: Bool) -> some View {
        VStack(spacing: large ? 5 : 2) {
            Text("Hasselblad")
                .font(.system(size: large ? 17 : 8, weight: .semibold, design: .serif))
                .italic()
                .tracking(large ? 1.2 : 0.45)
                .lineLimit(1)
            Text("FE 35mm F1.4 GM   35mm f/2.8 1/250s ISO 100")
                .font(.system(size: large ? 9 : 4.5, weight: .regular))
                .foregroundStyle(.black.opacity(0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
    }

    private func leicaFooterPreview(large: Bool) -> some View {
        HStack(spacing: large ? 10 : 5) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.86, green: 0, blue: 0.07))
                Text("Leica")
                    .font(.system(size: large ? 9 : 4.5, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: large ? 34 : 17, height: large ? 34 : 17)
            VStack(alignment: .leading, spacing: large ? 3 : 1) {
                Text("LEICA CAMERA")
                    .font(.system(size: large ? 12 : 6, weight: .bold))
                    .lineLimit(1)
                Text("35mm f/2.8 1/250s ISO 100")
                    .font(.system(size: large ? 9 : 4.5, weight: .regular))
                    .foregroundStyle(.black.opacity(0.52))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
    }

    private func appleFooterPreview(large: Bool) -> some View {
        HStack(spacing: large ? 8 : 4) {
            if let image = WatermarkRenderer.brandLogoImage(for: "APPLE") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: large ? 20 : 10, height: large ? 20 : 10)
            }
            VStack(alignment: .leading, spacing: large ? 3 : 1) {
                Text("iPhone Pro")
                    .font(.system(size: large ? 12 : 6, weight: .semibold))
                    .lineLimit(1)
                Text("35mm f/2.8 1/250s ISO 100")
                    .font(.system(size: large ? 9 : 4.5, weight: .regular))
                    .foregroundStyle(.black.opacity(0.52))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func brandLogoView(large: Bool) -> some View {
        if let image = WatermarkRenderer.brandLogoImage(for: "SONY ILCE-7M4") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: large ? 48 : 24, height: large ? 34 : 17)
        } else {
            Text("SONY")
                .font(.system(size: large ? 12 : 6, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: large ? 48 : 24, height: large ? 34 : 17)
        }
    }

    private var settingsPanel: some View {
        VStack(spacing: 14) {
            HStack {
                Text(String(localized: "Corner Radius"))
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(Int(state.watermarkSettings.cornerRadius * 100))%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.accentGreen)
            }
            Slider(value: $state.watermarkSettings.cornerRadius, in: 0...1)
                .disabled(!state.watermarkSettings.isEnabled)

            Toggle(String(localized: "Show EXIF Info"), isOn: $state.watermarkSettings.showExif)
                .font(.system(size: 14, weight: .semibold))
                .disabled(!state.watermarkSettings.isEnabled)

            exifInfoPanel
        }
        .padding(14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var exifInfoPanel: some View {
        let exifRows: [(String, String)] = [
            (String(localized: "Camera"), sampleExif.cameraDisplayName),
            (String(localized: "Lens"), sampleExif.lensModel),
            (String(localized: "Exposure"), sampleExif.exposureDisplayText),
            (String(localized: "Date"), sampleExif.capturedAt)
        ].compactMap { label, value in
            guard let value, !value.isEmpty else { return nil }
            return (label, value)
        }

        return VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Preview EXIF"))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
            ForEach(exifRows, id: \.0) { label, value in
                HStack {
                    Text(label)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text(value)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(10)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        .opacity(state.watermarkSettings.showExif ? 1 : 0.45)
    }
}
