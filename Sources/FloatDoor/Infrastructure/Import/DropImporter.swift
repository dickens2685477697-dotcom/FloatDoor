import AppKit
import Foundation
import UniformTypeIdentifiers

/// Converts AppKit drag providers into the small, explicit set of PortalItem
/// inputs. The source app controls the payload; this importer never reads
/// unrelated pasteboard history.
@MainActor
final class DropImporter {
    static let acceptedTypes: [UTType] = [
        .fileURL,
        .url,
        .image,
        .pdf,
        .utf8PlainText,
        .plainText,
        .rtf,
        .html,
        .text,
        .data,
        .item
    ]

    private let store: PortalStore

    init(store: PortalStore) {
        self.store = store
    }

    func importProviders(_ providers: [NSItemProvider], into scope: StorageScope) {
        guard !providers.isEmpty else {
            store.reportImportFailure("没有收到可保存的拖动内容。")
            return
        }

        providers.forEach { importProvider($0, into: scope) }
    }

    /// Bridges an AppKit drag destination back into the same provider-based
    /// importer used by SwiftUI. The outer panel must sometimes receive the
    /// drop itself, so copy each pasteboard item into an in-memory provider
    /// before the asynchronous import begins.
    func importPasteboard(_ pasteboard: NSPasteboard, into scope: StorageScope) {
        importProviders(pasteboardProviders(from: pasteboard), into: scope)
    }

    private func pasteboardProviders(from pasteboard: NSPasteboard) -> [NSItemProvider] {
        guard let items = pasteboard.pasteboardItems else { return [] }

        return items.compactMap { item in
            let provider = NSItemProvider()
            var hasRepresentation = false

            for type in item.types {
                let data = item.data(forType: type)
                    ?? item.string(forType: type)?.data(using: .utf8)
                guard let data else { continue }

                let typeIdentifier = type.rawValue
                provider.registerDataRepresentation(
                    forTypeIdentifier: typeIdentifier,
                    visibility: .all
                ) { completion in
                    completion(data, nil)
                    return nil
                }
                hasRepresentation = true
            }

            if let fileURL = Self.fileURL(from: item) {
                provider.suggestedName = fileURL.lastPathComponent
            }

            return hasRepresentation ? provider : nil
        }
    }

    private func importProvider(_ provider: NSItemProvider, into scope: StorageScope) {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            importFileURL(from: provider, into: scope)
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            importURL(from: provider, into: scope)
            return
        }

        if let imageType = provider.registeredTypeIdentifiers.first(where: {
            UTType($0)?.conforms(to: .image) == true
        }) {
            importData(from: provider, typeIdentifier: imageType, fallbackName: "拖入图片", into: scope)
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            importFileRepresentation(
                from: provider,
                preferredTypeIdentifier: UTType.pdf.identifier,
                into: scope
            )
            return
        }

        // A file dragged from Finder can expose both a file/data flavor and a
        // text flavor. Check the file flavor before text so Markdown (and
        // other text-based files) remain files with their original name.
        if Self.isFileLikeProvider(provider) {
            importFileRepresentation(from: provider, into: scope)
            return
        }

        if let textType = Self.textTypeIdentifier(for: provider) {
            importText(from: provider, typeIdentifier: textType.identifier, into: scope)
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier)
            || provider.hasItemConformingToTypeIdentifier(UTType.item.identifier) {
            importFileRepresentation(from: provider, into: scope)
            return
        }

