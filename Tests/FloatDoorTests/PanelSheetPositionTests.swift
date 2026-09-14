import AppKit
import XCTest
@testable import FloatDoor

@MainActor
final class PanelSheetPositionTests: XCTestCase {
    func testAllEditorEntrypointsLeaveParentUnchanged() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "FloatDoorEditorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let store = PortalStore(rootURL: directory, defaults: defaults)
        store.importText("Editor regression fixture", into: .permanent)
        store.dismissNotice()
        let item = try XCTUnwrap(store.permanentItems.first)
        let controller = NotchPanelController(store: store)
        controller.install()
        let panel = try XCTUnwrap(controller.panel)
        panel.isReleasedWhenClosed = false
        defer {
            controller.dismissEditor()
            panel.contentViewController = nil
            panel.close()
        }
        controller.show()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        let originalFrame = panel.frame
        let container = try XCTUnwrap(panel.contentView as? TrackingContainerView)
        let originalSize = container.bounds.size
        let originalImage = try render(panel)
        let openEditors: [() -> Void] = [
            { controller.presentNewMaterialEditor(scope: .permanent) },
            { controller.presentNewMaterialEditor(scope: .custom) },
            { controller.presentAreaRenameEditor(scope: .permanent) },
            { controller.presentAreaRenameEditor(scope: .custom) },
            { controller.presentItemRenameEditor(item) }
        ]
        for openEditor in openEditors {
            openEditor()
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            let editor = try XCTUnwrap(panel.childWindows?.first)
            XCTAssertNil(panel.attachedSheet, "No native sheet dimming or rectangular backdrop")
            XCTAssertEqual(panel.frame, originalFrame)
            XCTAssertEqual(container.bounds.size, originalSize)
            XCTAssertEqual(panel.level, .statusBar)
            XCTAssertEqual(panel.alphaValue, 1)
            XCTAssertEqual(editor.level, panel.level)
            XCTAssertTrue(container.isModalBlocked)
            XCTAssertTrue(container.hitTest(NSPoint(x: 288, y: 282)) === container)
            XCTAssertNil(container.destination(atWindowPoint: NSPoint(x: 190, y: 140)))
            XCTAssertTrue(editor.firstResponder is NSTextView, "Typing must focus the editor")
            let presentedImage = try render(panel)
            assertTransparentBottomCorners(presentedImage)
            // Sample unobscured shelf pixels, including the header. The parent
            // rendering must not acquire native sheet dimming while editing.
            for point in [NSPoint(x: 20, y: 100), NSPoint(x: 360, y: 400)] {
                let x = Int(point.x * CGFloat(originalImage.pixelsWide) / originalSize.width)
                let y = Int(point.y * CGFloat(originalImage.pixelsHigh) / originalSize.height)
                let before = try XCTUnwrap(originalImage.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                let after = try XCTUnwrap(presentedImage.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                XCTAssertEqual(before.redComponent, after.redComponent, accuracy: 0.02)
                XCTAssertEqual(before.greenComponent, after.greenComponent, accuracy: 0.02)
                XCTAssertEqual(before.blueComponent, after.blueComponent, accuracy: 0.02)
                XCTAssertEqual(before.alphaComponent, after.alphaComponent, accuracy: 0.02)
            }
            controller.pointerEntered()
            controller.collapse()
            XCTAssertTrue(controller.isExpanded)
            openEditor()
            XCTAssertEqual(panel.childWindows?.count, 1)
            controller.dismissEditor()
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            XCTAssertEqual(panel.frame, originalFrame)
            XCTAssertTrue(controller.isExpanded, "Closing the editor must leave the shelf open")
            XCTAssertFalse(container.isModalBlocked)
            XCTAssertTrue(panel.childWindows?.isEmpty ?? true)
        }
    }

    private func render(_ panel: NSWindow) throws -> NSBitmapImageRep {
        let view = try XCTUnwrap(panel.contentView?.superview)
        view.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return bitmap
    }

    private func assertTransparentBottomCorners(_ bitmap: NSBitmapImageRep) {
        for x in [1, bitmap.pixelsWide - 2] {
            XCTAssertLessThan(bitmap.colorAt(x: x, y: bitmap.pixelsHigh - 2)?.alphaComponent ?? 1, 0.01,
                              "The native frame must remain transparent outside the rounded shelf")
        }
    }

    func testSheetPresentationPreservesTopAnchoredPanelFrame() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let frame = NSRect(x: screen.frame.midX - 360, y: screen.frame.maxY - 432, width: 720, height: 432)
        let panel = NotchPanel(contentRect: frame)
        panel.isReleasedWhenClosed = false
        panel.contentView = NSView(frame: NSRect(origin: .zero, size: frame.size))
        defer { panel.close() }
        panel.setFrame(frame, display: false)
        panel.makeKeyAndOrderFront(nil)
        for size in [NSSize(width: 400, height: 295), NSSize(width: 340, height: 160)] {
            let sheet = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            sheet.isReleasedWhenClosed = false
            panel.level = .modalPanel
            panel.beginSheet(sheet)
            RunLoop.main.run(until: Date().addingTimeInterval(0.35))
            XCTAssertEqual(panel.frame, frame, "Opening the editor must not move the top-anchored panel")
            panel.endSheet(sheet)
            RunLoop.main.run(until: Date().addingTimeInterval(0.35))
            sheet.close()
            panel.level = .statusBar
            XCTAssertEqual(panel.frame, frame, "Closing the editor must not move the panel")
        }
    }
}
