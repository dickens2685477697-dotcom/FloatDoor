import AppKit
import SwiftUI
import XCTest
@testable import FloatDoor

@MainActor
final class PortalControlHitTestingTests: XCTestCase {
    func testNotchPanelDoesNotConsumeClicksToActivateTheApp() {
        let panel = NotchPanel(contentRect: .zero)

        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(panel.becomesKeyOnlyIfNeeded)
        XCTAssertTrue(panel.canBecomeKey)
    }

    func testNativeHeaderHotspotsReceiveFirstClickAndRouteEveryAction() throws {
        var performedActions: [String] = []
        let container = TrackingContainerView(frame: NSRect(x: 0, y: 0, width: 720, height: 432))
        container.installActionHotspots(
            createMaterial: { performedActions.append("create-material") },
            renameMaterialArea: { performedActions.append("rename-material") },
            createCustomMaterial: { performedActions.append("create-custom") },
            renameCustomArea: { performedActions.append("rename-custom") }
        )
        let panel = NotchPanel(contentRect: container.frame)
        panel.contentView = container
        panel.makeKeyAndOrderFront(nil)
        defer { panel.close() }
        container.layoutSubtreeIfNeeded()

        let hotspotCenters = [
            NSPoint(x: 288.5, y: 282.5),
            NSPoint(x: 345, y: 282),
            NSPoint(x: 635.5, y: 282.5),
            NSPoint(x: 692, y: 282)
        ]

        for point in hotspotCenters {
            let button = try XCTUnwrap(container.hitTest(point) as? NSButton)
            XCTAssertTrue(button.acceptsFirstMouse(for: nil))
            button.performClick(nil)
        }

        XCTAssertEqual(
            performedActions,
            ["create-material", "rename-material", "create-custom", "rename-custom"]
        )
    }