        store.reportImportFailure("无法识别这段拖动内容。")
    }

    private func importFileRepresentation(
        from provider: NSItemProvider,
        preferredTypeIdentifier: String? = nil,
        into scope: StorageScope
    ) {
        let typeIdentifier = Self.fileRepresentationTypeIdentifier(
            for: provider,
            preferred: preferredTypeIdentifier
        )
        let suggestedName = provider.suggestedName
        let providerBox = SendableItemProvider(provider: provider)

        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] sourceURL, error in
            guard let self else { return }

            if let sourceURL {
                do {
                    let stagingDirectory = FileManager.default.temporaryDirectory
                        .appending(path: "FloatDoorDrop-\(UUID().uuidString)", directoryHint: .isDirectory)
                    let originalName = Self.originalFileName(
                        suggestedName: suggestedName,
                        sourceURL: sourceURL,
                        typeIdentifier: typeIdentifier
                    )
                    let stagedURL = stagingDirectory.appending(path: originalName, directoryHint: .notDirectory)
                    try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: sourceURL, to: stagedURL)

                    Task { @MainActor in
                        self.store.importFile(at: stagedURL, into: scope)
                        try? FileManager.default.removeItem(at: stagingDirectory)
                    }
                } catch {
                    let message = error.localizedDescription
                    Task { @MainActor in
                        self.store.reportImportFailure("无法读取拖入的文件：\(message)")
                    }
                }
                return
            }

            // Some providers expose data but no file representation. Keep the
            // same filename and save the original bytes as a file in that case.
            providerBox.provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] data, dataError in
                guard let self else { return }
                guard let data else {
                    let message = dataError?.localizedDescription
                        ?? error?.localizedDescription
                        ?? "无法读取拖入的文件。"
                    Task { @MainActor in
                        self.store.reportImportFailure(message)
                    }
                    return
                }

                let originalName = Self.originalFileName(
                    suggestedName: suggestedName,
                    sourceURL: nil,
                    typeIdentifier: typeIdentifier
                )
                Task { @MainActor in
                    self.store.importFileData(
                        data,
                        originalName: originalName,
                        contentTypeIdentifier: typeIdentifier,
                        into: scope
                    )
                }
            }
        }
    }

    private func importFileURL(from provider: NSItemProvider, into scope: StorageScope) {
        let suggestedName = provider.suggestedName
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] object, error in
            guard let self else { return }
            guard let sourceURL = Self.url(from: object) else {
                Task { @MainActor in
                    self.store.reportImportFailure(error?.localizedDescription ?? "无法读取拖入的文件。")
                }
                return
            }

            do {
                // NSItemProvider may revoke its temporary representation when
                // this callback returns. Copy it once to a short-lived staging
                // directory so both regular files and folders can be imported
                // on the main actor without retaining the source URL.
                let stagingDirectory = FileManager.default.temporaryDirectory
                    .appending(path: "FloatDoorDrop-\(UUID().uuidString)", directoryHint: .isDirectory)
                let originalName = Self.originalFileName(
                    suggestedName: suggestedName,
                    sourceURL: sourceURL,
                    typeIdentifier: nil
                )
                let stagedURL = stagingDirectory.appending(path: originalName, directoryHint: .notDirectory)
                try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: sourceURL, to: stagedURL)

                Task { @MainActor in
                    self.store.importFile(at: stagedURL, into: scope)
                    try? FileManager.default.removeItem(at: stagingDirectory)
                }
            } catch {
                Task { @MainActor in
                    self.store.reportImportFailure("无法读取 \(sourceURL.lastPathComponent)：\(error.localizedDescription)")
                }
            }
        }
    }

    private func importURL(from provider: NSItemProvider, into scope: StorageScope) {
        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] object, error in
            guard let self else { return }
            guard let url = Self.url(from: object) else {
                Task { @MainActor in
                    self.store.reportImportFailure(error?.localizedDescription ?? "无法读取拖入的链接。")
                }
                return
            }

            Task { @MainActor in
                self.store.importURL(url, into: scope)
            }
        }
    }

    private func importText(from provider: NSItemProvider, typeIdentifier: String, into scope: StorageScope) {
        provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] data, error in
            guard let self else { return }

            guard let data, let text = Self.decodeText(data) else {
                Task { @MainActor in
                    self.store.reportImportFailure(error?.localizedDescription ?? "无法读取拖入的文字。")
                }
                return
            }

            Task { @MainActor in
                self.store.importText(text, into: scope)
            }
        }
    }

    private func importData(
        from provider: NSItemProvider,
        typeIdentifier: String,
        fallbackName: String,
        into scope: StorageScope
    ) {
        let suggestedName = provider.suggestedName
        provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] data, error in
            guard let self else { return }
            guard let data else {
                Task { @MainActor in
                    self.store.reportImportFailure(error?.localizedDescription ?? "无法读取拖入的图片。")
                }
                return
            }

            let name = Self.originalFileName(
                suggestedName: suggestedName,
                sourceURL: nil,
                typeIdentifier: typeIdentifier,
                fallback: fallbackName
            )
            Task { @MainActor in
                self.store.importFileData(data, originalName: name, contentTypeIdentifier: typeIdentifier, into: scope)
            }
        }
    }

    private nonisolated static func textTypeIdentifier(for provider: NSItemProvider) -> UTType? {
        [UTType.utf8PlainText, .plainText, .text, .rtf, .html]
            .first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) })
    }

    private nonisolated static func isFileLikeProvider(_ provider: NSItemProvider) -> Bool {
        let hasText = textTypeIdentifier(for: provider) != nil
        let hasURL = provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
        guard !hasURL else { return false }

        if let suggestedName = provider.suggestedName,
           hasFilenameExtension(in: suggestedName) {
            return true
        }

        let registeredTypes = provider.registeredTypeIdentifiers.compactMap(UTType.init)
        if registeredTypes.contains(where: { markdownTypeIdentifiers.contains($0.identifier) }) {
            return true
        }

        // A data-only provider is a file even when the source app does not
        // provide a filename. If it also advertises text, it may be a text
        // selection; only the filename/Markdown checks above should promote it
        // to a file in that case.
        let hasNonTextData = registeredTypes.contains {
            ($0.conforms(to: .data) || $0.conforms(to: .item))
                && !$0.conforms(to: .text)
                && !$0.conforms(to: .url)
                && !$0.conforms(to: .image)
        }
        return hasNonTextData && !hasText
    }

    private nonisolated static func fileRepresentationTypeIdentifier(
        for provider: NSItemProvider,
        preferred: String?
    ) -> String {
        if let preferred,
           provider.hasItemConformingToTypeIdentifier(preferred) {
            return preferred
        }

        let registeredTypes = provider.registeredTypeIdentifiers.compactMap { identifier in
            UTType(identifier).map { (identifier, $0) }
        }
        if let identifier = registeredTypes.first(where: {
            ($0.1.conforms(to: .data) || $0.1.conforms(to: .item))
                && !$0.1.conforms(to: .text)
                && !$0.1.conforms(to: .url)
                && !$0.1.conforms(to: .image)
        })?.0 {
            return identifier
        }

        if let textType = textTypeIdentifier(for: provider) {
            // A text-based file such as Markdown may expose only a text UTI.
            // Using it for the data fallback preserves the original bytes and
            // still lets the provider-supplied filename identify the file.
            return textType.identifier
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            return UTType.data.identifier
        }
        return UTType.item.identifier
    }

    private nonisolated static func originalFileName(
        suggestedName: String?,
        sourceURL: URL?,
        typeIdentifier: String?,
        fallback: String = "拖入文件"
    ) -> String {
        let suggested = sanitizedFilename(suggestedName)
        let source = sanitizedFilename(sourceURL?.lastPathComponent)

        // Prefer a provider-supplied name when it has an extension. This is
        // what preserves names such as README.md when the file representation
        // itself is a temporary URL.
        if let suggested, hasFilenameExtension(in: suggested) {
            return suggested
        }
        if let source, hasFilenameExtension(in: source) {
            return source
        }
        if let suggested {
            return suggested
        }
        if let source, source != "item" {
            return source
        }

        if let extensionPart = typeIdentifier.flatMap({ UTType($0)?.preferredFilenameExtension }) {
            return "\(fallback).\(extensionPart)"
        }
        return fallback
    }

    private nonisolated static func sanitizedFilename(_ name: String?) -> String? {
        guard let name else { return nil }
        let filename = URL(fileURLWithPath: name).lastPathComponent
        guard !filename.isEmpty, filename != ".", filename != "/" else { return nil }
        return filename
    }

    private nonisolated static func hasFilenameExtension(in name: String) -> Bool {
        !URL(fileURLWithPath: name).pathExtension.isEmpty
    }

    private nonisolated static var markdownTypeIdentifiers: Set<String> {
        Set(["md", "markdown", "mdown", "mkdn", "mkd"].compactMap {
            UTType(filenameExtension: $0)?.identifier
        })
    }

    private nonisolated static func decodeText(_ data: Data) -> String? {
        [
            String.Encoding.utf8,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            .utf32,
            .utf32LittleEndian,
            .utf32BigEndian,
            .ascii
        ].lazy.compactMap { String(data: data, encoding: $0) }.first
    }

    nonisolated private static func url(from object: NSSecureCoding?) -> URL? {
        if let url = object as? URL {
            return url
        }
        if let url = object as? NSURL {
            return url as URL
        }
        if let data = object as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        return nil
    }

    nonisolated private static func fileURL(from item: NSPasteboardItem) -> URL? {
        let fileURLType = NSPasteboard.PasteboardType(UTType.fileURL.identifier)
        if let data = item.data(forType: fileURLType),
           let url = URL(dataRepresentation: data, relativeTo: nil) {
            return url
        }

        guard let string = item.string(forType: fileURLType), !string.isEmpty else {
            return nil
        }
        if let url = URL(string: string), url.isFileURL {
            return url
        }
        return URL(fileURLWithPath: string)
    }
}

private struct SendableItemProvider: @unchecked Sendable {
    let provider: NSItemProvider
}
