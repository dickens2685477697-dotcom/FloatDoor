import Foundation
import UniformTypeIdentifiers

enum PortalStorageError: LocalizedError {
    case sourceFileUnavailable
    case unreadableData

    var errorDescription: String? {
        switch self {
        case .sourceFileUnavailable:
            return "无法访问拖入的文件。"
        case .unreadableData:
            return "无法读取拖入的数据。"
        }
    }
}

/// Owns the on-disk layout. Metadata only keeps relative names so a moved
/// Application Support directory remains readable after relaunch.
struct PortalFileStore: PortalRepository {
    let rootURL: URL

    init(rootURL: URL) {
        self.rootURL = rootURL
    }

    var temporaryDirectory: URL {
        rootURL.appending(path: "Temporary", directoryHint: .isDirectory)
    }

    var permanentDirectory: URL {
        rootURL.appending(path: "Permanent", directoryHint: .isDirectory)
    }

    /// Content for the user-defined area is kept outside the permanent
    /// material directory so the two collections can evolve independently.
    var customDirectory: URL {
        rootURL.appending(path: "Custom", directoryHint: .isDirectory)
    }

    var thumbnailsDirectory: URL {
        rootURL.appending(path: "Thumbnails", directoryHint: .isDirectory)
    }

    var databaseDirectory: URL {
        rootURL.appending(path: "Database", directoryHint: .isDirectory)
    }

    var databaseURL: URL {
        databaseDirectory.appending(path: "portal-items.json", directoryHint: .notDirectory)
    }

    func directory(for scope: StorageScope) -> URL {
        switch scope {
        case .temporary:
            return temporaryDirectory
        case .permanent:
            return permanentDirectory
        case .custom:
            return customDirectory
        }
    }

    func prepareDirectories() throws {
        let fileManager = FileManager.default
        for directory in [rootURL, temporaryDirectory, permanentDirectory, customDirectory, thumbnailsDirectory, databaseDirectory] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    func load() throws -> [PortalItem] {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([PortalItem].self, from: Data(contentsOf: databaseURL))
    }

    func save(_ items: [PortalItem]) throws {
        try prepareDirectories()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(items).write(to: databaseURL, options: .atomic)
    }

    func cachedURL(for item: PortalItem) -> URL? {
        guard let cachedFilename = item.cachedFilename else { return nil }
        return directory(for: item.scope).appending(path: cachedFilename, directoryHint: .notDirectory)
    }

    func copyFile(at sourceURL: URL, id: UUID, scope: StorageScope) throws -> StoredFile {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw PortalStorageError.sourceFileUnavailable
        }

        let accessedSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let filename = storageFilename(id: id, originalName: sourceURL.lastPathComponent)
        let destination = directory(for: scope).appending(path: filename, directoryHint: .notDirectory)
        try prepareDirectories()
        try FileManager.default.copyItem(at: sourceURL, to: destination)

        let attributes = try? FileManager.default.attributesOfItem(atPath: destination.path)
        let fileSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        return StoredFile(
            filename: filename,
            fileSize: fileSize,
            contentTypeIdentifier: contentTypeIdentifier(for: sourceURL)
        )
    }

    func saveData(
        _ data: Data,
        originalName: String,
        contentTypeIdentifier: String?,
        id: UUID,
        scope: StorageScope
    ) throws -> StoredFile {
        guard !data.isEmpty else {
            throw PortalStorageError.unreadableData
        }

        let filename = storageFilename(id: id, originalName: originalName)
        let destination = directory(for: scope).appending(path: filename, directoryHint: .notDirectory)
        try prepareDirectories()
        try data.write(to: destination, options: .atomic)

        return StoredFile(
            filename: filename,
            fileSize: Int64(data.count),
            contentTypeIdentifier: contentTypeIdentifier
        )
    }

    func moveCachedFile(for item: PortalItem, to scope: StorageScope) throws {
        guard let source = cachedURL(for: item) else { return }
        let destination = directory(for: scope).appending(path: source.lastPathComponent, directoryHint: .notDirectory)
        guard source != destination, FileManager.default.fileExists(atPath: source.path) else { return }
        try prepareDirectories()
        try FileManager.default.moveItem(at: source, to: destination)
    }

    func deleteCachedFile(for item: PortalItem) {
        guard let cachedURL = cachedURL(for: item) else { return }
        try? FileManager.default.removeItem(at: cachedURL)
    }

    func storageUsage() -> Int64 {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey]
        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )

        guard let enumerator else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard
                let values = try? fileURL.resourceValues(forKeys: keys),
                values.isRegularFile == true
            else {
                continue
            }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    private func storageFilename(id: UUID, originalName: String) -> String {
        let extensionPart = URL(fileURLWithPath: originalName).pathExtension
        guard !extensionPart.isEmpty else { return id.uuidString.lowercased() }
        return "\(id.uuidString.lowercased()).\(extensionPart)"
    }

    private func contentTypeIdentifier(for url: URL) -> String? {
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            return UTType.folder.identifier
        }
        if let type = UTType(filenameExtension: url.pathExtension) {
            return type.identifier
        }
        return nil
    }
}
