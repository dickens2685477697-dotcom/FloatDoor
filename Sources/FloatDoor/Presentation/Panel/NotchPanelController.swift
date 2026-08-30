import AppKit
import Combine
import OSLog
import SwiftUI

@MainActor
final class NotchPanelController: NSObject, ObservableObject {
    private static let logger = Logger(subsystem: "FloatDoor", category: "NewMaterial")
    private static let expandedHeightScale: CGFloat = 0.8
    private static let transitionDuration = 0.2
    private static let collapsedContentScale: CGFloat = 0.12
    private static let fallbackNotchSize = NSSize(width: 180, height: 32)
    private static let dragHalo = NSSize(width: 44, height: 12)
    static let expandedSize = NSSize(width: 720, height: 540 * expandedHeightScale)

    @Published private(set) var isExpanded = false
    @Published private(set) var collapsedSurfaceSize = fallbackNotchSize
    @Published private(set) var activeSection: PortalSection = .temporary
    @Published private(set) var dragHoveredDestination: PortalDropDestination?

    var collapsedWindowSize: NSSize {
        NSSize(
            width: collapsedSurfaceSize.width + Self.dragHalo.width,
            height: collapsedSurfaceSize.height + Self.dragHalo.height
        )
    }

    var currentWindowSize: NSSize {
        isExpanded ? Self.expandedSize : collapsedWindowSize
    }

    private let store: PortalStore
    private let dropImporter: DropImporter
    private let clipboardImporter: ClipboardImporter
    private let itemProviderFactory: PortalItemProviderFactory
    private var panel: NotchPanel?
    private var hostingView: TrackingContainerView?
    private var hostingController: NSViewController?
    private var collapseWorkItem: DispatchWorkItem?
    private var isKeepingExpandedForModal = false
    private var transientInteractionCount = 0
    private var globalDragMonitor: Any?
    private var localDragMonitor: Any?
    private var globalOutsideClickMonitor: Any?
    private var localOutsideClickMonitor: Any?
    private var localPasteMonitor: Any?
    private var localCopyMonitor: Any?
    private var copyHoveredItemID: UUID?
    private var newMaterialSheet: NSWindow?
    private var areaRenameSheet: NSWindow?
    private var transitionGeneration = 0
    private var isTransitioning = false

    init(store: PortalStore) {
        self.store = store
        self.dropImporter = DropImporter(store: store)
        self.clipboardImporter = ClipboardImporter(store: store)
        self.itemProviderFactory = PortalItemProviderFactory(store: store)
        super.init()
    }

