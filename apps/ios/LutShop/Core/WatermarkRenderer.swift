import Foundation
import ImageIO
import UIKit

enum WatermarkRenderer {
    static func brandLogoName(for source: String) -> String {
        let normalized = source.uppercased()
        if normalized.contains("NIKON") {
            return "nikon"
        }
        if normalized.contains("SONY") || normalized.contains("ILCE") || normalized.contains("ALPHA") || normalized.contains("A7") {
            return "sony"
        }
        if normalized.contains("CANON") {
            return "canon"
        }
        if normalized.contains("FUJI") {
            return "fujifilm"
        }
        if normalized.contains("LEICA") {
            return "leica"
        }
        if normalized.contains("PANASONIC") || normalized.contains("LUMIX") {
            return "panasonic"
        }
        if normalized.contains("APPLE") || normalized.contains("IPHONE") {
            return "apple"
        }
        return "default"
    }

    static func brandLogoImage(for source: String) -> UIImage? {
        let name = brandLogoName(for: source)
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "BrandLogos") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    static func exifSummary(fromImageData data: Data) -> PhotoExifSummary? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return exifSummary(from: source)
    }

    static func exifSummary(fromImageAtPath path: String?) -> PhotoExifSummary? {
        guard let path, !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return exifSummary(from: source)
    }

    static func render(image: UIImage, photo: Photo, settings: WatermarkSettings) -> UIImage {
        guard settings.style != .none else { return image }

        let sourceImage = normalized(image)
        let imageSize = sourceImage.size
        guard imageSize.width > 1, imageSize.height > 1 else { return image }

        let shortSide = min(imageSize.width, imageSize.height)
        let ratio = imageSize.width / imageSize.height
        let isPortrait = ratio < 0.88
        let outerPadding = outerPadding(for: settings.style, shortSide: shortSide)
        let footerHeight = footerHeight(for: settings.style, imageSize: imageSize, isPortrait: isPortrait)
        let canvasSize = CGSize(
            width: imageSize.width + outerPadding * 2,
            height: imageSize.height + outerPadding + footerHeight
        )
        let imageRect = CGRect(
            x: outerPadding,
            y: outerPadding,
            width: imageSize.width,
            height: imageSize.height
        )
        let radius = clamp(shortSide * 0.095 * CGFloat(settings.cornerRadius), min: 0, max: shortSide * 0.08)

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true

        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
            backgroundColor(for: settings.style).setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            let path = UIBezierPath(roundedRect: imageRect, cornerRadius: radius)
            context.cgContext.saveGState()
            path.addClip()
            sourceImage.draw(in: imageRect)
            context.cgContext.restoreGState()

            UIColor.black.withAlphaComponent(0.08).setStroke()
            path.lineWidth = max(1, shortSide * 0.0015)
            path.stroke()

            drawFooter(
                in: CGRect(
                    x: outerPadding,
                    y: imageRect.maxY,
                    width: imageSize.width,
                    height: footerHeight
                ),
                photo: photo,
                settings: settings
            )
        }
    }

    private static func outerPadding(for style: WatermarkStyle, shortSide: CGFloat) -> CGFloat {
        switch style {
        case .none:
            return 0
        case .filmBorder:
            return clamp(shortSide * 0.018, min: 10, max: 42)
        case .hasselbladMinimal:
            return clamp(shortSide * 0.045, min: 22, max: 86)
        case .leicaMinimal:
            return clamp(shortSide * 0.04, min: 20, max: 78)
        case .appleMinimal:
            return clamp(shortSide * 0.026, min: 14, max: 52)
        }
    }

    private static func footerHeight(for style: WatermarkStyle, imageSize: CGSize, isPortrait: Bool) -> CGFloat {
        switch style {
        case .none:
            return 0
        case .filmBorder:
            return clamp(imageSize.width * (isPortrait ? 0.17 : 0.095), min: 92, max: 260)
        case .hasselbladMinimal:
            return clamp(imageSize.width * (isPortrait ? 0.2 : 0.12), min: 110, max: 310)
        case .leicaMinimal:
            return clamp(imageSize.width * (isPortrait ? 0.18 : 0.1), min: 96, max: 280)
        case .appleMinimal:
            return clamp(imageSize.width * (isPortrait ? 0.13 : 0.075), min: 70, max: 190)
        }
    }

    private static func backgroundColor(for style: WatermarkStyle) -> UIColor {
        switch style {
        case .none, .filmBorder, .hasselbladMinimal, .leicaMinimal:
            return .white
        case .appleMinimal:
            return UIColor(red: 0.972, green: 0.972, blue: 0.96, alpha: 1)
        }
    }

    private static func exifSummary(from source: CGImageSource) -> PhotoExifSummary? {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else {
            return nil
        }

        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let exifAux = properties[kCGImagePropertyExifAuxDictionary] as? [CFString: Any]

        let make = stringValue(tiff?[kCGImagePropertyTIFFMake])
        let model = stringValue(tiff?[kCGImagePropertyTIFFModel])
        let lens = stringValue(exif?[kCGImagePropertyExifLensModel])
            ?? stringValue(exifAux?[kCGImagePropertyExifAuxLensModel])
        let focalLength = focalLengthText(exif?[kCGImagePropertyExifFocalLength])
        let aperture = apertureText(exif?[kCGImagePropertyExifFNumber])
        let shutter = shutterText(exif?[kCGImagePropertyExifExposureTime])
        let iso = isoText(exif?[kCGImagePropertyExifISOSpeedRatings])
        let capturedAt = stringValue(exif?[kCGImagePropertyExifDateTimeOriginal])
            ?? stringValue(tiff?[kCGImagePropertyTIFFDateTime])

        let summary = PhotoExifSummary(
            cameraMake: make,
            cameraModel: model,
            lensModel: lens,
            focalLength: focalLength,
            aperture: aperture,
            shutterSpeed: shutter,
            iso: iso,
            capturedAt: capturedAt
        )

        if [
            summary.cameraMake,
            summary.cameraModel,
            summary.lensModel,
            summary.focalLength,
            summary.aperture,
            summary.shutterSpeed,
            summary.iso,
            summary.capturedAt
        ].allSatisfy({ ($0 ?? "").isEmpty }) {
            return nil
        }
        return summary
    }

    private static func drawFooter(in rect: CGRect, photo: Photo, settings: WatermarkSettings) {
        let exif: PhotoExifSummary? = settings.showExif
            ? (photo.exifSummary ?? exifSummary(fromImageAtPath: photo.imagePath) ?? fallbackExifSummary())
            : nil
        let brandSource = [
            exif?.cameraMake,
            exif?.cameraModel
        ]
            .compactMap { trimmedNonEmpty($0) }
            .joined(separator: " ")
        let resolvedBrandSource = brandSource.isEmpty ? "SONY ILCE-7M4" : brandSource
        let camera = exif?.cameraDisplayName ?? "SONY ILCE-7M4"
        let lens = exif?.lensModel ?? "FE 70-200mm F2.8 GM OSS II"
        let exposure = exif?.exposureDisplayText ?? "200mm  f/2.8  1/250s  ISO 100"
        let date = normalizedDateText(exif?.capturedAt)

        switch settings.style {
        case .none:
            return
        case .filmBorder:
            drawStandardFooter(
                in: rect,
                camera: camera,
                lens: lens,
                exposure: exposure,
                date: date,
                brandSource: resolvedBrandSource
            )
        case .hasselbladMinimal:
            drawHasselbladFooter(in: rect, camera: camera, lens: lens, exposure: exposure, date: date)
        case .leicaMinimal:
            drawLeicaFooter(in: rect, camera: camera, lens: lens, exposure: exposure, date: date, brandSource: resolvedBrandSource)
        case .appleMinimal:
            drawAppleFooter(in: rect, camera: camera, lens: lens, exposure: exposure, date: date, brandSource: resolvedBrandSource)
        }
    }

    private static func drawStandardFooter(
        in rect: CGRect,
        camera: String,
        lens: String,
        exposure: String,
        date: String?,
        brandSource: String
    ) {
        let contentTop = rect.minY + rect.height * 0.14
        let contentHeight = rect.height * 0.68
        let gap = clamp(rect.width * 0.02, min: 12, max: 46)
        let logoSize = clamp(contentHeight * 0.98, min: 56, max: rect.width * 0.13)
        let rightWidth = clamp(rect.width * 0.31, min: rect.width * 0.25, max: rect.width * 0.38)
        let rightX = rect.maxX - rightWidth
        let separatorWidth = max(1, rect.width * 0.001)
        let separatorX = rightX - gap * 0.72
        let logoRect = CGRect(
            x: separatorX - gap - logoSize,
            y: contentTop + (contentHeight - logoSize) / 2,
            width: logoSize,
            height: logoSize
        )
        let leftTextX = rect.minX
        let leftTextWidth = max(1, logoRect.minX - rect.minX - gap)

        UIColor.black.withAlphaComponent(0.12).setFill()
        UIBezierPath(
            roundedRect: CGRect(
                x: separatorX,
                y: contentTop + contentHeight * 0.08,
                width: separatorWidth,
                height: contentHeight * 0.84
            ),
            cornerRadius: separatorWidth / 2
        ).fill()

        if let logo = brandLogoImage(for: brandSource) {
            drawImageFitted(logo, in: logoRect)
        } else {
            drawFitted(
                brandLogoName(for: brandSource).uppercased(),
                in: logoRect,
                baseFont: .systemFont(ofSize: logoRect.height * 0.2, weight: .bold),
                minFontSize: 7,
                color: UIColor(red: 0.16, green: 0.16, blue: 0.16, alpha: 1),
                alignment: .center
            )
        }

        let topFont = clamp(rect.height * 0.2, min: 16, max: 34)
        let bottomFont = clamp(rect.height * 0.155, min: 12, max: 25)
        let topRect = CGRect(x: leftTextX, y: contentTop + contentHeight * 0.1, width: leftTextWidth, height: contentHeight * 0.34)
        let bottomRect = CGRect(x: leftTextX, y: contentTop + contentHeight * 0.55, width: leftTextWidth, height: contentHeight * 0.28)

        drawFitted(
            camera,
            in: topRect,
            baseFont: .systemFont(ofSize: topFont, weight: .bold),
            minFontSize: 10,
            color: UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1),
            alignment: .left
        )
        drawFitted(
            lens,
            in: bottomRect,
            baseFont: .systemFont(ofSize: bottomFont, weight: .regular),
            minFontSize: 9,
            color: UIColor(red: 0.32, green: 0.32, blue: 0.32, alpha: 1),
            alignment: .left
        )

        drawFitted(
            exposure,
            in: CGRect(x: rightX, y: topRect.minY, width: rightWidth, height: topRect.height),
            baseFont: .systemFont(ofSize: topFont, weight: .bold),
            minFontSize: 10,
            color: UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1),
            alignment: .right
        )
        drawFitted(
            date ?? "",
            in: CGRect(x: rightX, y: bottomRect.minY, width: rightWidth, height: bottomRect.height),
            baseFont: .systemFont(ofSize: bottomFont, weight: .regular),
            minFontSize: 9,
            color: UIColor(red: 0.36, green: 0.36, blue: 0.36, alpha: 1),
            alignment: .right
        )
    }

    private static func drawHasselbladFooter(in rect: CGRect, camera: String, lens: String, exposure: String, date: String?) {
        let isNarrow = rect.width < rect.height * 4.8
        let brand = camera
        let detail = [lens, exposure, date].compactMap { trimmedNonEmpty($0) }.joined(separator: "   ")

        let brandFont = clamp(rect.height * (isNarrow ? 0.2 : 0.23), min: 17, max: 40)
        let detailFont = clamp(rect.height * (isNarrow ? 0.115 : 0.13), min: 10, max: 22)
        let brandRect = CGRect(
            x: rect.minX,
            y: rect.minY + rect.height * (isNarrow ? 0.16 : 0.18),
            width: rect.width,
            height: rect.height * 0.32
        )
        let detailRect = CGRect(
            x: rect.minX + rect.width * 0.07,
            y: rect.minY + rect.height * (isNarrow ? 0.53 : 0.56),
            width: rect.width * 0.86,
            height: rect.height * 0.22
        )

        drawFitted(
            brand,
            in: brandRect,
            baseFont: hasselbladBrandFont(ofSize: brandFont),
            minFontSize: 10,
            color: UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1),
            alignment: .center,
            kern: isNarrow ? 1.1 : 1.8
        )
        drawFitted(
            detail,
            in: detailRect,
            baseFont: .systemFont(ofSize: detailFont, weight: .regular),
            minFontSize: 8,
            color: UIColor(red: 0.36, green: 0.36, blue: 0.36, alpha: 1),
            alignment: .center,
            kern: 0.6
        )
    }

    private static func hasselbladBrandFont(ofSize size: CGFloat) -> UIFont {
        if let font = UIFont(name: "Didot-Italic", size: size) {
            return font
        }
        let descriptor = UIFont.systemFont(ofSize: size, weight: .semibold).fontDescriptor
        if let serif = descriptor.withDesign(.serif),
           let italic = serif.withSymbolicTraits(.traitItalic) {
            return UIFont(descriptor: italic, size: size)
        }
        if let italic = descriptor.withSymbolicTraits(.traitItalic) {
            return UIFont(descriptor: italic, size: size)
        }
        return .italicSystemFont(ofSize: size)
    }

    private static func drawLeicaFooter(in rect: CGRect, camera: String, lens: String, exposure: String, date: String?, brandSource: String) {
        let isNarrow = rect.width < rect.height * 5
        let dotSize = clamp(rect.height * 0.42, min: 34, max: 74)
        let dotRect = CGRect(
            x: rect.minX,
            y: rect.midY - dotSize / 2,
            width: dotSize,
            height: dotSize
        )
        UIColor(red: 0.86, green: 0, blue: 0.07, alpha: 1).setFill()
        UIBezierPath(ovalIn: dotRect).fill()

        drawFitted(
            brandLogoName(for: brandSource).uppercased(),
            in: dotRect.insetBy(dx: dotSize * 0.12, dy: dotSize * 0.28),
            baseFont: .italicSystemFont(ofSize: dotSize * 0.22),
            minFontSize: 6,
            color: .white,
            alignment: .center,
            kern: 0
        )

        let textX = dotRect.maxX + clamp(rect.width * 0.025, min: 12, max: 34)
        let textWidth = rect.maxX - textX
        let topFont = clamp(rect.height * (isNarrow ? 0.16 : 0.18), min: 13, max: 30)
        let bottomFont = clamp(rect.height * (isNarrow ? 0.11 : 0.13), min: 9, max: 21)
        let detail = [lens, exposure, date].compactMap { trimmedNonEmpty($0) }.joined(separator: "   ")

        drawFitted(
            camera.uppercased(),
            in: CGRect(x: textX, y: rect.minY + rect.height * 0.25, width: textWidth, height: rect.height * 0.25),
            baseFont: .systemFont(ofSize: topFont, weight: .bold),
            minFontSize: 9,
            color: UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1),
            alignment: .left,
            kern: 0.8
        )
        drawFitted(
            detail,
            in: CGRect(x: textX, y: rect.minY + rect.height * 0.53, width: textWidth, height: rect.height * 0.24),
            baseFont: .systemFont(ofSize: bottomFont, weight: .regular),
            minFontSize: 7,
            color: UIColor(red: 0.36, green: 0.36, blue: 0.36, alpha: 1),
            alignment: .left,
            kern: 0.4
        )
    }

    private static func drawAppleFooter(in rect: CGRect, camera: String, lens: String, exposure: String, date: String?, brandSource: String) {
        let isNarrow = rect.width < rect.height * 5
        let left = camera
        let detail = isNarrow
            ? [exposure, date].compactMap { trimmedNonEmpty($0) }.joined(separator: "  ")
            : [lens, exposure, date].compactMap { trimmedNonEmpty($0) }.joined(separator: "  ")
        let topFont = clamp(rect.height * 0.18, min: 12, max: 26)
        let bottomFont = clamp(rect.height * 0.13, min: 9, max: 18)
        let logoSize = clamp(rect.height * 0.32, min: 18, max: 42)
        let logoRect = CGRect(x: rect.minX, y: rect.minY + rect.height * 0.34, width: logoSize, height: logoSize)
        let textX = logoRect.maxX + clamp(rect.width * 0.018, min: 8, max: 22)
        let textWidth = rect.width - (textX - rect.minX)

        if let logo = brandLogoImage(for: brandSource) {
            drawImageFitted(logo, in: logoRect)
        } else {
            drawFitted(
                brandLogoName(for: brandSource).uppercased(),
                in: logoRect,
                baseFont: .systemFont(ofSize: topFont * 0.72, weight: .semibold),
                minFontSize: 7,
                color: .black,
                alignment: .center
            )
        }

        drawFitted(
            left,
            in: CGRect(x: textX, y: rect.minY + rect.height * 0.27, width: textWidth, height: rect.height * 0.24),
            baseFont: .systemFont(ofSize: topFont, weight: .semibold),
            minFontSize: 9,
            color: UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1),
            alignment: .left
        )
        drawFitted(
            detail,
            in: CGRect(x: textX, y: rect.minY + rect.height * 0.53, width: textWidth, height: rect.height * 0.22),
            baseFont: .systemFont(ofSize: bottomFont, weight: .regular),
            minFontSize: 7,
            color: UIColor(red: 0.36, green: 0.36, blue: 0.36, alpha: 1),
            alignment: .left
        )
    }

    private static func fallbackExifSummary() -> PhotoExifSummary {
        PhotoExifSummary(
            cameraMake: "SONY",
            cameraModel: "ILCE-7M4",
            lensModel: "FE 70-200mm F2.8 GM OSS II",
            focalLength: "200mm",
            aperture: "f/2.8",
            shutterSpeed: "1/250s",
            iso: "ISO 100",
            capturedAt: todayText()
        )
    }

    private static func drawFitted(
        _ text: String,
        in rect: CGRect,
        baseFont: UIFont,
        minFontSize: CGFloat,
        color: UIColor,
        alignment: NSTextAlignment,
        kern: CGFloat = 0.2
    ) {
        guard !text.isEmpty, rect.width > 1, rect.height > 1 else { return }
        var font = baseFont
        while font.pointSize > minFontSize {
            let measured = (text as NSString).boundingRect(
                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: rect.height),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: font, .kern: kern],
                context: nil
            )
            if measured.width <= rect.width {
                break
            }
            font = font.withSize(font.pointSize - 1)
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byTruncatingMiddle
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
            .kern: kern
        ]
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes,
            context: nil
        )
    }

    private static func drawImageFitted(_ image: UIImage, in rect: CGRect) {
        guard rect.width > 1, rect.height > 1, image.size.width > 1, image.size.height > 1 else { return }
        let scale = min(rect.width / image.size.width, rect.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let target = CGRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        image.draw(in: target)
    }

    private static func normalizedDateText(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
            .replacingOccurrences(of: ":", with: "-", options: [], range: value.startIndex..<value.index(value.startIndex, offsetBy: min(10, value.count)))
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private static func todayText() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private static func focalLengthText(_ value: Any?) -> String? {
        guard let number = numberValue(value), number > 0 else { return nil }
        return "\(rounded(number))mm"
    }

    private static func apertureText(_ value: Any?) -> String? {
        guard let number = numberValue(value), number > 0 else { return nil }
        return "f/\(rounded(number))"
    }

    private static func shutterText(_ value: Any?) -> String? {
        guard let number = numberValue(value), number > 0 else { return nil }
        if number >= 1 {
            return "\(rounded(number))s"
        }
        let denominator = max(1, Int(round(1 / number)))
        return "1/\(denominator)s"
    }

    private static func isoText(_ value: Any?) -> String? {
        if let values = value as? [Any], let first = values.first {
            return isoText(first)
        }
        guard let number = numberValue(value), number > 0 else { return nil }
        return "ISO \(Int(round(number)))"
    }

    private static func numberValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }

    private static func rounded(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.05 {
            return "\(Int(round(value)))"
        }
        return String(format: "%.1f", value)
    }

    private static func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }

    private static func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}
