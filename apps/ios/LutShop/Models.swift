import Foundation
import SwiftUI

enum PhotoStatus: String, CaseIterable, Identifiable {
    case raw = "RAW"
    case edited = "Edited"
    case exported = "Exported"

    var id: String { rawValue }
    var titleKey: LocalizedStringKey { LocalizedStringKey(rawValue) }
}

enum MainTab: String, CaseIterable, Identifiable {
    case gallery = "Gallery"
    case preview = "Preview"
    case luts = "LUTs"
    case export = "Export"

    var id: String { rawValue }
    var title: String { String(localized: String.LocalizationValue(rawValue)) }
    var titleKey: LocalizedStringKey { LocalizedStringKey(rawValue) }

    var icon: String {
        switch self {
        case .gallery: return "photo.on.rectangle.angled"
        case .preview: return "square.dashed"
        case .luts: return "square.stack.3d.up"
        case .export: return "square.and.arrow.up"
        }
    }
}

enum PhotoSortOption: String, CaseIterable, Identifiable {
    case fileName = "File name"
    case newest = "Newest"
    case rating = "Rating"
    case status = "Status"

    var id: String { rawValue }
    var title: String { String(localized: String.LocalizationValue(rawValue)) }
}

enum LutCategory: String, CaseIterable, Identifiable {
    case portrait = "Portrait"
    case landscape = "Landscape"
    case film = "Film"
    case blackWhite = "B&W"
    case commercial = "Commercial"
    case custom = "Custom"

    var id: String { rawValue }
    var title: String { String(localized: String.LocalizationValue(rawValue)) }
}

struct Photo: Identifiable, Equatable {
    let id: String
    var fileName: String
    var imageName: String
    var sessionName: String
    var status: PhotoStatus
    var isFavorite: Bool
    var isSelected: Bool
    var rating: Int
    var appliedLutId: String?
    var lutIntensity: Double
    var recommendedLutIds: [String]
    var palette: [Color]
}

struct LutPreset: Identifiable, Equatable {
    let id: String
    var name: String
    var category: LutCategory
    var tags: [String]
    var previewColors: [Color]
    var isFavorite: Bool
    var usageCount: Int
    var confidence: Int?
}

struct ExportSettings: Equatable {
    var format: String = "JPG"
    var size: String = "2048px"
    var quality: String = "High"
    var preserveExif: Bool = true
}
