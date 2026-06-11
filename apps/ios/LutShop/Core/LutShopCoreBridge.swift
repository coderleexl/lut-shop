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
}

final class MockLutShopCoreBridge: LutShopCoreBridge {
    func loadInitialPhotos() -> [Photo] {
        [
            Photo(id: "p1", fileName: "IMG_0123.CR3", imageName: "photo-portrait", sessionName: "2026-06-08 Studio Shoot", status: .raw, isFavorite: false, isSelected: false, rating: 3, appliedLutId: nil, lutIntensity: 0.72, recommendedLutIds: ["l1", "l3"], palette: [Color(red: 0.43, green: 0.50, blue: 0.24), .green, .black]),
            Photo(id: "p2", fileName: "IMG_0124.CR3", imageName: "photo-mountain", sessionName: "2026-06-08 Studio Shoot", status: .raw, isFavorite: true, isSelected: false, rating: 0, appliedLutId: nil, lutIntensity: 0.55, recommendedLutIds: ["l2"], palette: [.blue, .cyan, .black]),
            Photo(id: "p3", fileName: "IMG_0125.CR3", imageName: "photo-beach", sessionName: "2026-06-08 Studio Shoot", status: .raw, isFavorite: false, isSelected: false, rating: 5, appliedLutId: nil, lutIntensity: 0.64, recommendedLutIds: ["l3"], palette: [.orange, .brown, .black]),
            Photo(id: "p4", fileName: "IMG_0126.CR3", imageName: "photo-car", sessionName: "2026-06-08 Studio Shoot", status: .raw, isFavorite: true, isSelected: false, rating: 0, appliedLutId: nil, lutIntensity: 0.42, recommendedLutIds: ["l4"], palette: [.gray, .black, .brown]),
            Photo(id: "p5", fileName: "IMG_0127.CR3", imageName: "photo-man", sessionName: "2026-06-08 Studio Shoot", status: .raw, isFavorite: true, isSelected: false, rating: 4, appliedLutId: nil, lutIntensity: 0.51, recommendedLutIds: ["l1"], palette: [.gray, .black, .white]),
            Photo(id: "p6", fileName: "IMG_0128.CR3", imageName: "photo-street", sessionName: "2026-06-08 Studio Shoot", status: .edited, isFavorite: false, isSelected: false, rating: 0, appliedLutId: "l2", lutIntensity: 0.68, recommendedLutIds: ["l2"], palette: [.brown, .orange, .black]),
            Photo(id: "p7", fileName: "IMG_0129.CR3", imageName: "photo-blackcar", sessionName: "2026-06-08 Studio Shoot", status: .raw, isFavorite: true, isSelected: false, rating: 0, appliedLutId: nil, lutIntensity: 0.38, recommendedLutIds: ["l5"], palette: [.black, .gray, .brown]),
            Photo(id: "p8", fileName: "IMG_0130.CR3", imageName: "photo-chair", sessionName: "2026-06-08 Studio Shoot", status: .raw, isFavorite: false, isSelected: false, rating: 5, appliedLutId: nil, lutIntensity: 0.57, recommendedLutIds: ["l3"], palette: [.brown, .yellow, .black]),
            Photo(id: "p9", fileName: "IMG_0131.CR3", imageName: "photo-forest", sessionName: "2026-06-08 Studio Shoot", status: .exported, isFavorite: false, isSelected: false, rating: 0, appliedLutId: "l2", lutIntensity: 0.76, recommendedLutIds: ["l2"], palette: [.yellow, .green, .gray]),
            Photo(id: "p10", fileName: "IMG_0132.CR3", imageName: "photo-coast", sessionName: "2026-06-08 Studio Shoot", status: .raw, isFavorite: true, isSelected: false, rating: 0, appliedLutId: nil, lutIntensity: 0.43, recommendedLutIds: ["l4"], palette: [.blue, .gray, .black]),
            Photo(id: "p11", fileName: "IMG_0133.CR3", imageName: "photo-girl", sessionName: "2026-06-08 Studio Shoot", status: .raw, isFavorite: true, isSelected: false, rating: 0, appliedLutId: nil, lutIntensity: 0.61, recommendedLutIds: ["l1"], palette: [.brown, .orange, .black]),
            Photo(id: "p12", fileName: "IMG_0134.CR3", imageName: "photo-desert", sessionName: "2026-06-08 Studio Shoot", status: .raw, isFavorite: false, isSelected: false, rating: 0, appliedLutId: nil, lutIntensity: 0.49, recommendedLutIds: ["l2"], palette: [.orange, .yellow, .brown])
        ]
    }

    func loadLuts() -> [LutPreset] {
        [
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
}
