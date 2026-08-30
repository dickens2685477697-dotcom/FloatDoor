import AppKit
import SwiftUI

/// Keeps card actions on AppKit's first-mouse path while SwiftUI continues to
/// own their visual and accessibility presentation.
struct PortalCardActionHotspot: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> FirstMouseCardActionButton {
        let button = FirstMouseCardActionButton()
        button.configure(action: action)
        return button
    }

    func updateNSView(_ nsView: FirstMouseCardActionButton, context: Context) {
        nsView.configure(action: action)
    }
}

struct PortalCardMenuHotspot: NSViewRepresentable {
    let includesPromote: Bool
    let onPromote: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let onTrackingChanged: (Bool) -> Void

    func makeNSView(context: Context) -> FirstMouseCardMenuButton {
        let button = FirstMouseCardMenuButton()
        configure(button)
        return button
    }

    func updateNSView(_ nsView: FirstMouseCardMenuButton, context: Context) {
        configure(nsView)
    }

    private func configure(_ button: FirstMouseCardMenuButton) {
        button.configure(
            includesPromote: includesPromote,
            onPromote: onPromote,
            onRename: onRename,
            onDelete: onDelete,
            onTrackingChanged: onTrackingChanged
        )
    }
}

final class FirstMouseCardActionButton: NSButton {
    private var actionHandler: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        title = ""
        isBordered = false
        focusRingType = .none
        refusesFirstResponder = true
        setAccessibilityElement(false)
        target = self
        action = #selector(performAction)
    }

    convenience init() {
        self.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(action: @escaping () -> Void) {
        actionHandler = action
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    @objc private func performAction() {
        actionHandler?()
    }
}

final class FirstMouseCardMenuButton: NSButton {
    private var promoteHandler: (() -> Void)?
    private var renameHandler: (() -> Void)?
    private var deleteHandler: (() -> Void)?
    private var trackingChangedHandler: ((Bool) -> Void)?
    private(set) var actionMenu = NSMenu()

    init() {
        super.init(frame: .zero)
        title = ""
        isBordered = false
        focusRingType = .none
        refusesFirstResponder = true
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        includesPromote: Bool,
        onPromote: @escaping () -> Void,
        onRename: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onTrackingChanged: @escaping (Bool) -> Void
    ) {
        promoteHandler = onPromote
        renameHandler = onRename
        deleteHandler = onDelete
        trackingChangedHandler = onTrackingChanged

        let menu = NSMenu()
        menu.autoenablesItems = false
        if includesPromote {
            menu.addItem(actionItem(
                title: "转为长期素材",
                systemImageName: "archivebox",
                action: #selector(performPromote)
            ))
        }
        menu.addItem(actionItem(
            title: "重命名",
            systemImageName: "pencil",
            action: #selector(performRename)
        ))
        menu.addItem(.separator())
        let deleteItem = actionItem(
            title: "删除",
            systemImageName: "trash",
            action: #selector(performDelete)
        )
        deleteItem.attributedTitle = NSAttributedString(
            string: "删除",
            attributes: [.foregroundColor: NSColor.systemRed]
        )
        menu.addItem(deleteItem)
        actionMenu = menu
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        trackingChangedHandler?(true)
        defer { trackingChangedHandler?(false) }
        actionMenu.popUp(
            positioning: nil,
            at: NSPoint(x: bounds.maxX, y: bounds.maxY),
            in: self
        )
    }

    private func actionItem(title: String, systemImageName: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = true
        item.image = NSImage(systemSymbolName: systemImageName, accessibilityDescription: nil)
        return item
    }

    @objc private func performPromote() {
        promoteHandler?()
    }

    @objc private func performRename() {
        renameHandler?()
    }

    @objc private func performDelete() {
        deleteHandler?()
    }
}