    func testNativeCardHotspotsReceiveFirstClickAndRouteEveryAction() throws {
        var performedActions: [String] = []
        let actionButton = FirstMouseCardActionButton()
        actionButton.configure {
            performedActions.append("promote-button")
        }

        XCTAssertTrue(actionButton.acceptsFirstMouse(for: nil))
        actionButton.performClick(nil)

        let menuButton = FirstMouseCardMenuButton()
        menuButton.configure(
            includesPromote: true,
            onPromote: { performedActions.append("promote-menu") },
            onRename: { performedActions.append("rename") },
            onDelete: { performedActions.append("delete") },
            onTrackingChanged: { _ in }
        )

        XCTAssertTrue(menuButton.acceptsFirstMouse(for: nil))
        let menu = menuButton.actionMenu
        for title in ["转为长期素材", "重命名", "删除"] {
            let item = try XCTUnwrap(menu.item(withTitle: title))
            XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(item.action), to: item.target, from: item))
        }

        XCTAssertEqual(
            performedActions,
            ["promote-button", "promote-menu", "rename", "delete"]
        )
    }

    func testCardMenuButtonActuallyOpensItsNativeMenu() throws {
        var trackingStates: [Bool] = []
        let menuButton = FirstMouseCardMenuButton()
        menuButton.configure(
            includesPromote: false,
            onPromote: {},
            onRename: {},
            onDelete: {},
            onTrackingChanged: { trackingStates.append($0) }
        )
        let panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 25, height: 25))
        panel.contentView = menuButton
        panel.makeKeyAndOrderFront(nil)
        defer { panel.close() }

        let menuDelegate = MenuOpenSpy()
        let menu = menuButton.actionMenu
        menu.delegate = menuDelegate
        let escapeEvent = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: "\u{1B}",
            charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false,
            keyCode: 53
        ))
        NSApp.postEvent(escapeEvent, atStart: false)

        let mouseDown = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: menuButton.bounds.midX, y: menuButton.bounds.midY),
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
        menuButton.mouseDown(with: mouseDown)
        XCTAssertTrue(menuDelegate.didOpen)
        XCTAssertEqual(trackingStates, [true, false])
    }

    func testFirstCardControlCoordinatesHitNativeFirstMouseViews() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: "FloatDoor-Card-HitTest-\(UUID().uuidString)", directoryHint: .isDirectory)
        let suiteName = "FloatDoor-Card-HitTest-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: rootURL)
        }

        let store = PortalStore(rootURL: rootURL, defaults: defaults)
        store.importText("First card", into: .temporary)
        let item = try XCTUnwrap(store.temporaryItems.first)
        let selection = PortalItemSelection()
        let card = PortalItemCard(
            item: item,
            store: store,
            panelController: NotchPanelController(store: store),
            itemProviderFactory: PortalItemProviderFactory(store: store),
            selection: selection,
            orderedItems: [item],
            draggableItems: [item]
        )
        let hostingController = NSHostingController(rootView: card)
        let panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 664, height: 70))
        panel.contentViewController = hostingController
        panel.makeKeyAndOrderFront(nil)
        defer { panel.close() }
        hostingController.view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        let actionButton = try XCTUnwrap(firstSubview(of: FirstMouseCardActionButton.self, in: hostingController.view))
        let menuButton = try XCTUnwrap(firstSubview(of: FirstMouseCardMenuButton.self, in: hostingController.view))

        XCTAssertTrue(actionButton.acceptsFirstMouse(for: nil))
        XCTAssertTrue(menuButton.acceptsFirstMouse(for: nil))
        XCTAssertTrue(hitView(atCenterOf: actionButton, in: hostingController.view) is FirstMouseCardActionButton)
        XCTAssertTrue(hitView(atCenterOf: menuButton, in: hostingController.view) is FirstMouseCardMenuButton)

        actionButton.performClick(nil)
        XCTAssertTrue(store.temporaryItems.isEmpty)
        XCTAssertEqual(store.permanentItems.count, 1)

        let deleteItem = try XCTUnwrap(menuButton.actionMenu.item(withTitle: "删除"))
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(deleteItem.action), to: deleteItem.target, from: deleteItem))
        XCTAssertTrue(store.permanentItems.isEmpty)
    }

    func testPermanentMaterialFirstCardMenuOpensFromWindowMouseDown() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: "FloatDoor-Material-Menu-\(UUID().uuidString)", directoryHint: .isDirectory)
        let suiteName = "FloatDoor-Material-Menu-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: rootURL)
        }

        let store = PortalStore(rootURL: rootURL, defaults: defaults)
        store.importText("First material", into: .permanent)
        let controller = NotchPanelController(store: store)
        controller.install()
        controller.show()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        controller.setDragHoveredDestination(.permanentTab)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        let panel = try XCTUnwrap(NSApp.windows.first {
            $0 is NotchPanel
                && $0.isVisible
                && $0.frame.size == NotchPanelController.expandedSize
                && $0.contentView is TrackingContainerView
        } as? NotchPanel)
        let container = try XCTUnwrap(panel.contentView as? TrackingContainerView)
        defer {
            panel.contentViewController = nil
            panel.close()
        }
        let menuButton = try XCTUnwrap(firstSubview(of: FirstMouseCardMenuButton.self, in: container))
        let menuCenter = NSPoint(x: menuButton.bounds.midX, y: menuButton.bounds.midY)
        let containerPoint = menuButton.convert(menuCenter, to: container)
        let hitView = container.hitTest(containerPoint)
        XCTAssertTrue(
            hitView is FirstMouseCardMenuButton,
            "Expected material menu button, hit \(hitView.map { String(describing: type(of: $0)) } ?? "nil") at \(containerPoint)"
        )

        let menuDelegate = MenuOpenSpy()
        menuButton.actionMenu.delegate = menuDelegate
        let escapeEvent = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: "\u{1B}",
            charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false,
            keyCode: 53
        ))
        NSApp.postEvent(escapeEvent, atStart: false)
        let mouseDown = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: menuButton.convert(menuCenter, to: nil),
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))

        panel.sendEvent(mouseDown)
        XCTAssertTrue(menuDelegate.didOpen)
    }

    func testDragHoverOverPermanentTabUsesWindowCoordinates() {
        let (panel, container) = makeDragContainer()
        defer { panel.close() }
        container.activeSection = .temporary

        XCTAssertEqual(
            container.destination(atWindowPoint: NSPoint(x: 520, y: 335)),
            .permanentTab
        )
    }

    func testCustomAreaAcceptsTheSameWindowCoordinateDragHitAsMaterialArea() {
        let (panel, container) = makeDragContainer()
        defer { panel.close() }
        container.activeSection = .permanent

        XCTAssertEqual(
            container.destination(atWindowPoint: NSPoint(x: 190, y: 140)),
            .permanentArea
        )
        XCTAssertEqual(
            container.destination(atWindowPoint: NSPoint(x: 540, y: 140)),
            .customArea
        )
    }

    func testMainMenuProvidesStandardTextEditingShortcuts() throws {
        let mainMenu = ApplicationMenuFactory.makeMainMenu()
        let editMenu = try XCTUnwrap(mainMenu.items.first { $0.submenu?.title == "编辑" }?.submenu)

        XCTAssertEqual(editMenu.item(withTitle: "复制")?.action, Selector(("copy:")))
        XCTAssertEqual(editMenu.item(withTitle: "复制")?.keyEquivalent, "c")
        XCTAssertEqual(editMenu.item(withTitle: "粘贴")?.action, Selector(("paste:")))
        XCTAssertEqual(editMenu.item(withTitle: "粘贴")?.keyEquivalent, "v")
        XCTAssertEqual(editMenu.item(withTitle: "全选")?.action, Selector(("selectAll:")))
    }

    func testCardDragBridgePassesContextMenuClicksThroughToSwiftUI() {
        XCTAssertTrue(
            PortalCardDragView.shouldPassThroughToContextMenu(
                eventType: .rightMouseDown,
                modifierFlags: []
            )
        )
        XCTAssertTrue(
            PortalCardDragView.shouldPassThroughToContextMenu(
                eventType: .leftMouseDown,
                modifierFlags: .control
            )
        )
        XCTAssertFalse(
            PortalCardDragView.shouldPassThroughToContextMenu(
                eventType: .leftMouseDown,
                modifierFlags: []
            )
        )
    }

    private func makeDragContainer() -> (NotchPanel, TrackingContainerView) {
        let container = TrackingContainerView(frame: NSRect(x: 0, y: 0, width: 720, height: 432))
        let panel = NotchPanel(contentRect: container.frame)
        panel.setFrameOrigin(NSPoint(x: 900, y: 500))
        panel.contentView = container

        // A non-zero screen origin is intentional:
        // treating draggingLocation as a screen point would make these hits
        // miss the panel entirely.
        XCTAssertNotNil(container.window)
        return (panel, container)
    }

    private func firstSubview<T: NSView>(of type: T.Type, in root: NSView) -> T? {
        if let match = root as? T { return match }
        for subview in root.subviews {
            if let match = firstSubview(of: type, in: subview) {
                return match
            }
        }
        return nil
    }

    private func hitView(atCenterOf target: NSView, in root: NSView) -> NSView? {
        let center = NSPoint(x: target.bounds.midX, y: target.bounds.midY)
        return root.hitTest(target.convert(center, to: root))
    }

}

private final class MenuOpenSpy: NSObject, NSMenuDelegate {
    private(set) var didOpen = false

    func menuWillOpen(_ menu: NSMenu) {
        didOpen = true
    }
}
