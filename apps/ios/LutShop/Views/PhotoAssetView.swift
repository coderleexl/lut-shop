import SwiftUI
import UIKit

struct PhotoAssetView: View {
    let imageName: String
    var imagePath: String?
    var fallbackColors: [Color]
    var lutFileName: String?
    var lutIntensity: Double = 0

    var body: some View {
        if let image = UIImage.lutShopPhoto(
            named: imageName,
            path: imagePath,
            applyingBundledLutNamed: lutFileName,
            intensity: lutIntensity
        ) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .scaleEffect(1.45)
        } else {
            LinearGradient(colors: fallbackColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private extension UIImage {
    static func lutShopPhoto(
        named name: String,
        path: String?,
        applyingBundledLutNamed lutFileName: String? = nil,
        intensity: Double = 0
    ) -> UIImage? {
        if let lutFileName, intensity > 0 {
            if let path,
               let image = LutShopCppBridge.previewImage(
                byApplyingBundledLutNamed: lutFileName,
                toImageAtPath: path,
                intensity: intensity
               ) {
                return image
            }
            return LutShopCppBridge.previewImage(
                byApplyingBundledLutNamed: lutFileName,
                toImageNamed: name,
                intensity: intensity
            )
        }

        if let path, let image = UIImage(contentsOfFile: path) {
            return image
        }

        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: "jpg",
            subdirectory: "PrototypePhotos"
        ) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}
