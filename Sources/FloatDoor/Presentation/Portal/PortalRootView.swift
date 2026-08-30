import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PortalRootView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject var store: PortalStore
    @ObservedObject var panelController: NotchPanelController
    let dropImporter: DropImporter
    let itemProviderFactory: PortalItemProviderFactory

    @State private var primarySection: PortalSection = .temporary
    @State private var isTemporaryDropTarget = false
    @State private var isPermanentDropTarget = false
    @State private var isTemporaryTabDropTarget = false
    @State private var isPermanentTabDropTarget = false
    @State private var isCustomDropTarget = false
    @State private var isCollapsedDropTarget = false
    @StateObject private var itemSelection = PortalItemSelection()

    var body: some View {
        ZStack(alignment: .top) {
            expandedBody
                .frame(
                    width: NotchPanelController.expandedSize.width,
                    height: NotchPanelController.expandedSize.height,
                    alignment: .top
                )
                .background(panelSurface)
                .overlay(
                    NotchShape(cornerRadius: 42)
                        .stroke(.white.opacity(0.07), lineWidth: 1)
                        .allowsHitTesting(false)
                )
                .clipShape(NotchShape(cornerRadius: 42))
                .opacity(panelController.isExpanded ? 1 : 0)
                .allowsHitTesting(panelController.isExpanded)
                .accessibilityHidden(!panelController.isExpanded)

            collapsedBody
                .frame(
                    width: panelController.collapsedSurfaceSize.width,
                    height: panelController.collapsedSurfaceSize.height,
                    alignment: .top
                )
                .background(panelSurface)
                .overlay(
                    NotchShape(cornerRadius: 8)
                        .stroke(.white.opacity(0.055), lineWidth: 1)
                        .allowsHitTesting(false)
                )
                .clipShape(NotchShape(cornerRadius: 8))
                // The collapsed window remains as a transparent hover/drop
                // target around the physical notch, but has no visible handle.
                // The expanded panel therefore finishes by disappearing into
                // the notch instead of flashing a second compact surface.
                .opacity(0)
                .allowsHitTesting(!panelController.isExpanded)
                .accessibilityHidden(panelController.isExpanded)
        }
        .frame(
            width: panelController.currentWindowSize.width,
            height: panelController.currentWindowSize.height
        )
        .onChange(of: panelController.dragHoveredDestination) { _, destination in
            guard let destination else { return }
            selectSection(destination.section)
        }
        .onChange(of: store.items.map(\.id)) { _, _ in
            itemSelection.retainExistingItems(store.items)
        }
        .environment(\.colorScheme, .dark)
    }

    private var panelSurface: some View {
        ZStack {
            if reduceTransparency {
                Rectangle().fill(PortalTokens.Palette.canvas)
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }

            PortalTokens.Palette.canvas.opacity(panelController.isExpanded ? 0.96 : 0.99)

            LinearGradient(
                colors: [
                    Color.white.opacity(panelController.isExpanded ? 0.035 : 0.018),
                    Color.clear,
                    Color.black.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var collapsedBody: some View {
        Button {
            panelController.show()
        } label: {
            HStack(spacing: 8) {
                PortalIcon(glyph: .door, size: 16, tint: PortalTokens.Palette.accent, showsPlate: false)
                    .accessibilityHidden(true)

                Capsule()
                    .fill(.white.opacity(0.22))
                    .frame(width: 1, height: 14)

                Text("Float Door")
                    .font(PortalTokens.Typography.bodyStrong)
                    .foregroundStyle(PortalTokens.Palette.primaryText)

                Text("\(store.totalItemCount)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(PortalTokens.Palette.accent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .overlay {
            if isCollapsedDropTarget {
                Capsule()
                    .strokeBorder(Color.portalAccent.opacity(0.82), lineWidth: 1.5)
                    .padding(1)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(
            of: DropImporter.acceptedTypes,
            delegate: ScopeDropDelegate(
                isTargeted: $isCollapsedDropTarget,
                onTargeted: { panelController.draggingEnteredPanel() },
                onDrop: { providers in
                    acceptDrop(providers, into: primarySection)
                }
            )
        )
        .accessibilityLabel("打开 Float Door")
    }

    private var expandedBody: some View {
        VStack(spacing: 13) {
            header
            scopeSwitcher

            Group {
                if primarySection == .temporary {
                    temporaryContent
                } else {
                    permanentContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let notice = store.notice {
                NoticeBanner(notice: notice) {
                    store.dismissNotice()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(spacing: 12) {
            PortalIcon(glyph: .door, size: 38, tint: PortalTokens.Palette.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Float Door")
                    .font(PortalTokens.Typography.display)
                    .foregroundStyle(PortalTokens.Palette.primaryText)
                Text("拖入保存 · 拖出使用")
                    .font(PortalTokens.Typography.body)
                    .foregroundStyle(PortalTokens.Palette.secondaryText)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                CountChip(
                    count: store.temporaryItems.count,
                    label: "一次性",
                    tint: .orange
                )
                CountChip(
                    count: store.permanentItems.count + store.customItems.count,
                    label: "长期",
                    tint: Color.portalAccent
                )
            }

            PortalIconButton(
                glyph: .collapse,
                size: 28,
                helpText: "收起",
                label: "收起 Float Door",
                action: panelController.collapse
            )
        }
    }

    private var scopeSwitcher: some View {
        HStack(spacing: 4) {
            scopeButton(
                for: .temporary,
                count: store.temporaryItems.count,
                isDropTarget: $isTemporaryTabDropTarget
            )
            scopeButton(
                for: .permanent,
                count: store.permanentItems.count + store.customItems.count,
                isDropTarget: $isPermanentTabDropTarget
            )
        }
        .padding(4)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func scopeButton(
        for section: PortalSection,
        count: Int,
        isDropTarget: Binding<Bool>
    ) -> some View {
        let isSelected = primarySection == section
        let isAppKitDropTarget = panelController.dragHoveredDestination?.isTab == true
            && panelController.dragHoveredDestination?.section == section

        return Button {
            selectSection(section)
        } label: {
            HStack(spacing: 8) {
                PortalIcon(
                    glyph: section == .temporary ? .temporary : .permanent,
                    size: PortalTokens.Icon.section,
                    tint: isSelected ? PortalTokens.Palette.accent : PortalTokens.Palette.icon,
                    showsPlate: false
                )
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(section.title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(section.subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(isSelected ? 0.54 : 0.38))
                }
                Spacer(minLength: 4)
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .white.opacity(0.48))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.58))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Color.white.opacity(0.15) : Color.clear,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(
                        (isDropTarget.wrappedValue || isAppKitDropTarget)
                            ? Color.portalAccent.opacity(0.86)
                            : (isSelected ? .white.opacity(0.12) : .clear),
                        lineWidth: (isDropTarget.wrappedValue || isAppKitDropTarget) ? 1.5 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .onDrop(
            of: DropImporter.acceptedTypes,
            delegate: ScopeDropDelegate(
                isTargeted: isDropTarget,
                onTargeted: { selectSection(section) },
                onDrop: { providers in acceptDrop(providers, into: section) }
            )
        )
        .accessibilityHint("将内容拖到此处可直接保存到\(section.title)区域")
    }

    private var temporaryContent: some View {
        itemArea(
            items: store.temporaryItems,
            emptyTitle: "拖入当前任务需要的内容",
            emptyDetail: "文字、图片、链接和文件会暂存于此，默认 24 小时后自动清理。",
            usesCompositeEmptyIcon: true,
            dropMessage: "松开放入一次性区域",
            isDropTarget: $isTemporaryDropTarget,
            appKitDestination: .temporaryArea
        ) { providers in
            dropImporter.importProviders(providers, into: .temporary)
        }
    }

    private var permanentContent: some View {
        HStack(alignment: .top, spacing: 10) {
            permanentMaterialsPane
            customAreaPane
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permanentMaterialsPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            paneTitle(
                glyph: .permanent,
                title: store.materialAreaName,
                detail: "文件 · 图片 · 文本 · 链接",
                tint: Color.portalAccent,
                onCreate: {
                    panelController.presentNewMaterialEditor(source: "material-area-button", scope: .permanent)
                },
                onRename: {
                    panelController.presentAreaRenameEditor(scope: .permanent)
                }
            )

            itemArea(
                items: store.permanentItems,
                emptyTitle: "保存需要反复使用的内容",
                emptyDetail: "拖入这里即可长期保留，不会自动过期。",
                emptyGlyph: .permanent,
                dropMessage: "松开，直接长期保存",
                isDropTarget: $isPermanentDropTarget,
                appKitDestination: .permanentArea
            ) { providers in
                dropImporter.importProviders(providers, into: .permanent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var customAreaPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            paneTitle(
                glyph: .file,
                title: store.customAreaName,
                detail: "文件 · 图片 · 文本 · 链接",
                tint: PortalTokens.Palette.icon,
                onCreate: {
                    panelController.presentNewMaterialEditor(source: "custom-area-button", scope: .custom)
                },
                onRename: {
                    panelController.presentAreaRenameEditor(scope: .custom)
                }
            )

            itemArea(
                items: store.customItems,
                emptyTitle: "\(store.customAreaName) 空间",
                emptyDetail: "拖入即可保存并复用",
                emptyGlyph: .file,
                dropMessage: "松开放入\(store.customAreaName)空间",
                isDropTarget: $isCustomDropTarget,
                appKitDestination: .customArea
            ) { providers in
                dropImporter.importProviders(providers, into: .custom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func paneTitle(
        glyph: PortalGlyph,
        title: String,
        detail: String,
        tint: Color,
        onCreate: (() -> Void)? = nil,
        onRename: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 8) {
            PortalIcon(glyph: glyph, size: 28, tint: tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer(minLength: 4)

            if let onCreate {
                Button(action: onCreate) {
                    HStack(spacing: 4) {
                        PortalIcon(glyph: .add, size: 15, showsPlate: false)
                            .accessibilityHidden(true)
                        Text("新建素材")
                    }
                }
                .buttonStyle(GlassTextButtonStyle())
                .fixedSize()
                .help("在\(title)区域新建内容")
                .accessibilityLabel("在\(title)区域新建内容")
            }

            if let onRename {
                PortalIconButton(
                    glyph: .rename,
                    size: 20,
                    helpText: "重命名区域",
                    label: "重命名\(title)区域",
                    action: onRename
                )
                .frame(width: 20, height: 20)
            }
        }
    }

    @ViewBuilder
    private func itemArea(
        items: [PortalItem],
        emptyTitle: String,
        emptyDetail: String,
        usesCompositeEmptyIcon: Bool = false,
        emptyGlyph: PortalGlyph = .tray,
        dropMessage: String,
        isDropTarget: Binding<Bool>,
        appKitDestination: PortalDropDestination,
        onDrop: @escaping ([NSItemProvider]) -> Void
    ) -> some View {
        let isAppKitDropTarget = panelController.dragHoveredDestination == appKitDestination
        let isActiveDropTarget = isDropTarget.wrappedValue || isAppKitDropTarget

        ZStack {
            if items.isEmpty {
                emptyState(
                    title: emptyTitle,
                    detail: emptyDetail,
                    isDropTarget: isActiveDropTarget,
                    usesCompositeIcon: usesCompositeEmptyIcon,
                    glyph: emptyGlyph
                )
            } else {
                SlimScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(items) { item in
                            PortalItemCard(
                                item: item,
                                store: store,
                                panelController: panelController,
                                itemProviderFactory: itemProviderFactory,
                                selection: itemSelection,
                                orderedItems: items,
                                draggableItems: draggableItems
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if isActiveDropTarget {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.portalAccent.opacity(0.15))
                    .overlay(
                        VStack(spacing: 8) {
                            PortalIcon(glyph: .download, size: 34, tint: PortalTokens.Palette.accent, showsPlate: false)
                                .accessibilityHidden(true)
                            Text(dropMessage)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Color.portalAccent)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(Color.portalAccent.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    )
                    .padding(2)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
        .background(PortalTokens.Palette.glass, in: RoundedRectangle(cornerRadius: PortalTokens.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .onTapGesture {
            itemSelection.clear()
        }
        .onDrop(of: DropImporter.acceptedTypes, isTargeted: isDropTarget) { providers in
            onDrop(providers)
            return true
        }
    }

    private var draggableItems: [PortalItem] {
        switch primarySection {
        case .temporary:
            return store.temporaryItems
        case .permanent:
            return store.permanentItems + store.customItems
        }
    }

    private func emptyState(
        title: String,
        detail: String,
        isDropTarget: Bool,
        usesCompositeIcon: Bool,
        glyph: PortalGlyph
    ) -> some View {
        VStack(alignment: .center, spacing: 10) {
            if usesCompositeIcon {
                PortalDropCompositionIcon(isDropTarget: isDropTarget)
                    .accessibilityHidden(true)
                    .padding(.bottom, 16)
            } else {
                PortalIcon(
                    glyph: isDropTarget ? .download : glyph,
                    size: PortalTokens.Icon.hero,
                    tint: isDropTarget ? PortalTokens.Palette.accent : PortalTokens.Palette.icon
                )
                .accessibilityHidden(true)
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.84))
            Text(detail)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.white.opacity(0.46))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 230)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func acceptDrop(_ providers: [NSItemProvider], into section: PortalSection) -> Bool {
        selectSection(section)

        dropImporter.importProviders(providers, into: section.storageScope)
        return true
    }

    private func selectSection(_ section: PortalSection) {
        panelController.setActiveSection(section)
        guard primarySection != section else { return }
        itemSelection.clear()
        withAnimation(.easeOut(duration: 0.2)) {
            primarySection = section
        }
    }
}

private struct NotchShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, rect.width / 2, rect.height)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}
