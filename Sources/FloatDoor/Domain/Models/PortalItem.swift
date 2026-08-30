import Foundation
import UniformTypeIdentifiers

enum PortalItemType: String, Codable, CaseIterable {
    case text
    case url
    case image
    case file

    static func from(contentTypeIdentifier: String?) -> PortalItemType {
        guard
            let contentTypeIdentifier,
            let contentType = UTType(contentTypeIdentifier)
        else {
            return .file
        }

        return contentType.conforms(to: .image) ? .image : .file
    }
}

enum StorageScope: String, Codable, CaseIterable {
    case temporary
    case permanent
    case custom

    var displayName: String {
        switch self {
        case .temporary:
            return "一次性"
        case .permanent:
            return "长期素材"
        case .custom:
            return "自定义区域"
        }
    }
}

struct PortalItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var type: PortalItemType
    var scope: StorageScope
    var textContent: String?
    var originalURL: URL?
    var cachedFilename: String?
    var thumbnailFilename: String?
    var contentTypeIdentifier: String?
    var fileSize: Int64?
    var createdAt: Date
    var updatedAt: Date
    var expiresAt: Date?
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        name: String,
        type: PortalItemType,
        scope: StorageScope,
        textContent: String? = nil,
        originalURL: URL? = nil,
        cachedFilename: String? = nil,
        thumbnailFilename: String? = nil,
        contentTypeIdentifier: String? = nil,
        fileSize: Int64? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        expiresAt: Date? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.scope = scope
        self.textContent = textContent
        self.originalURL = originalURL
        self.cachedFilename = cachedFilename
        self.thumbnailFilename = thumbnailFilename
        self.contentTypeIdentifier = contentTypeIdentifier
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
        self.isPinned = isPinned
    }

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= .now
    }

    var contentSummary: String {
        switch type {
        case .text:
            return textContent?.singleLinePreview ?? "空文本"
        case .url:
            return originalURL?.absoluteString ?? "链接"
        case .image, .file:
            return fileSize.map {
                ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)
            } ?? "文件"
        }
    }
}

extension String {
    var singleLinePreview: String {
        let cleaned = components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > 80 else { return cleaned }
        return String(cleaned.prefix(80)) + "…"
    }
}
