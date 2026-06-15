import Compression
import Foundation

struct ImportedCubeFile {
    var fileName: String
    var data: Data
}

enum LutArchiveImportError: LocalizedError {
    case unsupportedFileType(String)
    case invalidCube(String)
    case invalidZip(String)
    case archiveTooDeep
    case entryTooLarge(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let ext):
            return String(localized: "Unsupported LUT file type: \(ext)")
        case .invalidCube(let name):
            return String(localized: "No valid CUBE data found in \(name)")
        case .invalidZip(let name):
            return String(localized: "Could not read ZIP archive: \(name)")
        case .archiveTooDeep:
            return String(localized: "Archive nesting is too deep")
        case .entryTooLarge(let name):
            return String(localized: "Archive entry is too large: \(name)")
        }
    }
}

enum ZipLutArchiveExtractor {
    private struct ZipEntry {
        var name: String
        var compressionMethod: UInt16
        var compressedSize: Int
        var uncompressedSize: Int
        var localHeaderOffset: Int
    }

    private static let maxArchiveDepth = 6
    private static let maxEntrySize = 64 * 1024 * 1024

    static func extractCubeFiles(from url: URL) throws -> [ImportedCubeFile] {
        let ext = url.pathExtension.lowercased()
        let data = try Data(contentsOf: url)
        switch ext {
        case "cube":
            guard isCubeData(data) else {
                throw LutArchiveImportError.invalidCube(url.lastPathComponent)
            }
            return [ImportedCubeFile(fileName: url.lastPathComponent, data: data)]
        case "zip":
            return try extractCubeFiles(fromZipData: data, archiveName: url.lastPathComponent, depth: 0)
        case "rar", "7z":
            throw LutArchiveImportError.unsupportedFileType(".\(ext)")
        default:
            throw LutArchiveImportError.unsupportedFileType(".\(ext.isEmpty ? url.lastPathComponent : ext)")
        }
    }

    private static func extractCubeFiles(fromZipData data: Data, archiveName: String, depth: Int) throws -> [ImportedCubeFile] {
        guard depth <= maxArchiveDepth else {
            throw LutArchiveImportError.archiveTooDeep
        }

        let entries = try centralDirectoryEntries(in: data, archiveName: archiveName)
        var cubes: [ImportedCubeFile] = []

        for entry in entries where !entry.name.hasSuffix("/") {
            let ext = URL(fileURLWithPath: entry.name).pathExtension.lowercased()
            guard ext == "cube" || ext == "zip" else { continue }

            let entryData = try inflatedData(for: entry, in: data, archiveName: archiveName)
            if ext == "cube" {
                guard isCubeData(entryData) else { continue }
                cubes.append(ImportedCubeFile(fileName: URL(fileURLWithPath: entry.name).lastPathComponent, data: entryData))
            } else {
                do {
                    let nested = try extractCubeFiles(fromZipData: entryData, archiveName: entry.name, depth: depth + 1)
                    cubes.append(contentsOf: nested)
                } catch LutArchiveImportError.invalidZip {
                    continue
                } catch LutArchiveImportError.unsupportedFileType {
                    continue
                }
            }
        }

        guard !cubes.isEmpty else {
            throw LutArchiveImportError.invalidZip(archiveName)
        }
        return cubes
    }

