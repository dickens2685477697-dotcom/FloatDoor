import SwiftUI

extension Color {
    static let portalAccent = PortalTokens.Palette.accent
}

struct ScopeDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onTargeted: () -> Void
    let onDrop: ([NSItemProvider]) -> Bool

    func dropEntered(info: DropInfo) {
        isTargeted = true
        onTargeted()
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        isTargeted = true
        onTargeted()
        return DropProposal(operation: .copy)
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        return onDrop(info.itemProviders(for: DropImporter.acceptedTypes))
    }
}

// Compatibility names keep the existing portal views source-compatible while
// the implementation now lives in DesignSystem/PortalControlStyles.swift.
typealias CountChip = PortalCountChip
typealias GlassTextButtonStyle = PortalTextButtonStyle
