import AppKit
import XCTest
@testable import FloatDoor

@MainActor
final class PanelPointerActivationTests: XCTestCase {
    func testEnteringAndMovingQuicklyDoesNotRevealPanel() throws {
        try withController { controller, panel in
            controller.pointerEntered()
            XCTAssertFalse(controller.isExpanded, "Entry alone must not reveal the panel")

            for index in 0...15 {
                let point = NSPoint(x: panel.frame.minX + 20 + CGFloat(index) * 10, y: panel.frame.midY)
                controller.samplePointerActivation(at: point, timestamp: 1 + Double(index) * 0.02)
                XCTAssertFalse(controller.isExpanded, "A fast pass must stay collapsed even after the dwell duration")
            }
        }
    }

    func testSlowingToAStopRevealsPanelOnlyAfterSustainedSlowInterval() throws {
        try withController { controller, panel in
            controller.pointerEntered()
            let entry = NSPoint(x: panel.frame.midX - 12, y: panel.frame.midY)
            let stop = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
            controller.samplePointerActivation(at: entry, timestamp: 1)
            controller.samplePointerActivation(at: stop, timestamp: 1.02)

            for index in 2...8 {
                controller.samplePointerActivation(at: stop, timestamp: 1 + Double(index) * 0.02)
                XCTAssertFalse(controller.isExpanded)
            }
            controller.samplePointerActivation(at: stop, timestamp: 1.18)
            XCTAssertTrue(controller.isExpanded)
        }
    }

    func testSustainedSlowMovementRevealsPanelWithoutRequiringACompleteStop() throws {
        try withController { controller, panel in
            controller.pointerEntered()
            let origin = NSPoint(x: panel.frame.midX - 20, y: panel.frame.midY)
            for index in 0...7 {
                let point = NSPoint(x: origin.x + CGFloat(index), y: origin.y)
                controller.samplePointerActivation(at: point, timestamp: 1 + Double(index) * 0.02)
                XCTAssertFalse(controller.isExpanded)
            }
            controller.samplePointerActivation(at: NSPoint(x: origin.x + 8, y: origin.y), timestamp: 1.16)
            XCTAssertTrue(controller.isExpanded)
        }
    }

    func testExitAndReentryRequireANewSlowInterval() throws {
        try withController { controller, panel in
            let point = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
            controller.pointerEntered()
            for index in 0...5 {
                controller.samplePointerActivation(at: point, timestamp: 1 + Double(index) * 0.02)
            }
            controller.pointerExited()
            for index in 6...15 {
                controller.samplePointerActivation(at: point, timestamp: 1 + Double(index) * 0.02)
            }
            XCTAssertFalse(controller.isExpanded, "Samples after exit must not complete an abandoned candidate")

            controller.pointerEntered()
            for index in 0...7 {
                controller.samplePointerActivation(at: point, timestamp: 2 + Double(index) * 0.02)
                XCTAssertFalse(controller.isExpanded)
            }
            controller.samplePointerActivation(at: point, timestamp: 2.16)
            XCTAssertTrue(controller.isExpanded)
        }
    }

    func testExplicitShowIsImmediateAndCollapseCancelsPendingActivation() throws {
        try withController { controller, panel in
            let point = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
            controller.pointerEntered()
            for index in 0...5 {
                controller.samplePointerActivation(at: point, timestamp: 1 + Double(index) * 0.02)
            }
            controller.collapse()
            for index in 6...15 {
                controller.samplePointerActivation(at: point, timestamp: 1 + Double(index) * 0.02)
            }
            XCTAssertFalse(controller.isExpanded)

            controller.show()
            XCTAssertTrue(controller.isExpanded, "Explicit opening must bypass the pointer speed gate")
        }
    }

    func testReleasedDragDoesNotRevealPanelAfterItsSlowInterval() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let point = NSPoint(x: screen.frame.midX, y: screen.frame.maxY - 10)
        try withController { controller, _ in
            controller.draggingEnteredPanel()
            for index in 0...12 {
                controller.samplePointerActivation(
                    at: point,
                    timestamp: 1 + Double(index) * 0.02,
                    isLeftMouseButtonPressed: false
                )
                XCTAssertFalse(controller.isExpanded)
            }
            XCTAssertFalse(controller.isExpanded, "Releasing before activation must abandon the drag candidate")
        }
    }

    func testTimerRecognizesStationaryPointerWithoutFurtherMouseEvents() throws {
        try withController { controller, panel in
            let pointer = NSEvent.mouseLocation
            panel.setFrameOrigin(NSPoint(x: pointer.x - panel.frame.width / 2, y: pointer.y - panel.frame.height / 2))
            controller.pointerEntered()
            XCTAssertFalse(controller.isExpanded)

            let deadline = Date().addingTimeInterval(0.6)
            while !controller.isExpanded, Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            }

            XCTAssertTrue(controller.isExpanded, "The common-runloop timer must detect a stop without more motion events")
        }
    }

    private func withController(_ body: (NotchPanelController, NotchPanel) throws -> Void) throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "FloatDoorPointerActivationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let store = PortalStore(rootURL: directory, defaults: defaults)
        let controller = NotchPanelController(store: store)
        controller.install()
        let panel = try XCTUnwrap(controller.panel)
        panel.isReleasedWhenClosed = false
        // Deterministic samples must not compete with real hover callbacks or
        // button presses while the user is working elsewhere on the display.
        panel.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        controller.collapse()
        XCTAssertFalse(controller.isExpanded)
        defer {
            controller.collapse()
            panel.contentViewController = nil
            panel.close()
        }
        try body(controller, panel)
    }
}
