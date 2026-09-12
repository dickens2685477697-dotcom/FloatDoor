import AppKit
import SwiftUI

struct SlimScrollView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView(.vertical) {
            content
                .tracklessScrollIndicators()
        }
        .scrollIndicators(.visible)
    }
}

extension View {
    /// Retain native scrolling and thumb dragging without an opaque track.
    func tracklessScrollIndicators() -> some View {
        background(TracklessScrollIndicatorInstaller())
    }
}

final class TracklessScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { true }
    override var isOpaque: Bool { false }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        // Intentionally transparent, including while hovered or dragging.
    }
}

private struct TracklessScrollIndicatorInstaller: NSViewRepresentable {
    func makeNSView(context: Context) -> TracklessScrollIndicatorView {
        TracklessScrollIndicatorView()
    }

    func updateNSView(_ nsView: TracklessScrollIndicatorView, context: Context) {
        nsView.scheduleInstallation()
    }
}

final class TracklessScrollIndicatorView: NSView {
    private var installationPending = false

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        scheduleInstallation()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleInstallation()
    }

    override func layout() {
        super.layout()
        scheduleInstallation()
    }

    func scheduleInstallation() {
        guard !installationPending else { return }
        installationPending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.installationPending = false
            self.installIndicators()
        }
    }

    func installIndicators() {
        if let scrollView = enclosingScrollView {
            configure(scrollView)
            return
        }
        // TextEditor owns its NSScrollView rather than enclosing the background
        // probe. Search the nearest containing SwiftUI subtree in that case.
        var ancestor = superview
        while let view = ancestor {
            let scrollViews = Self.scrollViews(in: view)
            if !scrollViews.isEmpty {
                scrollViews.forEach(configure)
                return
            }
            ancestor = view.superview
        }
    }

    private static func scrollViews(in view: NSView) -> [NSScrollView] {
        if let scrollView = view as? NSScrollView { return [scrollView] }
        return view.subviews.flatMap { scrollViews(in: $0) }
    }

    private func configure(_ scrollView: NSScrollView) {
        if !(scrollView.verticalScroller is TracklessScroller) {
            scrollView.verticalScroller = TracklessScroller()
        }
        if scrollView.hasHorizontalScroller,
           !(scrollView.horizontalScroller is TracklessScroller) {
            scrollView.horizontalScroller = TracklessScroller()
        }
        if scrollView.scrollerStyle != .overlay { scrollView.scrollerStyle = .overlay }
        if !scrollView.hasVerticalScroller { scrollView.hasVerticalScroller = true }
        if !scrollView.autohidesScrollers { scrollView.autohidesScrollers = true }
    }
}