    func install() {
        guard panel == nil else { return }

        let panel = NotchPanel(contentRect: .zero)
        panel.appearance = NSAppearance(named: .darkAqua)

        let rootView = PortalRootView(
            store: store,
            panelController: self,
            dropImporter: dropImporter,
            itemProviderFactory: itemProviderFactory
        )
        let swiftUIController = NSHostingController(rootView: rootView)
        let hostingView = TrackingContainerView()
        hostingView.panelController = self
        hostingView.activeSection = activeSection
        hostingView.onDragHoverDestinationChanged = { [weak self] destination in
            self?.setDragHoveredDestination(destination)
        }
        hostingView.onDragDrop = { [weak self] destination, pasteboard in
            self?.performAppKitDrop(destination, pasteboard: pasteboard) ?? false
        }
        hostingView.registerForDraggedTypes(DropImporter.acceptedTypes.map { NSPasteboard.PasteboardType($0.identifier) })
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        // The outer controller owns hover/drop handling, while the child
        // NSHostingController supplies SwiftUI's presentation context. This
        // lets `.sheet` work without casting SwiftUI's private _NSHostingView.
        let hostingController = NSViewController()
        hostingController.view = hostingView
        hostingController.addChild(swiftUIController)
        hostingView.embed(swiftUIController.view)
        hostingView.installActionHotspots(
            createMaterial: { [weak self] in
                self?.presentNewMaterialEditor(source: "native-material-hotspot", scope: .permanent)
            },
            renameMaterialArea: { [weak self] in
                self?.presentAreaRenameEditor(scope: .permanent)
            },
            createCustomMaterial: { [weak self] in
                self?.presentNewMaterialEditor(source: "native-custom-hotspot", scope: .custom)
            },
            renameCustomArea: { [weak self] in
                self?.presentAreaRenameEditor(scope: .custom)
            }
        )
        panel.contentViewController = hostingController

        self.panel = panel
        self.hostingView = hostingView
        self.hostingController = hostingController
        updateFrame()
        panel.orderFrontRegardless()
        installDragMonitors()
        installOutsideClickMonitors()
        installPasteMonitor()
        installCopyMonitor()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reposition),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: NSApp
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )
    }

    func show() {
        setExpanded(true)
    }

    func toggle() {
        setExpanded(!isExpanded)
    }

    func collapse() {
        setExpanded(false)
    }

    func beginModalInteraction() {
        collapseWorkItem?.cancel()
        isKeepingExpandedForModal = true
        // Lower the always-interactive panel while modal content is presented
        // so the attached sheet remains visually in front.
        panel?.level = .modalPanel
        setExpanded(true)
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

    func endModalInteraction() {
        isKeepingExpandedForModal = false
        panel?.level = .statusBar
        collapse()
    }

    func beginTransientInteraction() {
        collapseWorkItem?.cancel()
        transientInteractionCount += 1
    }

    func endTransientInteraction() {
        transientInteractionCount = max(0, transientInteractionCount - 1)
        guard transientInteractionCount == 0 else { return }
        if let panel, panel.frame.contains(NSEvent.mouseLocation) {
            collapseWorkItem?.cancel()
            return
        }
        pointerExited()
    }

    func presentNewMaterialEditor(source: String = "panel-button", scope: StorageScope = .permanent) {
        Self.logger.notice("Presentation requested from \(source, privacy: .public)")
        guard let panel else {
            Self.logger.error("Presentation aborted because the panel is not installed")
            return
        }

        if let newMaterialSheet {
            newMaterialSheet.makeKeyAndOrderFront(nil)
            return
        }

        beginModalInteraction()

        let sheet = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 270),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        sheet.title = "新建\(scope == .custom ? store.customAreaName : store.materialAreaName)"
        sheet.titleVisibility = .hidden
        sheet.titlebarAppearsTransparent = true
        sheet.isMovable = false
        sheet.isReleasedWhenClosed = false
        sheet.backgroundColor = .clear
        sheet.appearance = NSAppearance(named: .darkAqua)
        sheet.contentViewController = NSHostingController(
            rootView: NewMaterialSheet(store: store, scope: scope) { [weak self] in
                self?.dismissNewMaterialEditor()
            }
        )

        newMaterialSheet = sheet
        panel.beginSheet(sheet) { [weak self, weak sheet] _ in
            guard let self, self.newMaterialSheet === sheet else { return }
            self.newMaterialSheet = nil
            self.endModalInteraction()
        }
        Self.logger.notice("Native sheet attached: \(panel.attachedSheet === sheet, privacy: .public)")
    }

    private func dismissNewMaterialEditor() {
        guard let panel, let newMaterialSheet else { return }
        panel.endSheet(newMaterialSheet)
    }

    func presentAreaRenameEditor(scope: StorageScope) {
        guard let panel else { return }
        if let areaRenameSheet {
            areaRenameSheet.makeKeyAndOrderFront(nil)
            return
        }

        let originalName = scope == .custom ? store.customAreaName : store.materialAreaName
        beginModalInteraction()

        let sheet = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 160),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        sheet.titleVisibility = .hidden
        sheet.titlebarAppearsTransparent = true
        sheet.isMovable = false
        sheet.isReleasedWhenClosed = false
        sheet.backgroundColor = .clear
        sheet.appearance = NSAppearance(named: .darkAqua)
        sheet.contentViewController = NSHostingController(
            rootView: AreaRenameEditor(
                originalName: originalName,
                onCancel: { [weak self] in self?.dismissAreaRenameEditor() },
                onSave: { [weak self] name in
                    guard let self else { return }
                    if scope == .custom {
                        self.store.renameCustomArea(to: name)
                    } else {
                        self.store.renameMaterialArea(to: name)
                    }
                    self.dismissAreaRenameEditor()
                }
            )
        )

        areaRenameSheet = sheet
        panel.beginSheet(sheet) { [weak self, weak sheet] _ in
            guard let self, self.areaRenameSheet === sheet else { return }
            self.areaRenameSheet = nil
            self.endModalInteraction()
        }
    }

    private func dismissAreaRenameEditor() {
        guard let panel, let areaRenameSheet else { return }
        panel.endSheet(areaRenameSheet)
    }

    func pointerEntered() {
        collapseWorkItem?.cancel()
        setExpanded(true)
    }

    func pointerExited() {
        guard isExpanded, !keepsPanelExpanded else { return }
        collapseWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.setExpanded(false)
        }
        collapseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: workItem)
    }

    func draggingEnteredPanel() {
        collapseWorkItem?.cancel()
        // Resizing a drag destination from inside AppKit's drag callback can
        // invalidate the current destination. Expand on the next run-loop pass
        // so the drag session remains attached to the panel.
        guard !isExpanded else { return }
        DispatchQueue.main.async { [weak self] in
            self?.setExpanded(true)
        }
    }

    func setActiveSection(_ section: PortalSection) {
        activeSection = section
        hostingView?.activeSection = section
    }

    func setDragHoveredDestination(_ destination: PortalDropDestination?) {
        if let destination, destination.isTab {
            setActiveSection(destination.section)
        }
        guard dragHoveredDestination != destination else { return }
        dragHoveredDestination = destination
    }

    func setCopyHoveredItem(_ itemID: UUID, isHovered: Bool) {
        if isHovered {
            copyHoveredItemID = itemID
        } else if copyHoveredItemID == itemID {
            copyHoveredItemID = nil
        }
    }

    private func performAppKitDrop(
        _ destination: PortalDropDestination,
        pasteboard: NSPasteboard
    ) -> Bool {
        setDragHoveredDestination(nil)
        dropImporter.importPasteboard(pasteboard, into: destination.storageScope)
        return true
    }

    @objc
    private func reposition() {
        updateFrame()
    }

    @objc
    private func applicationDidResignActive() {
        guard isExpanded, !keepsPanelExpanded else { return }
        collapse()
    }

    @objc
    private func panelDidResignKey() {
        guard isExpanded, !keepsPanelExpanded else { return }
        collapse()
    }

    private func setExpanded(_ expanded: Bool) {
        collapseWorkItem?.cancel()
        if !expanded {
            setDragHoveredDestination(nil)
            copyHoveredItemID = nil
        }
        guard isExpanded != expanded || isTransitioning else {
            if expanded {
                NSApp.activate(ignoringOtherApps: true)
                panel?.makeKeyAndOrderFront(nil)
            } else {
                panel?.orderFrontRegardless()
            }
            return
        }
        if expanded {
            NSApp.activate(ignoringOtherApps: true)
            panel?.makeKeyAndOrderFront(nil)
            animateExpansion()
        } else {
            panel?.orderFrontRegardless()
            animateCollapse()
        }
    }

    private func animateExpansion() {
        guard let hostingView else { return }
        transitionGeneration += 1
        let generation = transitionGeneration
        isTransitioning = true

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard !reduceMotion else {
            isExpanded = true
            updateFrame()
            hostingView.layoutSubtreeIfNeeded()
            resetContentPresentation()
            isTransitioning = false
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hostingView.layer?.removeAllAnimations()
        hostingView.layer?.setAffineTransform(.identity)
        hostingView.layer?.opacity = 0
        hostingView.resetScaleAnchor()
        CATransaction.commit()

        // Hide the root layer before replacing the collapsed hierarchy and
        // resizing the window. Otherwise the expanded panel can be displayed
        // for one frame before its initial opacity reaches zero.
        isExpanded = true
        updateFrame()
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()

        // Commit the hidden expanded hierarchy to the render server first.
        // Starting the explicit animation on the next run-loop turn prevents
        // Core Animation from coalescing the 0 -> 1 opacity change.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.transitionGeneration == generation,
                  let layer = self.hostingView?.layer else { return }

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = Self.transitionDuration
            fade.timingFunction = CAMediaTimingFunction(name: .linear)

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            CATransaction.setCompletionBlock { [weak self] in
                DispatchQueue.main.async {
                    guard let self, self.transitionGeneration == generation else { return }
                    self.resetContentPresentation()
                    self.isTransitioning = false
                }
            }
            layer.opacity = 1
            layer.add(fade, forKey: "notch-fade-in")
            CATransaction.commit()
        }
    }

    private func animateCollapse() {
        guard hostingView != nil else { return }
        transitionGeneration += 1
        let generation = transitionGeneration
        isTransitioning = true

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard !reduceMotion else {
            isExpanded = false
            updateFrame()
            hostingView?.layoutSubtreeIfNeeded()
            resetContentPresentation()
            isTransitioning = false
            return
        }

        // Keep the expanded hierarchy at its full layout size for the whole
        // transition. Resizing it first makes SwiftUI reflow image/list cells
        // while the old window is still visible, producing stray snapshots.
        hostingView?.prepareForTopAnchoredScale()
        hostingView?.layer?.removeAllAnimations()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.transitionGeneration == generation else { return }
                self.isExpanded = false
                self.updateFrame()
                self.hostingView?.layoutSubtreeIfNeeded()
                // Give SwiftUI one display turn to replace the expanded tree
                // while the container is still transparent. Revealing it in
                // the same transaction can flash the final expanded frame.
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.transitionGeneration == generation else { return }
                    self.resetContentPresentation()
                    self.isTransitioning = false
                }
            }
        }
        hostingView?.layer?.add(makeNotchCollapseAnimation(), forKey: "notch-collapse")
        hostingView?.layer?.setAffineTransform(
            CGAffineTransform(scaleX: Self.collapsedContentScale, y: Self.collapsedContentScale)
        )
        hostingView?.layer?.opacity = 0
        CATransaction.commit()
    }

    private func makeNotchCollapseAnimation() -> CAAnimationGroup {
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1
        scale.toValue = Self.collapsedContentScale
        scale.duration = Self.transitionDuration
        scale.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 1
        opacity.toValue = 0
        opacity.duration = Self.transitionDuration
        // Opacity must not inherit the scale easing. A linear timing function
        // keeps the fade rate constant from the first frame to the last.
        opacity.timingFunction = CAMediaTimingFunction(name: .linear)

        let group = CAAnimationGroup()
        group.animations = [scale, opacity]
        group.duration = Self.transitionDuration
        group.isRemovedOnCompletion = true
        return group
    }

    private func resetContentPresentation() {
        guard let hostingView else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hostingView.layer?.removeAllAnimations()
        hostingView.layer?.setAffineTransform(.identity)
        hostingView.layer?.opacity = 1
        hostingView.resetScaleAnchor()
        CATransaction.commit()
    }

    private func installDragMonitors() {
        guard globalDragMonitor == nil, localDragMonitor == nil else { return }

        globalDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
            Task { @MainActor in
                self?.expandWhenDraggingNearNotch()
            }
        }

        localDragMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            Task { @MainActor in
                self?.expandWhenDraggingNearNotch()
            }
            return event
        }
    }

    private func installOutsideClickMonitors() {
        guard globalOutsideClickMonitor == nil, localOutsideClickMonitor == nil else { return }

        let mouseDownEvents: NSEvent.EventTypeMask = [
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown
        ]

        globalOutsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseDownEvents) { [weak self] event in
            // Events delivered by a global monitor have no app-owned window;
            // AppKit reports their location directly in screen coordinates.
            let screenPoint = event.locationInWindow
            Task { @MainActor in
                self?.collapseIfClickIsOutsidePanel(at: screenPoint)
            }
        }

        localOutsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseDownEvents) { [weak self] event in
            let screenPoint = event.window?.convertPoint(toScreen: event.locationInWindow)
                ?? event.locationInWindow
            self?.collapseIfClickIsOutsidePanel(at: screenPoint)
            return event
        }
    }

    private func collapseIfClickIsOutsidePanel(at screenPoint: NSPoint) {
        guard isExpanded,
              !keepsPanelExpanded,
              let panel,
              !panel.frame.contains(screenPoint) else { return }
        collapse()
    }

    private var keepsPanelExpanded: Bool {
        isKeepingExpandedForModal || transientInteractionCount > 0
    }

    private func installPasteMonitor() {
        guard localPasteMonitor == nil else { return }

        localPasteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handlePasteShortcut(event) ? nil : event
        }
    }

    private func installCopyMonitor() {
        guard localCopyMonitor == nil else { return }

        localCopyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleCopyShortcut(event) ? nil : event
        }
    }

    private func handleCopyShortcut(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.command),
              modifiers.isDisjoint(with: [.control, .option, .shift]),
              event.charactersIgnoringModifiers?.lowercased() == "c",
              isExpanded,
              let panel,
              panel.isKeyWindow,
              panel.attachedSheet == nil,
              !(panel.firstResponder is NSTextView),
              let itemID = copyHoveredItemID,
              let item = store.items.first(where: { $0.id == itemID }) else {
            return false
        }

        let writers = itemProviderFactory.pasteboardWriters(for: [item])
        guard !writers.isEmpty else { return false }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects(writers)
    }

    private func handlePasteShortcut(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.command),
              modifiers.isDisjoint(with: [.control, .option, .shift]),
              event.charactersIgnoringModifiers?.lowercased() == "v",
              isExpanded,
              let panel,
              panel.isKeyWindow,
              panel.attachedSheet == nil,
              let hostingView else {
            return false
        }

        let windowPoint = panel.mouseLocationOutsideOfEventStream
        guard let destination = hostingView.destination(atWindowPoint: windowPoint),
              !destination.isTab else {
            return false
        }

        clipboardImporter.importCurrentContents(into: destination.storageScope)
        return true
    }

    private func expandWhenDraggingNearNotch() {
        guard !isExpanded else { return }
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) else { return }

        let notchSize = measuredNotchSize(for: screen)
        // The physical camera housing has no drawable pixels and therefore
        // cannot be an AppKit drag destination. Observe cross-app mouse drags
        // and use a small invisible band around it as the activation target.
        let activationRect = NSRect(
            x: screen.frame.midX - (notchSize.width + 80) / 2,
            y: screen.frame.maxY - notchSize.height - 20,
            width: notchSize.width + 80,
            height: notchSize.height + 20
        )
        guard activationRect.contains(pointer) else { return }
        draggingEnteredPanel()
    }

    private func updateFrame() {
        guard let panel else { return }
        let targetScreen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
        updateNotchSize(for: targetScreen)
        let size = currentWindowSize
        hostingView?.frame = NSRect(origin: .zero, size: size)
        let frame = frame(for: size, on: targetScreen)

        panel.setFrame(frame, display: true)
    }

    private func updateNotchSize(for screen: NSScreen?) {
        let measuredSize = screen.map(measuredNotchSize(for:)) ?? Self.fallbackNotchSize
        if collapsedSurfaceSize != measuredSize {
            collapsedSurfaceSize = measuredSize
        }
    }

    private func measuredNotchSize(for screen: NSScreen) -> NSSize {
        guard screen.safeAreaInsets.top > 0,
              let leftArea = screen.auxiliaryTopLeftArea,
              let rightArea = screen.auxiliaryTopRightArea else {
            return Self.fallbackNotchSize
        }

        let measuredWidth = rightArea.minX - leftArea.maxX
        guard measuredWidth > 0 else { return Self.fallbackNotchSize }

        // AppKit reports screen geometry in points, so this matches the
        // physical camera housing at the current display scale.
        return NSSize(width: measuredWidth, height: screen.safeAreaInsets.top)
    }

    private func frame(for size: NSSize, on screen: NSScreen?) -> NSRect {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen else {
            return NSRect(origin: .zero, size: size)
        }

        // This anchors to the physical top centre. On notched displays it
        // visually occupies the notch region; on other displays it is the
        // documented top-centre fallback.
        return NSRect(
            x: targetScreen.frame.midX - size.width / 2,
            y: targetScreen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}

final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = false
        // Any window or SwiftUI shadow is clipped by the transparent panel's
        // rectangular bounds and shows up as dark corner blocks.
        hasShadow = false
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class TrackingContainerView: NSView {
    weak var panelController: NotchPanelController?
    var activeSection: PortalSection = .temporary
    var onDragHoverDestinationChanged: ((PortalDropDestination?) -> Void)?
    var onDragDrop: ((PortalDropDestination, NSPasteboard) -> Bool)?
    private var hoverTrackingArea: NSTrackingArea?
    private var actionHotspots: [NSButton] = []
    private var createMaterialAction: (() -> Void)?
    private var renameMaterialAreaAction: (() -> Void)?
    private var createCustomMaterialAction: (() -> Void)?
    private var renameCustomAreaAction: (() -> Void)?
    private var lastDragHoverDestination: PortalDropDestination?

    func prepareForTopAnchoredScale() {
        guard let layer else { return }
        let frame = layer.frame
        layer.anchorPoint = CGPoint(x: 0.5, y: 1)
        layer.position = CGPoint(x: frame.midX, y: frame.maxY)
    }

    func resetScaleAnchor() {
        guard let layer else { return }
        let frame = layer.frame
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: frame.midX, y: frame.midY)
    }

    func embed(_ contentView: NSView) {
        contentView.frame = bounds
        contentView.autoresizingMask = [.width, .height]
        addSubview(contentView)
    }

    func installActionHotspots(
        createMaterial: @escaping () -> Void,
        renameMaterialArea: @escaping () -> Void,
        createCustomMaterial: @escaping () -> Void,
        renameCustomArea: @escaping () -> Void
    ) {
        guard actionHotspots.isEmpty else { return }
        createMaterialAction = createMaterial
        renameMaterialAreaAction = renameMaterialArea
        createCustomMaterialAction = createCustomMaterial
        renameCustomAreaAction = renameCustomArea
        actionHotspots = [
            makeHotspot(action: #selector(handleCreateMaterial)),
            makeHotspot(action: #selector(handleRenameMaterialArea)),
            makeHotspot(action: #selector(handleCreateCustomMaterial)),
            makeHotspot(action: #selector(handleRenameCustomArea))
        ]
        actionHotspots.forEach(addSubview)
        needsLayout = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // SwiftUI's nested permanent-pane ScrollView can return its hosting
        // view before consulting embedded NSViewRepresentable controls. Route
        // card actions by their real, converted frames so the visible control
        // receives the first mouse even when an intermediate SwiftUI wrapper
        // opts out of hit testing.
        if let cardControl = firstVisibleCardControl(at: point, in: self) {
            return cardControl
        }
        return super.hitTest(point)
    }

    private func firstVisibleCardControl(at point: NSPoint, in root: NSView) -> NSView? {
        for subview in root.subviews.reversed() {
            if let match = firstVisibleCardControl(at: point, in: subview) {
                return match
            }
        }

        guard root is FirstMouseCardActionButton || root is FirstMouseCardMenuButton,
              isVisible(root, at: point) else {
            return nil
        }
        return root
    }

    private func isVisible(_ target: NSView, at containerPoint: NSPoint) -> Bool {
        var current: NSView? = target
        while let view = current, view !== self {
            guard !view.isHidden,
                  view.alphaValue > 0.01,
                  view.bounds.contains(view.convert(containerPoint, from: self)) else {
                return false
            }
            current = view.superview
        }
        return current === self
    }

    override func layout() {
        super.layout()
        guard actionHotspots.count == 4 else { return }
        let isExpanded = bounds.width >= 700 && bounds.height >= 400
        actionHotspots.forEach { $0.isHidden = !isExpanded }
        guard isExpanded else { return }

        // The panel is a fixed 720 x 432 surface. These rectangles mirror the
        // trailing header controls in the two equal-width permanent panes.
        actionHotspots[0].frame = NSRect(x: 250, y: 269, width: 77, height: 27)
        actionHotspots[1].frame = NSRect(x: 335, y: 272, width: 20, height: 20)
        actionHotspots[2].frame = NSRect(x: 597, y: 269, width: 77, height: 27)
        actionHotspots[3].frame = NSRect(x: 682, y: 272, width: 20, height: 20)
    }

    private func makeHotspot(action: Selector) -> NSButton {
        let button = FirstMouseHotspotButton()
        button.title = ""
        button.isBordered = false
        button.focusRingType = .none
        button.refusesFirstResponder = true
        button.target = self
        button.action = action
        return button
    }

    @objc private func handleCreateMaterial() {
        createMaterialAction?()
    }

    @objc private func handleRenameMaterialArea() {
        renameMaterialAreaAction?()
    }

    @objc private func handleCreateCustomMaterial() {
        createCustomMaterialAction?()
    }

    @objc private func handleRenameCustomArea() {
        renameCustomAreaAction?()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        panelController?.pointerEntered()
    }

    override func mouseExited(with event: NSEvent) {
        panelController?.pointerExited()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        panelController?.draggingEnteredPanel()
        updateDragHoverDestination(for: sender)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        panelController?.draggingEnteredPanel()
        updateDragHoverDestination(for: sender)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        clearDragHoverDestination()
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        clearDragHoverDestination()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        destination(atWindowPoint: sender.draggingLocation) != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let destination = destination(atWindowPoint: sender.draggingLocation) else {
            clearDragHoverDestination()
            return false
        }

        let accepted = onDragDrop?(destination, sender.draggingPasteboard) ?? false
        clearDragHoverDestination()
        return accepted
    }

    override func wantsPeriodicDraggingUpdates() -> Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    private func updateDragHoverDestination(for info: NSDraggingInfo) {
        let destination = destination(atWindowPoint: info.draggingLocation)
        guard destination != lastDragHoverDestination else { return }
        lastDragHoverDestination = destination
        onDragHoverDestinationChanged?(destination)
    }

    private func clearDragHoverDestination() {
        guard lastDragHoverDestination != nil else { return }
        lastDragHoverDestination = nil
        onDragHoverDestinationChanged?(nil)
    }

    /// `NSDraggingInfo.draggingLocation` is expressed in the destination
    /// window's base coordinate system, not in screen coordinates. Keeping
    /// that conversion explicit prevents the panel's screen origin from being
    /// subtracted a second time and makes every drop zone hittable.
    func destination(atWindowPoint windowPoint: NSPoint) -> PortalDropDestination? {
        guard bounds.width >= 700, bounds.height >= 400,
              window != nil else { return nil }

        let localPoint = convert(windowPoint, from: nil)

        // The expanded surface is fixed at 720 x 432. The scope switcher is
        // laid out 18 pt from the sides, 71 pt from the top, with 4 pt outer
        // padding and 4 pt between its two equal-width buttons. AppKit uses a
        // bottom-left origin, so convert the top-anchored layout here.
        let switcherTop: CGFloat = 71
        let switcherHeight: CGFloat = 52
        let switcherFrame = NSRect(
            x: 18,
            y: bounds.height - switcherTop - switcherHeight,
            width: bounds.width - 36,
            height: switcherHeight
        )
        let innerFrame = switcherFrame.insetBy(dx: 4, dy: 4)
        let buttonWidth = (innerFrame.width - 4) / 2
        let temporaryFrame = NSRect(
            x: innerFrame.minX,
            y: innerFrame.minY,
            width: buttonWidth,
            height: innerFrame.height
        )
        let permanentFrame = NSRect(
            x: temporaryFrame.maxX + 4,
            y: temporaryFrame.minY,
            width: buttonWidth,
            height: innerFrame.height
        )

        if permanentFrame.contains(localPoint) {
            return .permanentTab
        }
        if temporaryFrame.contains(localPoint) {
            return .temporaryTab
        }

        let topDownY = bounds.height - localPoint.y
        let itemAreaTop: CGFloat = activeSection == .temporary ? 136 : 172
        let itemAreaBottom = bounds.height - 18
        guard topDownY >= itemAreaTop, topDownY <= itemAreaBottom else {
            return nil
        }

        if activeSection == .temporary {
            return .temporaryArea
        }

        let paneWidth = (switcherFrame.width - 10) / 2
        let permanentPaneFrame = NSRect(
            x: switcherFrame.minX,
            y: bounds.height - itemAreaBottom,
            width: paneWidth,
            height: itemAreaBottom - itemAreaTop
        )
        if permanentPaneFrame.contains(localPoint) {
            return .permanentArea
        }

        let customPaneFrame = NSRect(
            x: permanentPaneFrame.maxX + 10,
            y: permanentPaneFrame.minY,
            width: paneWidth,
            height: permanentPaneFrame.height
        )
        if customPaneFrame.contains(localPoint) {
            return .customArea
        }
        return nil
    }
}

private final class FirstMouseHotspotButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private struct AreaRenameEditor: View {
    let originalName: String
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var proposedName: String
    @FocusState private var isFocused: Bool

    init(originalName: String, onCancel: @escaping () -> Void, onSave: @escaping (String) -> Void) {
        self.originalName = originalName
        self.onCancel = onCancel
        self.onSave = onSave
        self._proposedName = State(initialValue: originalName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("重命名区域")
                .font(PortalTokens.Typography.display)
                .foregroundStyle(PortalTokens.Palette.primaryText)

            TextField("名称", text: $proposedName)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .padding(PortalTokens.Spacing.small)
                .portalGlass(cornerRadius: PortalTokens.Radius.small)
                .onSubmit(save)

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .buttonStyle(PortalTextButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("保存", action: save)
                    .buttonStyle(.borderedProminent)
                    .tint(PortalTokens.Palette.accent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(PortalTokens.Palette.canvas)
        .preferredColorScheme(.dark)
        .task {
            await Task.yield()
            isFocused = true
        }
    }

    private var trimmedName: String {
        proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        if trimmedName == originalName {
            onCancel()
        } else {
            onSave(trimmedName)
        }
    }
}
