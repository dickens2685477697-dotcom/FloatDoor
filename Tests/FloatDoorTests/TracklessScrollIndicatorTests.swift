import AppKit
import SwiftUI
import XCTest
@testable import FloatDoor

@MainActor
final class TracklessScrollIndicatorTests: XCTestCase {
    func testBothMaterialPanesKeepNativeThumbsWithoutTracks() throws {
        let content = HStack {
            SlimScrollView {
                VStack { ForEach(0..<30) { Text("Material \($0)") } }
            }
            SlimScrollView {
                VStack { ForEach(0..<30) { Text("Prompt \($0)") } }
            }
        }
        let host = NSHostingView(rootView: content)
        let window = hostOffscreen(host)
        defer { window.contentView = nil }
        let scrollViews = descendants(of: host)
        XCTAssertEqual(scrollViews.count, 2)
        for scroll in scrollViews {
            XCTAssertTrue(scroll.verticalScroller is TracklessScroller)
            XCTAssertTrue(scroll.hasVerticalScroller)
            XCTAssertEqual(scroll.scrollerStyle, .legacy)
            XCTAssertFalse(try XCTUnwrap(scroll.verticalScroller).isOpaque)
            assertGutterDoesNotCoverContent(scroll)
            XCTAssertGreaterThan(try XCTUnwrap(scroll.documentView).bounds.height, scroll.contentSize.height)
            scroll.contentView.scroll(to: NSPoint(x: 0, y: 100))
            scroll.reflectScrolledClipView(scroll.contentView)
            XCTAssertGreaterThan(scroll.contentView.bounds.origin.y, 0)
        }
    }

    func testTextEditorUsesSameThumbAfterViewUpdate() {
        let editor = TextEditor(text: .constant(String(repeating: "Long material text\n", count: 50)))
            .tracklessScrollIndicators()
        let host = NSHostingView(rootView: editor)
        let window = hostOffscreen(host)
        defer { window.contentView = nil }
        host.rootView = editor
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        let scrollViews = descendants(of: host)
        XCTAssertEqual(scrollViews.count, 1)
        XCTAssertTrue(scrollViews.first?.verticalScroller is TracklessScroller)
        XCTAssertEqual(scrollViews.first?.scrollerStyle, .legacy)
        if let scroll = scrollViews.first { assertGutterDoesNotCoverContent(scroll) }
    }

    private func assertGutterDoesNotCoverContent(_ scroll: NSScrollView, file: StaticString = #filePath, line: UInt = #line) {
        scroll.tile()
        guard let scroller = scroll.verticalScroller else {
            XCTFail("Missing native scrollbar", file: file, line: line)
            return
        }
        let contentRect = scroll.contentView.convert(scroll.contentView.bounds, to: scroll)
        let scrollerRect = scroller.convert(scroller.bounds, to: scroll)
        XCTAssertGreaterThan(scrollerRect.width, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(contentRect.maxX, scrollerRect.minX, file: file, line: line)
        XCTAssertFalse(scroll.drawsBackground, file: file, line: line)
    }

    private func hostOffscreen(_ host: NSView) -> NSWindow {
        host.frame = NSRect(x: 0, y: 0, width: 600, height: 200)
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        return window
    }

    private func descendants(of view: NSView) -> [NSScrollView] {
        if let scroll = view as? NSScrollView { return [scroll] }
        return view.subviews.flatMap { descendants(of: $0) }
    }
}
