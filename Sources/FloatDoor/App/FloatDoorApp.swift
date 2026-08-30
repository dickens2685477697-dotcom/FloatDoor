import AppKit

@main
struct FloatDoorApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = PortalStore()
    private lazy var clipboardImporter = ClipboardImporter(store: store)
    private lazy var panelController = NotchPanelController(store: store)
    private lazy var settingsWindowController = SettingsWindowController(store: store)
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = ApplicationMenuFactory.makeMainMenu()
        panelController.install()
        installStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.purgeExpired(showNotice: false)
    }

    @objc
    private func openPortal() {
        panelController.show()
    }

    @objc
    private func saveClipboard() {
        clipboardImporter.importCurrentContents()
        panelController.show()
    }

    @objc
    private func createMaterial() {
        panelController.presentNewMaterialEditor(source: "status-menu")
    }

    @objc
    private func clearTemporary() {
        store.clearTemporary()
    }

    @objc
    private func openSettings() {
        settingsWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func createCustomAreaContent() {
        panelController.presentNewMaterialEditor(source: "status-menu", scope: .custom)
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }

    private func installStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = PortalMenuIcon.door()
        statusItem.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        menu.addItem(withTitle: "打开 Float Door", action: #selector(openPortal), keyEquivalent: "")
        menu.addItem(withTitle: "新建长期素材", action: #selector(createMaterial), keyEquivalent: "n")
        menu.addItem(withTitle: "新建自定义区域内容", action: #selector(createCustomAreaContent), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "保存当前剪贴板", action: #selector(saveClipboard), keyEquivalent: "v")
        menu.addItem(withTitle: "清空一次性区域", action: #selector(clearTemporary), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 Float Door", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }

        statusItem.menu = menu
        self.statusItem = statusItem
    }
}

enum ApplicationMenuFactory {
    static func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let applicationMenuItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Float Door")
        applicationMenu.addItem(
            withTitle: "退出 Float Door",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        applicationMenuItem.submenu = applicationMenu
        mainMenu.addItem(applicationMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(menuItem("撤销", action: "undo:", keyEquivalent: "z"))
        let redo = menuItem("重做", action: "redo:", keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(menuItem("剪切", action: "cut:", keyEquivalent: "x"))
        editMenu.addItem(menuItem("复制", action: "copy:", keyEquivalent: "c"))
        editMenu.addItem(menuItem("粘贴", action: "paste:", keyEquivalent: "v"))
        editMenu.addItem(menuItem("全选", action: "selectAll:", keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        return mainMenu
    }

    private static func menuItem(_ title: String, action: String, keyEquivalent: String) -> NSMenuItem {
        NSMenuItem(title: title, action: Selector((action)), keyEquivalent: keyEquivalent)
    }
}
