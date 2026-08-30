import AppKit
import UniformTypeIdentifiers

/// Builds drag representations without coupling PortalStore to AppKit.
@MainActor
final class PortalItemProviderFactory {
    private let store: PortalStore

    init(store: PortalStore) {
        self.store = store
    }

    func provider(for item: PortalItem) -> NSItemProvider {
        switch item.type {
        case .text:
            return NSItemProvider(object: (item.textContent ?? "") as NSString)
        case .url:
            guard let url = item.originalURL else { return NSItemProvider() }
            return NSItemProvider(object: url as NSURL)
        case .image, .file:
            guard
                let fileURL = store.fileURL(for: item),
                let exportURL = try? DragExport.makeFileURL(from: fileURL, named: item.name)
            else {
                return NSItemProvider()
            }

            let provider = NSItemProvider()
            provider.suggestedName = item.name
            provider.registerFileRepresentation(
                forTypeIdentifier: item.contentTypeIdentifier ?? UTType.data.identifier,
                fileOptions: [],
                visibility: .all
            ) { completion in
                completion(exportURL, false, nil)
                return nil
            }
            provider.registerObject(exportURL as NSURL, visibility: .all)
            return provider
        }
    }

    func pasteboardWriters(for items: [PortalItem]) -> [any NSPasteboardWriting] {
        items.compactMap { item in
            switch item.type {
            case .text:
                return (item.textContent ?? "") as NSString
            case .url:
                return item.originalURL as NSURL?
            case .image, .file:
                guard
                    let fileURL = store.fileURL(for: item),
                    let exportURL = try? DragExport.makeFileURL(from: fileURL, named: item.name)
                else {
                    return nil
                }
                return exportURL as NSURL
            }
        }
    }
}

private enum DragExport {
    static func makeFileURL(from sourceURL: URL, named originalName: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "FloatDoorExport-\(UUID().uuidString)", directoryHint: .isDirectory)
        let filename = URL(fileURLWithPath: originalName).lastPathComponent
        let exportName = filename.isEmpty || filename == "." ? sourceURL.lastPathComponent : filename
        let destination = directory.appending(path: exportName, directoryHint: .notDirectory)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: sourceURL, to: destination)

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 300) {
            try? FileManager.default.removeItem(at: directory)
        }
        return destination
    }
}
