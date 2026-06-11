import SwiftUI
import UIKit

struct PhotoAssetView: View {
    let imageName: String
    var fallbackColors: [Color]

    var body: some View {
        if let image = UIImage.prototypePhoto(named: imageName) {
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
    static func prototypePhoto(named name: String) -> UIImage? {
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
