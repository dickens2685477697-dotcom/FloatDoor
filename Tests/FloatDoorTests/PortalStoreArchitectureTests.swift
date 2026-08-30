import Foundation
import XCTest
@testable import FloatDoor

@MainActor
final class PortalStoreArchitectureTests: XCTestCase {
    func testStorePersistsThroughInjectedRepository() throws {
        let repository = InMemoryPortalRepository()
        let suiteName = "FloatDoorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PortalStore(repository: repository, defaults: defaults)
        store.importText("可替换存储实现", into: .permanent)

        XCTAssertEqual(repository.savedItems.count, 1)
        XCTAssertEqual(repository.savedItems.first?.textContent, "可替换存储实现")
        XCTAssertEqual(store.permanentItems, repository.savedItems)
    }
}

private final class InMemoryPortalRepository: PortalRepository {
    let rootURL = URL(fileURLWithPath: "/in-memory")
    var savedItems: [PortalItem] = []

    func prepareDirectories() throws {}
    func load() throws -> [PortalItem] { savedItems }
    func save(_ items: [PortalItem]) throws { savedItems = items }
    func cachedURL(for item: PortalItem) -> URL? { nil }

    func copyFile(at sourceURL: URL, id: UUID, scope: StorageScope) throws -> StoredFile {
        throw InMemoryRepositoryError.fileOperationsUnsupported
    }

    func saveData(
        _ data: Data,
        originalName: String,
        contentTypeIdentifier: String?,
        id: UUID,
        scope: StorageScope
    ) throws -> StoredFile {
        throw InMemoryRepositoryError.fileOperationsUnsupported
    }

    func moveCachedFile(for item: PortalItem, to scope: StorageScope) throws {}
    func deleteCachedFile(for item: PortalItem) {}
    func storageUsage() -> Int64 { 0 }
}

private enum InMemoryRepositoryError: Error {
    case fileOperationsUnsupported
}
