import AppKit
import SwiftUI

/// AppKit bridge used because SwiftUI's `onDrag` exposes one provider per view.
/// A native dragging session can put every selected provider on one pasteboard.
struct PortalCardDragBridge: NSViewRepresentable {
    let onMouseDown: (PortalSelectionModifiers) -> Void
    let onPrepareForDrag: () -> Void
    let onPrepareForContextMenu: () -> Void
    let onHoverChanged: (Bool) -> Void
    let pasteboardWritersForDrag: () -> [any NSPasteboardWriting]

    func makeNSView(context: Context) -> PortalCardDragView {
        let view = PortalCardDragView()
        view.onMouseDown = onMouseDown
        view.onPrepareForDrag = onPrepareForDrag
        view.onPrepareForContextMenu = onPrepareForContextMenu
        view.onHoverChanged = onHoverChanged
        view.pasteboardWritersForDrag = pasteboardWritersForDrag
        return view
    }

    func updateNSView(_ nsView: PortalCardDragView, context: Context) {
        nsView.onMouseDown = onMouseDown
        nsView.onPrepareForDrag = onPrepareForDrag
        nsView.onPrepareForContextMenu = onPrepareForContextMenu
        nsView.onHoverChanged = onHoverChanged
        nsView.pasteboardWritersForDrag = pasteboardWritersForDrag
    }

    static func dismantleNSView(_ nsView: PortalCardDragView, coordinator: ()) {
        nsView.prepareForRemoval()
    }
}

final class PortalCardDragView: NSView, NSDraggingSource {
    var onMouseDown: ((PortalSelectionModifiers) -> Void)?
    var onPrepareForDrag: (() -> Void)?
    var onPrepareForContextMenu: (() -> Void)?
    var onHoverChanged: ((Bool) -> Void)?
    var pasteboardWritersForDrag: (() -> [any NSPasteboardWriting])?

    private var hoverTrackingArea: NSTrackingArea?
    private var isHovered = false
    private var mouseDownPoint: NSPoint?
    private var mouseDownModifiers: PortalSelectionModifiers = []
    private var hasStartedDrag = false

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        onHoverChanged?(false)
    }

    func prepareForRemoval() {
        if isHovered {
            onHoverChanged?(false)
        }
        isHovered = false
        onHoverChanged = nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Let the surrounding SwiftUI card receive right-click/control-click so
        // its existing contextMenu remains available over the interaction bridge.
        if let event = NSApp.currentEvent,
           Self.shouldPassThroughToContextMenu(
               eventType: event.type,
               modifierFlags: event.modifierFlags
           ) {
            onPrepareForContextMenu?()
            return nil
        }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        mouseDownModifiers = Self.selectionModifiers(from: event.modifierFlags)
        hasStartedDrag = false
    }

    override func mouseUp(with event: NSEvent) {
        guard !hasStartedDrag else { return }
        onMouseDown?(mouseDownModifiers)
    }

    override func mouseDragged(with event: NSEvent) {
        guard !hasStartedDrag, let mouseDownPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - mouseDownPoint.x, point.y - mouseDownPoint.y) >= 3 else { return }
        onPrepareForDrag?()
        guard let writers = pasteboardWritersForDrag?(), !writers.isEmpty else { return }

        hasStartedDrag = true
        let preview = dragPreview(itemCount: writers.count)
        let frame = NSRect(origin: point, size: preview.size)
        let draggingItems = writers.map { writer -> NSDraggingItem in
            let draggingItem = NSDraggingItem(pasteboardWriter: writer)
            draggingItem.setDraggingFrame(frame, contents: preview)
            return draggingItem
        }
        beginDraggingSession(with: draggingItems, event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }

    private static func selectionModifiers(from flags: NSEvent.ModifierFlags) -> PortalSelectionModifiers {
        var modifiers: PortalSelectionModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return modifiers
    }

    static func shouldPassThroughToContextMenu(
        eventType: NSEvent.EventType,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        eventType == .rightMouseDown
            || (eventType == .leftMouseDown && modifierFlags.contains(.control))
    }

    private func dragPreview(itemCount: Int) -> NSImage {
        let size = NSSize(width: 90, height: 42)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.controlAccentColor.withAlphaComponent(0.86).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 10, yRadius: 10).fill()
        let text = itemCount == 1 ? "1 个项目" : "\(itemCount) 个项目"
        text.draw(
            at: NSPoint(x: 14, y: 13),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.white
            ]
        )
        image.unlockFocus()
        return image
    }
}
