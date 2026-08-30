import Foundation
import UniformTypeIdentifiers

/// Centralizes PortalItem construction so new import sources do not duplicate
/// naming, expiration, and content-type rules.
enum PortalItemFactory {
    static func text(
        _ text: String,
        scope: StorageScope,
        expiresAt: Date?
    ) -> PortalItem {
        PortalItem(
            name: suggestedTextName(for: text),
            type: .text,
            scope: scope,
            textContent: text,
            createdAt: .now,
            updatedAt: .now,
            expiresAt: expiresAt
        )
    }

    static func link(
        _ url: URL,
        scope: StorageScope,
        expiresAt: Date?
    ) -> PortalItem {
        PortalItem(
            name: url.host(percentEncoded: false) ?? url.absoluteString,
            type: .url,
            scope: scope,
            originalURL: url,
            createdAt: .now,
            updatedAt: .now,
            expiresAt: expiresAt
        )
    }

    static func file(
        id: UUID,
        originalName: String,
        storedFile: StoredFile,
        scope: StorageScope,
        expiresAt: Date?
    ) -> PortalItem {
        PortalItem(
            id: id,
            name: originalName.isEmpty ? "未命名文件" : originalName,
            type: PortalItemType.from(contentTypeIdentifier: storedFile.contentTypeIdentifier),
            scope: scope,
            cachedFilename: storedFile.filename,
            contentTypeIdentifier: storedFile.contentTypeIdentifier,
            fileSize: storedFile.fileSize,
            createdAt: .now,
            updatedAt: .now,
            expiresAt: expiresAt
        )
    }

    static func resolvedContentTypeIdentifier(supplied: String?, originalName: String) -> String? {
        let extensionPart = URL(fileURLWithPath: originalName).pathExtension
        guard
            !extensionPart.isEmpty,
            let inferredType = UTType(filenameExtension: extensionPart)
        else {
            return supplied
        }

        if supplied == nil || supplied == UTType.data.identifier || supplied == UTType.item.identifier {
            return inferredType.identifier
        }
        if let supplied, let suppliedType = UTType(supplied), suppliedType.conforms(to: .text) {
            return inferredType.identifier
        }
        return supplied
    }

    private static func suggestedTextName(for text: String) -> String {
        let firstContentLine = text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !firstContentLine.isEmpty else { return "文本片段" }
        guard firstContentLine.count <= 40 else {
            return String(firstContentLine.prefix(40)) + "…"
        }
        return firstContentLine
    }
}
