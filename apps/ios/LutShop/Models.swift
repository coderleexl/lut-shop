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
    case watermark = "Watermark"
    case export = "Export"

    var id: String { rawValue }
    var title: String { String(localized: String.LocalizationValue(rawValue)) }
    var titleKey: LocalizedStringKey { LocalizedStringKey(rawValue) }

    var icon: String {
        switch self {
        case .gallery: return "photo.on.rectangle.angled"
        case .preview: return "square.dashed"
        case .luts: return "square.stack.3d.up"
        case .watermark: return "drop.fill"
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

enum LutCategory: String, CaseIterable, Identifiable, Codable {
    case portrait = "Portrait"
    case landscape = "Landscape"
    case film = "Film"
    case blackWhite = "B&W"
    case commercial = "Commercial"
    case custom = "Custom"

    var id: String { rawValue }
    var title: String { String(localized: String.LocalizationValue(rawValue)) }
}

struct LutCategoryGroup: Identifiable, Equatable, Codable {
    var id: String
    var title: String
    var category: LutCategory
    var isSystem: Bool
}

enum ImportSource: String, CaseIterable, Identifiable {
    case photoLibrary = "Photo Library"
    case filePicker = "Files"
    case ftpCamera = "FTP Camera"

    var id: String { rawValue }
    var title: String { String(localized: String.LocalizationValue(rawValue)) }
}

enum CameraConnectionStatus: String {
    case idle = "Ready"
    case waiting = "Waiting"
    case receiving = "Receiving"
    case stopped = "Stopped"

    var title: String { String(localized: String.LocalizationValue(rawValue)) }
}

enum CameraImportFormat: String, CaseIterable, Identifiable {
    case jpg = "JPG"
    case raw = "RAW"
    case rawJpg = "RAW + JPG"

    var id: String { rawValue }
    var title: String { rawValue }
}

struct CameraDevice: Identifiable, Equatable {
    let id: String
    var name: String
    var model: String
    var source: ImportSource
    var hostHint: String
    var port: Int
    var username: String
    var isDiscovered: Bool = false
}

struct CameraImportSettings: Equatable {
    var format: CameraImportFormat = .rawJpg
    var autoCreateSession = true
    var groupRawJpgPairs = true
    var skipDuplicateFiles = true
}

struct FtpReceiverConfiguration: Equatable {
    var port: Int = 2121
    var username: String = "lee"
    var password: String = "123456"
}

struct CameraSession: Identifiable, Equatable {
    let id: String
    var name: String
    var source: ImportSource
    var deviceName: String
    var startedAt: Date
    var status: CameraConnectionStatus
    var receivedCount: Int
    var currentFileName: String?
    var lastFileName: String?
}

struct Photo: Identifiable, Equatable {
    let id: String
    var fileName: String
    var imageName: String
    var imagePath: String? = nil
    var sessionName: String
    var status: PhotoStatus
    var isFavorite: Bool
    var isSelected: Bool
    var rating: Int
    var appliedLutId: String?
    var lutIntensity: Double
    var recommendedLutIds: [String]
    var palette: [Color]
    var exifSummary: PhotoExifSummary? = nil

    var formatBadgeText: String {
        let rawExtensions = Set(["raw", "dng", "arw", "cr2", "cr3", "nef", "nrw", "orf", "pef", "raf", "rw2", "srw"])
        let jpegExtensions = Set(["jpg", "jpeg"])

        let candidates = [fileName, imagePath ?? ""]
        for candidate in candidates where !candidate.isEmpty {
            let ext = (candidate as NSString).pathExtension.lowercased()
            guard !ext.isEmpty else { continue }
            if rawExtensions.contains(ext) {
                return "RAW"
            }
            if jpegExtensions.contains(ext) {
                return "JPG"
            }
            return ext.uppercased()
        }

        return status.rawValue
    }
}

struct PhotoExifSummary: Codable, Equatable {
    var cameraMake: String?
    var cameraModel: String?
    var lensModel: String?
    var focalLength: String?
    var aperture: String?
    var shutterSpeed: String?
    var iso: String?
    var capturedAt: String?

    var cameraDisplayName: String? {
        [cameraMake, cameraModel]
            .compactMap { value in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed?.isEmpty == false ? trimmed : nil
            }
            .removingDuplicates()
            .joined(separator: " ")
            .nilIfEmpty
    }

    var exposureDisplayText: String? {
        [focalLength, aperture, shutterSpeed, iso]
            .compactMap { value in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed?.isEmpty == false ? trimmed : nil
            }
            .joined(separator: "  ")
            .nilIfEmpty
    }
}

enum WatermarkStyle: String, CaseIterable, Identifiable, Codable {
    case none
    case filmBorder
    case hasselbladMinimal
    case leicaMinimal
    case appleMinimal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return String(localized: "No Watermark")
        case .filmBorder:
            return String(localized: "Film Border")
        case .hasselbladMinimal:
            return String(localized: "Hasselblad Minimal")
        case .leicaMinimal:
            return String(localized: "Leica Minimal")
        case .appleMinimal:
            return String(localized: "Apple Minimal")
        }
    }
}

struct WatermarkSettings: Codable, Equatable {
    var style: WatermarkStyle = .none
    var cornerRadius: Double = 0.22
    var showExif: Bool = true

    var isEnabled: Bool {
        style != .none
    }
}

struct LutPreset: Identifiable, Equatable {
    let id: String
    var name: String
    var category: LutCategory
    var categoryGroupId: String? = nil
    var tags: [String]
    var previewColors: [Color]
    var isFavorite: Bool
    var usageCount: Int
    var confidence: Int?
    var sourceFileName: String? = nil
    var cubeSize: Int? = nil
    var cubeEntryCount: Int? = nil
    var provider: String? = nil
    var isBundled: Bool = false
    var userPath: String? = nil

    var hasRenderableSource: Bool {
        sourceFileName?.isEmpty == false || userPath?.isEmpty == false
    }
}

struct ExportSettings: Equatable {
    var format: String = "JPG"
    var size: String = "2048px"
    var quality: String = "High"
    var preserveExif: Bool = true
}

private extension Array where Element == String {
    func removingDuplicates() -> [String] {
        var result: [String] = []
        for item in self where !result.contains(item) {
            result.append(item)
        }
        return result
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
