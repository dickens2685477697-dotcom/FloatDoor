import XCTest
@testable import FloatDoor

final class PortalItemTimeLabelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testCreatedTimeUsesCompletedUnitsAndHandlesClockSkew() {
        XCTAssertEqual(PortalItemTimeLabel.created(at: now.addingTimeInterval(60), now: now), "刚刚保存")
        XCTAssertEqual(PortalItemTimeLabel.created(at: now.addingTimeInterval(-3599), now: now), "59 分钟前")
        XCTAssertEqual(PortalItemTimeLabel.created(at: now.addingTimeInterval(-3600), now: now), "1 小时前")
        XCTAssertEqual(PortalItemTimeLabel.created(at: now.addingTimeInterval(-86400), now: now), "1 天前")
    }

    func testRemainingTimeDoesNotClaimPrematureExpiry() {
        XCTAssertEqual(PortalItemTimeLabel.remaining(until: now, now: now), "已到期")
        XCTAssertEqual(PortalItemTimeLabel.remaining(until: now.addingTimeInterval(-1), now: now), "已到期")
        XCTAssertEqual(PortalItemTimeLabel.remaining(until: now.addingTimeInterval(59), now: now), "不足 1 分钟后清理")
        XCTAssertEqual(PortalItemTimeLabel.remaining(until: now.addingTimeInterval(61), now: now), "剩余 2 分钟")
        XCTAssertEqual(PortalItemTimeLabel.remaining(until: now.addingTimeInterval(86400), now: now), "剩余 1 天")
    }
}
