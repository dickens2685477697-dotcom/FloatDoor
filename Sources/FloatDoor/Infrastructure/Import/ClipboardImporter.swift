import AppKit
import UniformTypeIdentifiers

/// Adapts the system pasteboard into application-level import commands.
@MainActor
final class ClipboardImporter {
    private let store: PortalStore

    init(store: PortalStore) {
        self.store = store
    }

    func importCurrentContents(into scope: StorageScope = .temporary) {
        importContents(of: .general, into: scope)
    }

    func importContents(of pasteboard: NSPasteboard, into scope: StorageScope = .temporary) {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [:]) as? [NSURL], !urls.isEmpty {
            urls.map { $0 as URL }.forEach { store.importURL($0, into: scope) }
            return
        }

        if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            let type = pasteboard.data(forType: .png) == nil ? UTType.tiff : UTType.png
            store.importFileData(
                imageData,
                originalName: "剪贴板图片.\(type.preferredFilenameExtension ?? "data")",
                contentTypeIdentifier: type.identifier,
                into: scope
            )
            return
        }

        if let text = pasteboard.string(forType: .string) {
            store.importText(text, into: scope)
            return
        }

        store.showInformation("剪贴板中没有可保存的文本、图片、链接或文件。")
    }
}
