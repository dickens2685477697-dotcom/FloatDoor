import XCTest
@testable import FloatDoor

@MainActor
final class PortalItemSelectionTests: XCTestCase {
    private let ids = (0..<5).map { _ in UUID() }

    func testPlainClickSelectsOnlyClickedItem() {
        let selection = PortalItemSelection()
        selection.select(ids[0], in: ids, modifiers: .command)
        selection.select(ids[2], in: ids)

        XCTAssertEqual(selection.selectedIDs, [ids[2]])
    }

    func testCommandClickTogglesItemsIndependently() {
        let selection = PortalItemSelection()
        selection.select(ids[0], in: ids, modifiers: .command)
        selection.select(ids[2], in: ids, modifiers: .command)
        XCTAssertEqual(selection.selectedIDs, [ids[0], ids[2]])

        selection.select(ids[0], in: ids, modifiers: .command)
        XCTAssertEqual(selection.selectedIDs, [ids[2]])
    }

    func testShiftClickSelectsContinuousRangeFromAnchor() {
        let selection = PortalItemSelection()
        selection.select(ids[1], in: ids)
        selection.select(ids[4], in: ids, modifiers: .shift)

        XCTAssertEqual(selection.selectedIDs, Set(ids[1...4]))
    }

    func testCommandShiftClickAddsRangeToExistingSelection() {
        let selection = PortalItemSelection()
        selection.select(ids[0], in: ids, modifiers: .command)
        selection.select(ids[2], in: ids, modifiers: .command)
        selection.select(ids[4], in: ids, modifiers: [.command, .shift])

        XCTAssertEqual(selection.selectedIDs, Set([ids[0], ids[2], ids[3], ids[4]]))
    }

    func testDraggingUnselectedItemSelectsItExclusively() {
        let selection = PortalItemSelection()
        selection.select(ids[0], in: ids, modifiers: .command)
        selection.select(ids[1], in: ids, modifiers: .command)

        selection.prepareForDrag(ids[3])

        XCTAssertEqual(selection.selectedIDs, [ids[3]])
    }

    func testDraggingAnItemInExistingSelectionKeepsWholeSelection() {
        let selection = PortalItemSelection()
        selection.select(ids[0], in: ids, modifiers: .command)
        selection.select(ids[1], in: ids, modifiers: .command)

        selection.prepareForDrag(ids[1])

        XCTAssertEqual(selection.selectedIDs, [ids[0], ids[1]])
    }

    func testContextMenuOnSelectedItemKeepsWholeSelection() {
        let selection = PortalItemSelection()
        selection.select(ids[0], in: ids, modifiers: .command)
        selection.select(ids[1], in: ids, modifiers: .command)

        selection.prepareForContextMenu(ids[1])

        XCTAssertEqual(selection.selectedIDs, [ids[0], ids[1]])
    }

    func testContextMenuOnUnselectedItemSelectsItExclusively() {
        let selection = PortalItemSelection()
        selection.select(ids[0], in: ids, modifiers: .command)
        selection.select(ids[1], in: ids, modifiers: .command)

        selection.prepareForContextMenu(ids[3])

        XCTAssertEqual(selection.selectedIDs, [ids[3]])
    }

    func testClearingSelectionAlsoResetsShiftSelectionAnchor() {
        let selection = PortalItemSelection()
        selection.select(ids[1], in: ids)

        selection.clear()
        selection.select(ids[4], in: ids, modifiers: .shift)

        XCTAssertEqual(selection.selectedIDs, [ids[4]])
    }

    func testSelectedItemsCanResolveAcrossMultiplePanes() {
        let items = ids.map { PortalItem(id: $0, name: $0.uuidString, type: .text, scope: .permanent) }
        let leftPaneIDs = Array(ids[0...1])
        let rightPaneIDs = Array(ids[2...4])
        let selection = PortalItemSelection()
        selection.select(ids[0], in: leftPaneIDs, modifiers: .command)
        selection.select(ids[3], in: rightPaneIDs, modifiers: .command)

        XCTAssertEqual(selection.selectedItems(from: items).map(\.id), [ids[0], ids[3]])
    }

    func testEverySelectedItemProducesOnePasteboardWriterForBatchDrag() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: "FloatDoorSelectionTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let suiteName = "FloatDoorSelectionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            try? FileManager.default.removeItem(at: rootURL)
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = PortalStore(rootURL: rootURL, defaults: defaults)
        let factory = PortalItemProviderFactory(store: store)
        let items = [
            PortalItem(id: ids[0], name: "A", type: .text, scope: .permanent, textContent: "A"),
            PortalItem(id: ids[1], name: "B", type: .text, scope: .permanent, textContent: "B")
        ]
        let selection = PortalItemSelection()
        selection.select(ids[0], in: ids, modifiers: .command)
        selection.select(ids[1], in: ids, modifiers: .command)

        let selected = selection.selectedItems(from: items)
        XCTAssertEqual(factory.pasteboardWriters(for: selected).count, 2)
    }
}
