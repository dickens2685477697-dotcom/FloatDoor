import Foundation
import XCTest
@testable import FloatDoor

final class SingleInstanceCoordinatorTests: XCTestCase {
    func testOnlyOneLockOwnerCanExistAtATime() throws {
        let lockURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FloatDoorTests-\(UUID().uuidString).lock")
        defer { try? FileManager.default.removeItem(at: lockURL) }

        var firstOwner: SingleInstanceLock? = SingleInstanceLock(fileURL: lockURL)
        XCTAssertNotNil(firstOwner)
        XCTAssertNil(SingleInstanceLock(fileURL: lockURL))

        firstOwner = nil
        XCTAssertNotNil(SingleInstanceLock(fileURL: lockURL))
    }
}
