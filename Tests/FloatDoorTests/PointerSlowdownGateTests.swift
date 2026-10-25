import Foundation
import XCTest
@testable import FloatDoor

final class PointerSlowdownGateTests: XCTestCase {
    private let region = CGRect(x: 900, y: 1_000, width: 300, height: 60)
    private let restingPoint = CGPoint(x: 1_000, y: 1_020)

    func testEntryAloneDoesNotActivateButStoppingDoes() {
        var gate = PointerSlowdownGate()

        for timestamp in [0.0, 0.04, 0.08, 0.12] {
            XCTAssertFalse(gate.sample(at: restingPoint, timestamp: timestamp, in: region))
        }
        XCTAssertTrue(gate.sample(at: restingPoint, timestamp: 0.16, in: region))
    }

    func testSlowMovementCanActivateWithoutACompleteStop() {
        var gate = PointerSlowdownGate()

        // An 80 pt/s approach should work without requiring a perfectly still hand.
        for index in 0..<4 {
            let point = CGPoint(x: 1_000 + Double(index) * 3.2, y: 1_020)
            XCTAssertFalse(gate.sample(at: point, timestamp: Double(index) * 0.04, in: region))
        }
        XCTAssertTrue(gate.sample(at: CGPoint(x: 1_012.8, y: 1_020), timestamp: 0.16, in: region))
    }

    func testFastPassThroughDoesNotActivate() {
        var gate = PointerSlowdownGate()

        // The pointer crosses the whole trigger region at 1,000 pt/s.
        for index in 0...16 {
            let point = CGPoint(x: 890 + Double(index) * 20, y: 1_020)
            XCTAssertFalse(gate.sample(at: point, timestamp: Double(index) * 0.02, in: region))
        }
    }

    func testRemainingInRegionWhileMovingQuicklyDoesNotBecomeADwellTrigger() {
        var gate = PointerSlowdownGate()

        for index in 0...12 {
            let point = CGPoint(x: index.isMultiple(of: 2) ? 1_000 : 1_012, y: 1_020)
            XCTAssertFalse(gate.sample(at: point, timestamp: Double(index) * 0.04, in: region))
        }
    }

    func testFastApproachThenSlowdownActivatesAfterSlowInterval() {
        var gate = PointerSlowdownGate()

        XCTAssertFalse(gate.sample(at: CGPoint(x: 940, y: 1_020), timestamp: 0, in: region))
        XCTAssertFalse(gate.sample(at: CGPoint(x: 980, y: 1_020), timestamp: 0.04, in: region))
        for index in 1...3 {
            let point = CGPoint(x: 980 + Double(index) * 2, y: 1_020)
            XCTAssertFalse(gate.sample(at: point, timestamp: 0.04 + Double(index) * 0.04, in: region))
        }
        XCTAssertTrue(gate.sample(at: CGPoint(x: 988, y: 1_020), timestamp: 0.20, in: region))
    }

    func testSpeedingUpRequiresANewSlowInterval() {
        var gate = PointerSlowdownGate()

        for timestamp in [0.0, 0.04, 0.08, 0.12] {
            XCTAssertFalse(gate.sample(at: restingPoint, timestamp: timestamp, in: region))
        }
        let newPoint = CGPoint(x: 1_030, y: 1_020)
        XCTAssertFalse(gate.sample(at: newPoint, timestamp: 0.16, in: region))
        for timestamp in [0.20, 0.24, 0.28] {
            XCTAssertFalse(gate.sample(at: newPoint, timestamp: timestamp, in: region))
        }
        XCTAssertTrue(gate.sample(at: newPoint, timestamp: 0.32, in: region))
    }

    func testLeavingAndReenteringDoesNotReusePreviousSlowTime() {
        var gate = PointerSlowdownGate()

        for timestamp in [0.0, 0.04, 0.08, 0.12] {
            XCTAssertFalse(gate.sample(at: restingPoint, timestamp: timestamp, in: region))
        }
        XCTAssertFalse(gate.sample(at: CGPoint(x: 1_000, y: 990), timestamp: 0.14, in: region))
        for timestamp in [0.16, 0.20, 0.24, 0.28] {
            XCTAssertFalse(gate.sample(at: restingPoint, timestamp: timestamp, in: region))
        }
        XCTAssertTrue(gate.sample(at: restingPoint, timestamp: 0.32, in: region))
    }

    func testExplicitResetRequiresANewSlowInterval() {
        var gate = PointerSlowdownGate()

        for timestamp in [0.0, 0.04, 0.08, 0.12] {
            XCTAssertFalse(gate.sample(at: restingPoint, timestamp: timestamp, in: region))
        }
        gate.reset()
        for timestamp in [0.16, 0.20, 0.24, 0.28] {
            XCTAssertFalse(gate.sample(at: restingPoint, timestamp: timestamp, in: region))
        }
        XCTAssertTrue(gate.sample(at: restingPoint, timestamp: 0.32, in: region))
    }

    func testChangingScreenGeometryRequiresANewSlowInterval() {
        var gate = PointerSlowdownGate()

        for timestamp in [0.0, 0.04, 0.08, 0.12] {
            XCTAssertFalse(gate.sample(at: restingPoint, timestamp: timestamp, in: region))
        }
        let movedRegion = region.offsetBy(dx: 10, dy: 10)
        for timestamp in [0.16, 0.20, 0.24, 0.28] {
            XCTAssertFalse(gate.sample(at: restingPoint, timestamp: timestamp, in: movedRegion))
        }
        XCTAssertTrue(gate.sample(at: restingPoint, timestamp: 0.32, in: movedRegion))
    }

    func testSamplingGapDoesNotCountAsStationaryTime() {
        var gate = PointerSlowdownGate()

        for timestamp in [0.0, 0.04, 0.08, 0.12] {
            XCTAssertFalse(gate.sample(at: restingPoint, timestamp: timestamp, in: region))
        }
        for timestamp in [1.0, 1.04, 1.08, 1.12] {
            XCTAssertFalse(gate.sample(at: restingPoint, timestamp: timestamp, in: region))
        }
        XCTAssertTrue(gate.sample(at: restingPoint, timestamp: 1.16, in: region))
    }

    func testReversedOrRepeatedTimestampsRequireANewSlowInterval() {
        for discontinuity in [0.10, 0.12] {
            var gate = PointerSlowdownGate()
            for timestamp in [0.0, 0.04, 0.08, 0.12] {
                XCTAssertFalse(gate.sample(at: restingPoint, timestamp: timestamp, in: region))
            }
            XCTAssertFalse(gate.sample(at: restingPoint, timestamp: discontinuity, in: region))
            for offset in [0.04, 0.08, 0.12] {
                XCTAssertFalse(gate.sample(at: restingPoint, timestamp: discontinuity + offset, in: region))
            }
            XCTAssertTrue(gate.sample(at: restingPoint, timestamp: discontinuity + 0.16, in: region))
        }
    }
}
