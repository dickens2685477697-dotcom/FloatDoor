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
        }
        .scrollIndicators(.hidden)
        .hideNativeScrollIndicators()
    }
}

extension View {
    /// SwiftUI's `scrollIndicators(.hidden)` can leave AppKit's scroller alive
    /// after the hosting hierarchy is rebuilt. Keep the underlying NSScrollView
    /// in sync so a custom indicator is never drawn on top of the native one.
    func hideNativeScrollIndicators() -> some View {
        background(NativeScrollIndicatorHider())
    }
}

private struct NativeScrollIndicatorHider: NSViewRepresentable {
    func makeNSView(context: Context) -> IndicatorHidingView {
        IndicatorHidingView()
    }

    func updateNSView(_ nsView: IndicatorHidingView, context: Context) {
        nsView.hideIndicators()
    }
}

private final class IndicatorHidingView: NSView {
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        hideIndicators()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        hideIndicators()
    }

    func hideIndicators() {
        DispatchQueue.main.async { [weak self] in
            guard let scrollView = self?.enclosingScrollView else { return }
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
            scrollView.autohidesScrollers = true
        }
    }
}
