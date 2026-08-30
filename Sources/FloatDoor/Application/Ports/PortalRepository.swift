import Foundation

/// Persistence boundary used by the application layer.
///
/// Keeping this protocol free of AppKit and SwiftUI makes PortalStore usable
/// with an in-memory repository in tests and with a different persistence
/// implementation in future features.
protocol PortalRepository {
    var rootURL: URL { get }

    func prepareDirectories() throws
    func load() throws -> [PortalItem]
    func save(_ items: [PortalItem]) throws

    func cachedURL(for item: PortalItem) -> URL?
    func copyFile(at sourceURL: URL, id: UUID, scope: StorageScope) throws -> StoredFile
    func saveData(
        _ data: Data,
        originalName: String,
        contentTypeIdentifier: String?,
        id: UUID,
        scope: StorageScope
    ) throws -> StoredFile
    func moveCachedFile(for item: PortalItem, to scope: StorageScope) throws
    func deleteCachedFile(for item: PortalItem)
    func storageUsage() -> Int64
}
