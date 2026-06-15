import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

final class CoreImageLutRenderer {
    static let shared = CoreImageLutRenderer()

    private struct ParsedCube {
        let size: Int
        let entries: [SIMD3<Float>]
    }

    private let context = CIContext(options: [
        .workingColorSpace: CGColorSpaceCreateDeviceRGB(),
        .outputColorSpace: CGColorSpaceCreateDeviceRGB()
    ])
    private var cubeCache: [String: ParsedCube] = [:]
    private let lock = NSLock()

    private init() {}

    func applyBundledLut(named fileName: String, toImageNamed imageName: String, intensity: Double) -> UIImage? {
        guard let image = prototypeImage(named: imageName),
              let url = Bundle.main.url(
                forResource: (fileName as NSString).deletingPathExtension,
                withExtension: "cube",
                subdirectory: "BundledLuts"
              ) else {
            return nil
        }
        return applyLut(at: url, to: image, intensity: intensity)
    }

    func applyBundledLut(named fileName: String, toImageAtPath imagePath: String, intensity: Double) -> UIImage? {
        guard let image = UIImage(contentsOfFile: imagePath),
              let url = Bundle.main.url(
                forResource: (fileName as NSString).deletingPathExtension,
                withExtension: "cube",
                subdirectory: "BundledLuts"
              ) else {
            return nil
        }
        return applyLut(at: url, to: image, intensity: intensity)
    }

    func applyUserLut(atPath lutPath: String, toImageNamed imageName: String, intensity: Double) -> UIImage? {
        guard let image = prototypeImage(named: imageName) else { return nil }
        return applyLut(at: URL(fileURLWithPath: lutPath), to: image, intensity: intensity)
    }

    func applyUserLut(atPath lutPath: String, toImageAtPath imagePath: String, intensity: Double) -> UIImage? {
        guard let image = UIImage(contentsOfFile: imagePath) else { return nil }
        return applyLut(at: URL(fileURLWithPath: lutPath), to: image, intensity: intensity)
    }

    func applyLut(at url: URL, to image: UIImage, intensity: Double) -> UIImage? {
        guard intensity > 0 else { return image }
        guard let cube = parsedCube(at: url) else { return nil }
        let normalized = image.lutShopNormalizedForRendering()
        guard let inputImage = CIImage(image: normalized),
              let filter = CIFilter(name: "CIColorCubeWithColorSpace") else {
            return nil
        }

        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(cube.size, forKey: "inputCubeDimension")
        filter.setValue(cubeData(for: cube, intensity: intensity), forKey: "inputCubeData")
        filter.setValue(CGColorSpaceCreateDeviceRGB(), forKey: "inputColorSpace")

        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: inputImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: normalized.scale, orientation: .up)
    }

    private func parsedCube(at url: URL) -> ParsedCube? {
        let key = url.path
        lock.lock()
        if let cached = cubeCache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let text = try? String(contentsOf: url, encoding: .utf8),
              let parsed = Self.parseCube(text) else {
            return nil
        }

        lock.lock()
        cubeCache[key] = parsed
        lock.unlock()
        return parsed
    }

    private static func parseCube(_ text: String) -> ParsedCube? {
        var size = 0
        var entries: [SIMD3<Float>] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }

            let parts = line.split { $0 == " " || $0 == "\t" }.map(String.init)
            guard let first = parts.first else { continue }
            if first == "TITLE" { continue }
            if first == "LUT_3D_SIZE", parts.count >= 2 {
                size = Int(parts[1]) ?? 0
                continue
            }
            if first.hasPrefix("LUT_") || first.hasPrefix("DOMAIN_") {
                continue
            }
            guard parts.count >= 3,
                  let r = Float(parts[0]),
                  let g = Float(parts[1]),
                  let b = Float(parts[2]) else {
                continue
            }
            entries.append(SIMD3(r, g, b))
        }

        guard size > 0, entries.count == size * size * size else {
            return nil
        }
        return ParsedCube(size: size, entries: entries)
    }

    private func cubeData(for cube: ParsedCube, intensity: Double) -> Data {
        let blend = Float(min(max(intensity, 0), 1))
        var values = [Float]()
        values.reserveCapacity(cube.entries.count * 4)

        for blueIndex in 0..<cube.size {
            for greenIndex in 0..<cube.size {
                for redIndex in 0..<cube.size {
                    let index = blueIndex * cube.size * cube.size + greenIndex * cube.size + redIndex
                    let input = SIMD3(
                        Float(redIndex) / Float(cube.size - 1),
                        Float(greenIndex) / Float(cube.size - 1),
                        Float(blueIndex) / Float(cube.size - 1)
                    )
                    let output = input + (cube.entries[index] - input) * blend
                    values.append(Self.clamp01(output.x))
                    values.append(Self.clamp01(output.y))
                    values.append(Self.clamp01(output.z))
                    values.append(1.0)
                }
            }
        }

        return values.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    private static func clamp01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    private func prototypeImage(named imageName: String) -> UIImage? {
        guard let url = Bundle.main.url(
            forResource: imageName,
            withExtension: "jpg",
            subdirectory: "PrototypePhotos"
        ) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}

private extension UIImage {
    func lutShopNormalizedForRendering() -> UIImage {
        guard imageOrientation != .up else { return self }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }
}
