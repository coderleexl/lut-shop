import SwiftUI

struct PreviewView: View {
    @EnvironmentObject private var state: LutShopAppState

    var body: some View {
        VStack(spacing: 14) {
            topBar
            imagePreview
            lutRecommendations
            adjustmentPanel
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 86)
        .background(Color.black.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            GlassButton(systemName: "chevron.left") {
                state.selectedTab = .gallery
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(state.currentPhoto?.fileName ?? String(localized: "Preview"))
                    .font(.system(size: 17, weight: .semibold))
                Text(state.previewCompareEnabled ? String(localized: "Before / After") : String(localized: "After · \(Int(state.lutIntensity * 100))%"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            GlassButton(systemName: state.currentPhoto?.isFavorite == true ? "star.fill" : "star") {
                if let id = state.currentPhoto?.id {
                    state.toggleFavorite(id)
                }
            }
        }
    }

    private var imagePreview: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(.clear)
            .overlay {
                comparePreviewContent
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(.black.opacity(0.04))
            .overlay(alignment: .topLeading) {
                Text(state.previewCompareEnabled ? String(localized: "Before") : state.activeLut?.name ?? String(localized: "No LUT"))
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(12)
            }
            .overlay(alignment: .topTrailing) {
                if state.previewCompareEnabled {
                    Text(String(localized: "After"))
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.45), in: Capsule())
                        .padding(12)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { index in
                        Button {
                            state.rateCurrentPhoto(index)
                        } label: {
                            Image(systemName: index <= (state.currentPhoto?.rating ?? 0) ? "star.fill" : "star")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(index <= (state.currentPhoto?.rating ?? 0) ? .yellow : .white.opacity(0.45))
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(0.78, contentMode: .fit)
    }

    private var comparePreviewContent: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let dividerX = width * state.previewComparePosition

            ZStack(alignment: .leading) {
                previewImage(isBefore: false)

                if state.previewCompareEnabled {
                    previewImage(isBefore: true)
                        .frame(width: dividerX, alignment: .leading)
                        .clipped()

                    compareDivider(x: dividerX)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard state.previewCompareEnabled, width > 0 else { return }
                        state.setPreviewComparePosition(value.location.x / width)
                    }
            )
        }
    }

    private func previewImage(isBefore: Bool) -> some View {
        Group {
            if let photo = state.currentPhoto {
                PhotoAssetView(
                    imageName: photo.imageName,
                    imagePath: photo.imagePath,
                    fallbackColors: isBefore ? [.gray, .black] : photo.palette,
                    lutFileName: isBefore ? nil : state.activeLut?.sourceFileName,
                    lutIntensity: isBefore ? 0 : state.lutIntensity
                )
            } else {
                LinearGradient(colors: [.gray, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    private func compareDivider(x: Double) -> some View {
        Rectangle()
            .fill(.white.opacity(0.88))
            .frame(width: 2)
            .overlay {
                Circle()
                    .fill(.black.opacity(0.55))
                    .frame(width: 42, height: 42)
                    .overlay(Circle().stroke(.white.opacity(0.75), lineWidth: 1))
                    .overlay {
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
            }
            .offset(x: x - 1)
    }

    private var lutRecommendations: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(state.recommendedLuts + state.luts.filter { !state.recommendedLuts.contains($0) }) { lut in
                    Button {
                        state.activeLutId = lut.id
                        state.validateLutLoad(lut.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            LutStrip(colors: lut.previewColors)
                                .frame(width: 112, height: 34)
                            Text(lut.name)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            if let confidence = lut.confidence {
                                Text(String(localized: "CV \(confidence)%"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.accentGreen)
                            }
                        }
                        .padding(10)
                        .frame(width: 132, alignment: .leading)
                        .background(.white.opacity(state.activeLutId == lut.id ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(state.activeLutId == lut.id ? Color.accentGreen : .white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var adjustmentPanel: some View {
        VStack(spacing: 14) {
            HStack {
                Text(String(localized: "LUT Intensity"))
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(Int(state.lutIntensity * 100))%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.accentGreen)
            }
            Slider(value: $state.lutIntensity, in: 0...1)
            HStack {
                Button(state.previewCompareEnabled ? String(localized: "Show After") : String(localized: "Compare")) {
                    state.previewCompareEnabled.toggle()
                }
                .buttonStyle(.bordered)
                Button(String(localized: "Undo")) {
                    state.resetCurrentPhotoAdjustment()
                }
                .buttonStyle(.bordered)
                Button(String(localized: "Save")) {
                    state.applyActiveLutToCurrentPhoto()
                }
                .buttonStyle(.borderedProminent)
            }
            Button {
                state.syncCurrentAdjustmentToOtherSelectedPhotos()
            } label: {
                Label(String(localized: "Sync to Selected"), systemImage: "square.stack.3d.down.right")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(state.selectedPhotosExcludingCurrentCount == 0)
            .opacity(state.selectedPhotosExcludingCurrentCount == 0 ? 0.48 : 1)
        }
        .padding(14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}