    private static func centralDirectoryEntries(in data: Data, archiveName: String) throws -> [ZipEntry] {
        guard let eocdOffset = endOfCentralDirectoryOffset(in: data) else {
            throw LutArchiveImportError.invalidZip(archiveName)
        }

        let entryCount = Int(readUInt16(data, at: eocdOffset + 10))
        let centralDirectoryOffset = Int(readUInt32(data, at: eocdOffset + 16))
        var offset = centralDirectoryOffset
        var entries: [ZipEntry] = []

        for _ in 0..<entryCount {
            guard offset + 46 <= data.count, readUInt32(data, at: offset) == 0x02014b50 else {
                throw LutArchiveImportError.invalidZip(archiveName)
            }

            let compressionMethod = readUInt16(data, at: offset + 10)
            let compressedSize = Int(readUInt32(data, at: offset + 20))
            let uncompressedSize = Int(readUInt32(data, at: offset + 24))
            let fileNameLength = Int(readUInt16(data, at: offset + 28))
            let extraLength = Int(readUInt16(data, at: offset + 30))
            let commentLength = Int(readUInt16(data, at: offset + 32))
            let localHeaderOffset = Int(readUInt32(data, at: offset + 42))
            let nameStart = offset + 46
            let nameEnd = nameStart + fileNameLength

            guard nameEnd <= data.count else {
                throw LutArchiveImportError.invalidZip(archiveName)
            }
            guard uncompressedSize <= maxEntrySize else {
                let rawName = String(data: data[nameStart..<nameEnd], encoding: .utf8) ?? archiveName
                throw LutArchiveImportError.entryTooLarge(rawName)
            }

            let name = String(data: data[nameStart..<nameEnd], encoding: .utf8) ?? ""
            entries.append(
                ZipEntry(
                    name: name,
                    compressionMethod: compressionMethod,
                    compressedSize: compressedSize,
                    uncompressedSize: uncompressedSize,
                    localHeaderOffset: localHeaderOffset
                )
            )
            offset = nameEnd + extraLength + commentLength
        }

        return entries
    }

    private static func inflatedData(for entry: ZipEntry, in archiveData: Data, archiveName: String) throws -> Data {
        let localOffset = entry.localHeaderOffset
        guard localOffset + 30 <= archiveData.count, readUInt32(archiveData, at: localOffset) == 0x04034b50 else {
            throw LutArchiveImportError.invalidZip(archiveName)
        }

        let localNameLength = Int(readUInt16(archiveData, at: localOffset + 26))
        let localExtraLength = Int(readUInt16(archiveData, at: localOffset + 28))
        let dataStart = localOffset + 30 + localNameLength + localExtraLength
        let dataEnd = dataStart + entry.compressedSize
        guard dataStart >= 0, dataEnd <= archiveData.count else {
            throw LutArchiveImportError.invalidZip(archiveName)
        }

        let compressed = archiveData[dataStart..<dataEnd]
        switch entry.compressionMethod {
        case 0:
            return Data(compressed)
        case 8:
            return try inflateDeflateData(Data(compressed), expectedSize: entry.uncompressedSize, entryName: entry.name)
        default:
            throw LutArchiveImportError.invalidZip(entry.name)
        }
    }

    private static func inflateDeflateData(_ data: Data, expectedSize: Int, entryName: String) throws -> Data {
        var output = Data(count: expectedSize)
        let decodedSize = output.withUnsafeMutableBytes { destination in
            data.withUnsafeBytes { source in
                compression_decode_buffer(
                    destination.bindMemory(to: UInt8.self).baseAddress!,
                    expectedSize,
                    source.bindMemory(to: UInt8.self).baseAddress!,
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard decodedSize > 0 else {
            throw LutArchiveImportError.invalidZip(entryName)
        }
        output.count = decodedSize
        return output
    }

    private static func endOfCentralDirectoryOffset(in data: Data) -> Int? {
        guard data.count >= 22 else { return nil }
        let lowerBound = max(0, data.count - 22 - 65_535)
        var offset = data.count - 22
        while offset >= lowerBound {
            if readUInt32(data, at: offset) == 0x06054b50 {
                return offset
            }
            offset -= 1
        }
        return nil
    }

    private static func isCubeData(_ data: Data) -> Bool {
        guard let text = String(data: data.prefix(128 * 1024), encoding: .utf8) else {
            return false
        }
        return text.contains("LUT_3D_SIZE") || text.contains("LUT_1D_SIZE")
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }
}
