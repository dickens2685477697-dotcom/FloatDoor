import Foundation

struct PortalSelectionModifiers: OptionSet {
    let rawValue: Int

    static let command = PortalSelectionModifiers(rawValue: 1 << 0)
    static let shift = PortalSelectionModifiers(rawValue: 1 << 1)
}

/// Finder-style selection state shared by every visible portal item list.
@MainActor
final class PortalItemSelection: ObservableObject {
    @Published private(set) var selectedIDs: Set<PortalItem.ID> = []

    private var anchorID: PortalItem.ID?

    func isSelected(_ item: PortalItem) -> Bool {
        selectedIDs.contains(item.id)
    }

    func select(
        _ itemID: PortalItem.ID,
        in orderedIDs: [PortalItem.ID],
        modifiers: PortalSelectionModifiers = []
    ) {
        if modifiers.contains(.shift),
           let anchorID,
           let anchorIndex = orderedIDs.firstIndex(of: anchorID),
           let itemIndex = orderedIDs.firstIndex(of: itemID) {
            let bounds = min(anchorIndex, itemIndex)...max(anchorIndex, itemIndex)
            let range = Set(bounds.map { orderedIDs[$0] })
            selectedIDs = modifiers.contains(.command) ? selectedIDs.union(range) : range
            return
        }

        if modifiers.contains(.command) {
            if selectedIDs.contains(itemID) {
                selectedIDs.remove(itemID)
            } else {
                selectedIDs.insert(itemID)
            }
            anchorID = itemID
            return
        }

        selectedIDs = [itemID]
        anchorID = itemID
    }

    /// Finder keeps the current group when dragging a selected item, but first
    /// selects an unselected item exclusively when the drag starts on it.
    func prepareForDrag(_ itemID: PortalItem.ID) {
        guard !selectedIDs.contains(itemID) else { return }
        selectedIDs = [itemID]
        anchorID = itemID
    }

    /// Finder preserves an existing multi-selection when right-clicking one of
    /// its members, but selects an unselected item exclusively before opening
    /// that item's context menu.
    func prepareForContextMenu(_ itemID: PortalItem.ID) {
        guard !selectedIDs.contains(itemID) else { return }
        selectedIDs = [itemID]
        anchorID = itemID
    }

    func selectedItems(from orderedItems: [PortalItem]) -> [PortalItem] {
        orderedItems.filter { selectedIDs.contains($0.id) }
    }

    func clear() {
        selectedIDs.removeAll()
        anchorID = nil
    }

    func retainExistingItems(_ items: [PortalItem]) {
        let existingIDs = Set(items.map(\.id))
        selectedIDs.formIntersection(existingIDs)
        if let anchorID, !existingIDs.contains(anchorID) {
            self.anchorID = nil
        }
    }
}
