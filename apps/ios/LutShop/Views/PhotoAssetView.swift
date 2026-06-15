import SwiftUI
import UIKit

struct PhotoAssetView: View {
    let imageName: String
    var imagePath: String?
    var fallbackColors: [Color]
    var lutFileName: String?
    var lutPath: String?
    var lutIntensity: Double = 0
    var watermarkSettings: WatermarkSettings?
    var exifSummary: PhotoExifSummary?
    var fileName: String = ""
    var sessionName: String = ""

    var body: some View {
        if let image = UIImage.lutShopPhoto(
            named: imageName,
            path: imagePath,
            applyingBundledLutNamed: lutFileName,
            applyingLutAtPath: lutPath,
            intensity: lutIntensity,
            watermarkSettings: watermarkSettings,
            exifSummary: exifSummary,
            fileName: fileName,
            sessionName: sessionName
        ) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: watermarkSettings?.isEnabled == true ? .fit : .fill)
                .scaleEffect(watermarkSettings?.isEnabled == true ? 1 : 1.45)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            LinearGradient(colors: fallbackColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private extension UIImage {
    static func lutShopPhoto(
        named name: String,
        path: String?,
        applyingBundledLutNamed lutFileName: String? = nil,
        applyingLutAtPath lutPath: String? = nil,
        intensity: Double = 0,
        watermarkSettings: WatermarkSettings? = nil,
        exifSummary: PhotoExifSummary? = nil,
        fileName: String = "",
        sessionName: String = ""
    ) -> UIImage? {
        let baseImage: UIImage?
        if let lutPath, intensity > 0 {
            if let path,
               let image = CoreImageLutRenderer.shared.applyUserLut(
                atPath: lutPath,
                toImageAtPath: path,
                intensity: intensity
               ) {
                baseImage = image
            } else if let image = CoreImageLutRenderer.shared.applyUserLut(
                atPath: lutPath,
                toImageNamed: name,
                intensity: intensity
            ) {
                baseImage = image
            } else if let path,
               let image = LutShopCppBridge.applyUserLut(
                atPath: lutPath,
                toImageAtPath: path,
                intensity: intensity
               ) {
                baseImage = image
            } else {
                baseImage = LutShopCppBridge.applyUserLut(
                    atPath: lutPath,
                    toImageNamed: name,
                    intensity: intensity
                )
            }
        } else if let lutFileName, intensity > 0 {
            if let path,
               let image = CoreImageLutRenderer.shared.applyBundledLut(
                named: lutFileName,
                toImageAtPath: path,
                intensity: intensity
               ) {
                baseImage = image
            } else if let image = CoreImageLutRenderer.shared.applyBundledLut(
                named: lutFileName,
                toImageNamed: name,
                intensity: intensity
            ) {
                baseImage = image
            } else if let path,
               let image = LutShopCppBridge.previewImage(
                byApplyingBundledLutNamed: lutFileName,
                toImageAtPath: path,
                intensity: intensity
               ) {
                baseImage = image
            } else {
                baseImage = LutShopCppBridge.previewImage(
                    byApplyingBundledLutNamed: lutFileName,
                    toImageNamed: name,
                    intensity: intensity
                )
            }
        } else if let path, let image = UIImage(contentsOfFile: path) {
            baseImage = image
        } else if let url = Bundle.main.url(
            forResource: name,
            withExtension: "jpg",
            subdirectory: "PrototypePhotos"
        ) {
            baseImage = UIImage(contentsOfFile: url.path)
        } else {
            baseImage = nil
        }

        guard let baseImage else { return nil }
        guard let watermarkSettings, watermarkSettings.isEnabled else {
            return baseImage
        }

        return WatermarkRenderer.render(
            image: baseImage,
            photo: Photo(
                id: "preview",
                fileName: fileName.isEmpty ? name : fileName,
                imageName: name,
                imagePath: path,
                sessionName: sessionName,
                status: .edited,
                isFavorite: false,
                isSelected: false,
                rating: 0,
                appliedLutId: nil,
                lutIntensity: intensity,
                recommendedLutIds: [],
                palette: [],
                exifSummary: exifSummary
            ),
            settings: watermarkSettings
        )
    }
}
