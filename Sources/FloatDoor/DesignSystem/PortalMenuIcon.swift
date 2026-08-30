import AppKit

/// Monochrome companion for the coloured glass icon set. Menu-bar artwork
/// must remain a template image so macOS can adapt it to light/dark desktops.
enum PortalMenuIcon {
    static func door() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.labelColor.setStroke()
            NSColor.labelColor.setFill()

            let frame = NSBezierPath()
            frame.lineWidth = 1.5
            frame.lineCapStyle = .round
            frame.lineJoinStyle = .round
            frame.move(to: NSPoint(x: 4, y: 3))
            frame.line(to: NSPoint(x: 4, y: 14.5))
            frame.line(to: NSPoint(x: 11.5, y: 16))
            frame.line(to: NSPoint(x: 11.5, y: 2))
            frame.close()
            frame.stroke()

            let jamb = NSBezierPath()
            jamb.lineWidth = 1.5
            jamb.lineCapStyle = .round
            jamb.move(to: NSPoint(x: 11.5, y: 14.5))
            jamb.line(to: NSPoint(x: 15, y: 14.5))
            jamb.line(to: NSPoint(x: 15, y: 3.5))
            jamb.line(to: NSPoint(x: 11.5, y: 3.5))
            jamb.stroke()

            NSBezierPath(ovalIn: NSRect(x: 9.2, y: 8.4, width: 1.4, height: 1.4)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Float Door"
        return image
    }
}
