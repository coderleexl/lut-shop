import Foundation
import SwiftUI

protocol LutShopCoreBridge {
    func loadInitialPhotos() -> [Photo]
    func loadLuts() -> [LutPreset]
    func recommendLuts(for photo: Photo, from luts: [LutPreset]) -> [LutPreset]
    func apply(lut: LutPreset, intensity: Double, to photos: [Photo]) -> [Photo]
    func rate(_ photos: [Photo], rating: Int) -> [Photo]
    func markExported(_ photos: [Photo]) -> [Photo]
    func toggleFavorite(lut: LutPreset) -> LutPreset
    func rename(lut: LutPreset, to name: String) -> LutPreset
    func makeImportedLut(existingCount: Int) -> LutPreset
    func loadSummary(for lut: LutPreset) -> String?
    func previewPixelSummary(for lut: LutPreset) -> String?
}

final class MockLutShopCoreBridge: LutShopCoreBridge {
    func loadInitialPhotos() -> [Photo] {
        []
    }

    func loadLuts() -> [LutPreset] {
        let bundled = Self.loadBundledLuts()
        if !bundled.isEmpty {
            return bundled
        }

        return [
            LutPreset(id: "l1", name: "Clean Portrait", category: .portrait, tags: ["skin", "soft", "studio"], previewColors: [.brown, .orange, .white], isFavorite: true, usageCount: 68, confidence: 94),
            LutPreset(id: "l2", name: "Alpine Teal", category: .landscape, tags: ["mountain", "cool", "travel"], previewColors: [.blue, .cyan, .green], isFavorite: false, usageCount: 41, confidence: 88),
            LutPreset(id: "l3", name: "Gold Hour Film", category: .film, tags: ["warm", "sunset", "grain"], previewColors: [.orange, .yellow, .brown], isFavorite: true, usageCount: 92, confidence: 91),
            LutPreset(id: "l4", name: "Mono Contrast", category: .blackWhite, tags: ["street", "mono", "contrast"], previewColors: [.black, .gray, .white], isFavorite: false, usageCount: 23, confidence: nil),
            LutPreset(id: "l5", name: "Commercial Deep", category: .commercial, tags: ["product", "car", "deep"], previewColors: [.black, .gray, .orange], isFavorite: false, usageCount: 36, confidence: nil)
        ]
    }

    func recommendLuts(for photo: Photo, from luts: [LutPreset]) -> [LutPreset] {
        let ids = Set(photo.recommendedLutIds)
        return luts
            .filter { ids.contains($0.id) }
            .sorted { ($0.confidence ?? 0) > ($1.confidence ?? 0) }
    }

    func apply(lut: LutPreset, intensity: Double, to photos: [Photo]) -> [Photo] {
        photos.map { photo in
            var edited = photo
            edited.appliedLutId = lut.id
            edited.lutIntensity = min(max(intensity, 0), 1)
            edited.status = .edited
            return edited
        }
    }

    func rate(_ photos: [Photo], rating: Int) -> [Photo] {
        let clampedRating = min(max(rating, 0), 5)
        return photos.map { photo in
            var rated = photo
            rated.rating = clampedRating
            return rated
        }
    }

    func markExported(_ photos: [Photo]) -> [Photo] {
        photos.map { photo in
            var exported = photo
            exported.status = .exported
            return exported
        }
    }

    func toggleFavorite(lut: LutPreset) -> LutPreset {
        var updated = lut
        updated.isFavorite.toggle()
        return updated
    }

    func rename(lut: LutPreset, to name: String) -> LutPreset {
        var updated = lut
        updated.name = name
        return updated
    }

    func makeImportedLut(existingCount: Int) -> LutPreset {
        let count = existingCount + 1
        return LutPreset(
            id: "custom-\(count)",
            name: "Imported LUT \(count)",
            category: .custom,
            tags: ["imported", "cube"],
            previewColors: [.accentGreen, .cyan, .white],
            isFavorite: false,
            usageCount: 0,
            confidence: nil
        )
    }

    func loadSummary(for lut: LutPreset) -> String? {
        guard let sourceFileName = lut.sourceFileName else { return nil }
        return LutShopCppBridge.loadSummary(forBundledLutNamed: sourceFileName)
    }

    func previewPixelSummary(for lut: LutPreset) -> String? {
        guard let sourceFileName = lut.sourceFileName else { return nil }
        return LutShopCppBridge.previewPixelSummary(forBundledLutNamed: sourceFileName)
    }

    private static func loadBundledLuts() -> [LutPreset] {
        LutShopCppBridge.bundledLutMetadata().compactMap { item in
            guard
                let id = item["id"] as? String,
                let name = item["name"] as? String,
                let fileName = item["fileName"] as? String
            else {
                return nil
            }

            let category = category(from: item["category"] as? String)
            return LutPreset(
                id: id,
                name: name,
                category: category,
                tags: ["sony", "cube", fileName],
                previewColors: previewColors(for: category),
                isFavorite: false,
                usageCount: 0,
                confidence: nil,
                sourceFileName: fileName,
                cubeSize: (item["cubeSize"] as? NSNumber)?.intValue,
                cubeEntryCount: (item["entryCount"] as? NSNumber)?.intValue,
                provider: item["provider"] as? String,
                isBundled: true
            )
        }
    }

    private static func category(from rawValue: String?) -> LutCategory {
        LutCategory.allCases.first { $0.rawValue == rawValue } ?? .custom
    }

    private static func previewColors(for category: LutCategory) -> [Color] {
        switch category {
        case .portrait:
            return [.brown, .orange, .white]
        case .landscape:
            return [.blue, .cyan, .green]
        case .film:
            return [.black, .orange, .cyan]
        case .blackWhite:
            return [.black, .gray, .white]
        case .commercial:
            return [.black, .gray, .orange]
        case .custom:
            return [.accentGreen, .cyan, .white]
        }
    }
}
