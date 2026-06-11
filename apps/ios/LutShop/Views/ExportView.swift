import SwiftUI

struct ExportView: View {
    @EnvironmentObject private var state: LutShopAppState
    @State private var isExporting = false
    @State private var progress = 0.0
    @State private var didComplete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(state.selectedPhotos.count) Selected")
                        .font(.system(size: 30, weight: .bold))
                    Text("Batch process and export")
                        .foregroundStyle(.white.opacity(0.56))
                }
                Spacer()
                Button("Cancel") {
                    state.selectedTab = .gallery
                }
                .buttonStyle(.bordered)
            }

            if state.selectedPhotos.isEmpty {
                emptyState
            } else {
                selectedList
                activeLutPanel
                settingsPanel
                progressPanel

                Button {
                    startExport()
                } label: {
                    Label(didComplete ? String(localized: "Export Again") : String(localized: "Export Photos"), systemImage: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentGreen)
                .disabled(isExporting)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 24)
        .padding(.bottom, 86)
        .background(Color.black.ignoresSafeArea())
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.stack")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
            Text(String(localized: "No photos selected"))
                .font(.system(size: 20, weight: .bold))
            Text(String(localized: "Select photos in Gallery before starting a batch export."))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.58))
                .multilineTextAlignment(.center)
            Button(String(localized: "Go to Gallery")) {
                state.selectedTab = .gallery
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accentGreen)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var selectedList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(state.selectedPhotos) { photo in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.clear)
                        .overlay {
                            PhotoAssetView(imageName: photo.imageName, fallbackColors: photo.palette)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(width: 88, height: 112)
                        .overlay(alignment: .bottomLeading) {
                            Text(photo.fileName)
                                .font(.system(size: 10, weight: .bold))
                                .lineLimit(1)
                                .padding(7)
                        }
                }
            }
        }
    }

    private var activeLutPanel: some View {
        HStack(spacing: 12) {
            if let lut = state.activeLut {
                LutStrip(colors: lut.previewColors)
                    .frame(width: 84, height: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(lut.name)
                        .font(.system(size: 15, weight: .semibold))
                    Text(String(localized: "Applied at \(Int(state.lutIntensity * 100))% intensity"))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.56))
                }
            } else {
                Text(String(localized: "No LUT selected"))
                    .font(.system(size: 15, weight: .semibold))
            }
            Spacer()
            Button(String(localized: "Choose")) {
                state.selectedTab = .luts
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var settingsPanel: some View {
        VStack(spacing: 12) {
            Picker(String(localized: "Format"), selection: $state.exportSettings.format) {
                Text("JPG").tag("JPG")
                Text("PNG").tag("PNG")
            }
            Picker(String(localized: "Size"), selection: $state.exportSettings.size) {
                Text("Original").tag("Original")
                Text("2048px").tag("2048px")
                Text("1080px").tag("1080px")
            }
            Picker(String(localized: "Quality"), selection: $state.exportSettings.quality) {
                Text("High").tag("High")
                Text("Medium").tag("Medium")
                Text("Low").tag("Low")
            }
            Toggle("Preserve EXIF", isOn: $state.exportSettings.preserveExif)
        }
        .pickerStyle(.segmented)
        .padding(14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: progress)
                .tint(Color.accentGreen)
            HStack {
                Text(progressLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(didComplete ? Color.accentGreen : .white.opacity(0.68))
                Spacer()
                if didComplete {
                    Button(String(localized: "Clear")) {
                        state.clearSelection()
                        progress = 0
                        didComplete = false
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .opacity(isExporting || didComplete ? 1 : 0.72)
    }

    private var progressLabel: String {
        if didComplete {
            return String(localized: "Export complete")
        }
        if isExporting {
            return String(localized: "Exporting \(Int(progress * 100))%")
        }
        return String(localized: "Ready to export")
    }

    private func startExport() {
        guard !state.selectedPhotos.isEmpty, !isExporting else { return }
        isExporting = true
        progress = 0
        didComplete = false
        Task {
            for step in 1...10 {
                try? await Task.sleep(for: .milliseconds(120))
                progress = Double(step) / 10
            }
            state.markSelectionExported()
            isExporting = false
            didComplete = true
        }
    }
}
