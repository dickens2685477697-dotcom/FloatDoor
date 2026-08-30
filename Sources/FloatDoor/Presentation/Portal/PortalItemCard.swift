import AppKit
import SwiftUI

struct PortalItemCard: View {
    let item: PortalItem
    @ObservedObject var store: PortalStore
    @ObservedObject var panelController: NotchPanelController
    let itemProviderFactory: PortalItemProviderFactory
    @ObservedObject var selection: PortalItemSelection
    let orderedItems: [PortalItem]
    let draggableItems: [PortalItem]

    @State private var isShowingRenameSheet = false
    @State private var proposedName = ""

    var body: some View {
        HStack(spacing: 11) {
            HStack(spacing: 11) {
                leadingVisual

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)

                    Text(item.contentSummary)
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)

                    HStack(spacing: 7) {
                        HStack(spacing: 3) {
                            PortalIcon(glyph: .clock, size: 13, showsPlate: false)
                                .accessibilityHidden(true)
                            Text(item.createdAt, style: .relative)
                        }

                        if let expiresAt = item.expiresAt {
                            Text(expiresAt, style: .relative)
                                .foregroundStyle(item.isExpired ? .red : .orange)
                        }
                    }
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                }

                Spacer(minLength: 4)
            }
            .contentShape(Rectangle())
            .overlay {
                PortalCardDragBridge(
                    onMouseDown: { modifiers in
                        selection.select(item.id, in: orderedItems.map(\.id), modifiers: modifiers)
                    },
                    onPrepareForDrag: {
                        selection.prepareForDrag(item.id)
                    },
                    onPrepareForContextMenu: {
                        selection.prepareForContextMenu(item.id)
                    },
                    onHoverChanged: { isHovered in
                        panelController.setCopyHoveredItem(item.id, isHovered: isHovered)
                    },
                    pasteboardWritersForDrag: {
                        let selected = selection.selectedItems(from: draggableItems)
                        return itemProviderFactory.pasteboardWriters(for: selected)
                    }
                )
            }

            HStack(spacing: 5) {
                if item.scope == .temporary {
                    Button {
                        store.promote(item)
                    } label: {
                        PortalIcon(glyph: .permanent, size: 25, tint: PortalTokens.Palette.accent, showsPlate: false)
                    }
                    .buttonStyle(.plain)
                    .help("转为长期素材")
                    .accessibilityLabel("转为长期素材")
                    .overlay {
                        PortalCardActionHotspot {
                            store.promote(item)
                        }
                        .accessibilityHidden(true)
                    }
                }

                Menu {
                    if item.scope == .temporary {
                        Button {
                            store.promote(item)
                        } label: {
                            Label {
                                Text("转为长期素材")
                            } icon: {
                                PortalIcon(glyph: .permanent, size: 14, showsPlate: false)
                            }
                        }
                    }
                    Button {
                        presentRenameSheet()
                    } label: {
                        Label {
                            Text("重命名")
                        } icon: {
                            PortalIcon(glyph: .rename, size: 14, showsPlate: false)
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        store.delete(item)
                    } label: {
                        Label {
                            Text("删除")
                        } icon: {
                            PortalIcon(glyph: .delete, size: 14, showsPlate: false)
                        }
                    }
                } label: {
                    PortalIcon(glyph: .more, size: 25, showsPlate: false)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .frame(width: 25, height: 25)
                .accessibilityLabel("更多操作")
                .overlay {
                    PortalCardMenuHotspot(
                        includesPromote: item.scope == .temporary,
                        onPromote: { store.promote(item) },
                        onRename: presentRenameSheet,
                        onDelete: { store.delete(item) },
                        onTrackingChanged: { isTracking in
                            if isTracking {
                                panelController.beginTransientInteraction()
                            } else {
                                panelController.endTransientInteraction()
                            }
                        }
                    )
                    .accessibilityHidden(true)
                }
            }
        }
        .padding(10)
        .portalGlass(
            cornerRadius: PortalTokens.Radius.medium,
            emphasized: selection.isSelected(item),
            strokeColor: selection.isSelected(item) ? Color.portalAccent.opacity(0.95) : nil
        )
        .overlay {
            if selection.isSelected(item) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.portalAccent.opacity(0.10))
                    .allowsHitTesting(false)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .contextMenu {
            if item.scope == .temporary {
                Button("转为长期素材") {
                    store.promote(item)
                }
            }
            Button("重命名") {
                presentRenameSheet()
            }
            Divider()
            Button(contextDeleteTitle) {
                store.delete(contextDeleteTargets)
            }
        }
        .accessibilityAddTraits(selection.isSelected(item) ? .isSelected : [])
        .sheet(isPresented: $isShowingRenameSheet, onDismiss: {
            panelController.endModalInteraction()
        }) {
            RenameItemSheet(
                proposedName: $proposedName,
                originalName: item.name,
                onSave: { store.rename(item, to: proposedName) }
            )
        }
    }

    private func presentRenameSheet() {
        panelController.beginModalInteraction()
        proposedName = item.name
        isShowingRenameSheet = true
    }

    private var contextDeleteTargets: [PortalItem] {
        let selectedItems = selection.selectedItems(from: draggableItems)
        return selection.isSelected(item) && !selectedItems.isEmpty ? selectedItems : [item]
    }

    private var contextDeleteTitle: String {
        let count = contextDeleteTargets.count
        return count > 1 ? "删除 \(count) 个项目" : "删除"
    }

    @ViewBuilder
    private var leadingVisual: some View {
        if item.type == .image,
           let url = store.fileURL(for: item),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                )
        } else {
            PortalIcon(glyph: itemGlyph, size: 42, tint: iconTint)
                .accessibilityHidden(true)
        }
    }

    private var iconTint: Color {
        PortalTokens.Palette.icon
    }

    private var itemGlyph: PortalGlyph {
        switch item.type {
        case .text: return .text
        case .url: return .link
        case .image: return .image
        case .file: return .file
        }
    }
}
