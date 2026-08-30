import Combine
import Foundation

@MainActor
final class PortalStore: NSObject, ObservableObject {
    @Published private(set) var items: [PortalItem] = []
    @Published private(set) var notice: PortalNotice?
    @Published private(set) var temporaryRetention: TemporaryRetention
    @Published private(set) var materialAreaName: String
    @Published private(set) var customAreaName: String

    private let repository: any PortalRepository
    private let defaults: UserDefaults
    private let retentionDefaultsKey = "temporaryRetentionHours"
    private let materialAreaNameDefaultsKey = "materialAreaName"
    private let customAreaNameDefaultsKey = "customAreaName"
    private var expiryTimer: Timer?

    init(
        repository: any PortalRepository,
        defaults: UserDefaults = .standard,
        schedulesExpiryCleanup: Bool = false
    ) {
        self.repository = repository
        self.defaults = defaults
        let savedRetention = defaults.object(forKey: retentionDefaultsKey) as? Int
        self.temporaryRetention = TemporaryRetention(rawValue: savedRetention ?? TemporaryRetention.oneDay.rawValue) ?? .oneDay
        self.materialAreaName = Self.validAreaName(defaults.string(forKey: materialAreaNameDefaultsKey), fallback: "素材")
        self.customAreaName = Self.validAreaName(defaults.string(forKey: customAreaNameDefaultsKey), fallback: "Prompt")
        super.init()

        do {
            try repository.prepareDirectories()
            items = try repository.load()
            purgeExpired(showNotice: false)
        } catch {
            setNotice(error.localizedDescription, style: .error)
        }

        if schedulesExpiryCleanup {
            expiryTimer = Timer.scheduledTimer(
                timeInterval: 15 * 60,
                target: self,
                selector: #selector(runExpiryCleanup(_:)),
                userInfo: nil,
                repeats: true
            )
        }
    }

    convenience init(rootURL: URL? = nil, defaults: UserDefaults = .standard) {
        self.init(
            repository: PortalFileStore(rootURL: rootURL ?? Self.defaultRootURL()),
            defaults: defaults,
            schedulesExpiryCleanup: rootURL == nil
        )
    }

    @objc
    private func runExpiryCleanup(_ timer: Timer) {
        purgeExpired()
    }

    var temporaryItems: [PortalItem] {
        items
            .filter { $0.scope == .temporary }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var permanentItems: [PortalItem] {
        items
            .filter { $0.scope == .permanent }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var customItems: [PortalItem] {
        items
            .filter { $0.scope == .custom }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var totalItemCount: Int {
        items.count
    }

    var storageUsage: Int64 {
        repository.storageUsage()
    }

    var storageRootURL: URL {
        repository.rootURL
    }

    func setTemporaryRetention(_ retention: TemporaryRetention) {
        temporaryRetention = retention
        defaults.set(retention.rawValue, forKey: retentionDefaultsKey)
        setNotice("一次性内容默认策略已更新为\(retention.displayName)。", style: .success)
    }

    func renameMaterialArea(to name: String) {
        renameArea(
            name,
            currentName: materialAreaName,
            defaultsKey: materialAreaNameDefaultsKey,
            update: { self.materialAreaName = $0 }
        )
    }

    func renameCustomArea(to name: String) {
        renameArea(
            name,
            currentName: customAreaName,
            defaultsKey: customAreaNameDefaultsKey,
            update: { self.customAreaName = $0 }
        )
    }

    func importText(_ text: String, into scope: StorageScope) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setNotice("不能保存空文本。", style: .error)
            return
        }

        let item = PortalItemFactory.text(
            text,
            scope: scope,
            expiresAt: expirationDate(for: scope)
        )
        add(item, successMessage: "已放入\(displayName(for: scope))区域。")
    }

    func importURL(_ url: URL, into scope: StorageScope) {
        if url.isFileURL {
            importFile(at: url, into: scope)
            return
        }

        let item = PortalItemFactory.link(
            url,
            scope: scope,
            expiresAt: expirationDate(for: scope)
        )
        add(item, successMessage: "链接已放入\(displayName(for: scope))区域。")
    }

    func importFile(at sourceURL: URL, into scope: StorageScope) {
        let id = UUID()
        do {
            let storedFile = try repository.copyFile(at: sourceURL, id: id, scope: scope)
            let item = PortalItemFactory.file(
                id: id,
                originalName: sourceURL.lastPathComponent,
                storedFile: storedFile,
                scope: scope,
                expiresAt: expirationDate(for: scope)
            )
            add(item, rollbackFileFor: item, successMessage: "已放入\(displayName(for: scope))区域。")
        } catch {
            setNotice("无法保存 \(sourceURL.lastPathComponent)：\(error.localizedDescription)", style: .error)
        }
    }

    func importFileData(
        _ data: Data,
        originalName: String,
        contentTypeIdentifier: String?,
        into scope: StorageScope
    ) {
        let id = UUID()
        do {
            let resolvedTypeIdentifier = PortalItemFactory.resolvedContentTypeIdentifier(
                supplied: contentTypeIdentifier,
                originalName: originalName
            )
            let storedFile = try repository.saveData(
                data,
                originalName: originalName,
                contentTypeIdentifier: resolvedTypeIdentifier,
                id: id,
                scope: scope
            )
            let item = PortalItemFactory.file(
                id: id,
                originalName: originalName,
                storedFile: storedFile,
                scope: scope,
                expiresAt: expirationDate(for: scope)
            )
            add(item, rollbackFileFor: item, successMessage: "已放入\(displayName(for: scope))区域。")
        } catch {
            setNotice("无法保存 \(originalName)：\(error.localizedDescription)", style: .error)
        }
    }

    func promote(_ item: PortalItem) {
        guard item.scope == .temporary, let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        let previousItems = items
        do {
            try repository.moveCachedFile(for: item, to: .permanent)
            var promoted = item
            promoted.scope = .permanent
            promoted.expiresAt = nil
            promoted.updatedAt = .now
            items[index] = promoted

            guard persist() else {
                items = previousItems
                try? repository.moveCachedFile(for: promoted, to: .temporary)
                return
            }
            setNotice("已转为长期素材。", style: .success)
        } catch {
            setNotice("转为长期素材失败：\(error.localizedDescription)", style: .error)
        }
    }

    func rename(_ item: PortalItem, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        let previousItems = items
        items[index].name = trimmedName
        items[index].updatedAt = .now
        guard persist() else {
            items = previousItems
            return
        }
        setNotice("已重命名。", style: .success)
    }

    func delete(_ item: PortalItem) {
        remove([item], successMessage: "已删除内容。")
    }

    func delete(_ items: [PortalItem]) {
        let existingItems = items.filter { target in
            self.items.contains { $0.id == target.id }
        }
        guard !existingItems.isEmpty else { return }
        let message = existingItems.count == 1
            ? "已删除内容。"
            : "已删除 \(existingItems.count) 个内容。"
        remove(existingItems, successMessage: message)
    }

    func clearTemporary() {
        remove(temporaryItems, successMessage: "已清空一次性区域。")
    }

    func purgeExpired(showNotice: Bool = true) {
        let expiredItems = temporaryItems.filter(\.isExpired)
        guard !expiredItems.isEmpty else { return }
        remove(expiredItems, successMessage: showNotice ? "已清理 \(expiredItems.count) 个过期内容。" : nil)
    }

    func fileURL(for item: PortalItem) -> URL? {
        repository.cachedURL(for: item)
    }

    func dismissNotice() {
        notice = nil
    }

    func reportImportFailure(_ message: String) {
        setNotice(message, style: .error)
    }

    func showInformation(_ message: String) {
        setNotice(message, style: .information)
    }

    private func add(_ item: PortalItem, rollbackFileFor rollbackItem: PortalItem? = nil, successMessage: String) {
        let previousItems = items
        items.append(item)
        guard persist() else {
            items = previousItems
            if let rollbackItem {
                repository.deleteCachedFile(for: rollbackItem)
            }
            return
        }
        setNotice(successMessage, style: .success)
    }

    private func remove(_ targets: [PortalItem], successMessage: String?) {
        guard !targets.isEmpty else { return }
        let targetIDs = Set(targets.map(\.id))
        let previousItems = items
        items.removeAll { targetIDs.contains($0.id) }
        guard persist() else {
            items = previousItems
            return
        }
        targets.forEach(repository.deleteCachedFile)
        if let successMessage {
            setNotice(successMessage, style: .success)
        }
    }

    @discardableResult
    private func persist() -> Bool {
        do {
            try repository.save(items)
            return true
        } catch {
            setNotice("本地保存失败：\(error.localizedDescription)", style: .error)
            return false
        }
    }

    private func expirationDate(for scope: StorageScope) -> Date? {
        scope == .temporary ? temporaryRetention.expirationDate() : nil
    }

    private func displayName(for scope: StorageScope) -> String {
        switch scope {
        case .temporary:
            return scope.displayName
        case .permanent:
            return materialAreaName
        case .custom:
            return customAreaName
        }
    }

    private func renameArea(
        _ name: String,
        currentName: String,
        defaultsKey: String,
        update: (String) -> Void
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName != currentName else { return }

        update(trimmedName)
        defaults.set(trimmedName, forKey: defaultsKey)
        setNotice("已重命名区域。", style: .success)
    }

    private func setNotice(_ text: String, style: PortalNoticeStyle) {
        if case .success = style {
            notice = nil
            return
        }
        notice = PortalNotice(text: text, style: style)
    }

    private static func defaultRootURL() -> URL {
        let fileManager = FileManager.default
        let applicationSupport = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        return migratedRootURL(in: applicationSupport, fileManager: fileManager)
    }

    /// Keeps material created by builds released before the Float Door rename.
    /// New installations always use the FloatDoor directory.
    static func migratedRootURL(
        in applicationSupport: URL,
        fileManager: FileManager = .default
    ) -> URL {
        let currentRoot = applicationSupport.appending(path: "FloatDoor", directoryHint: .isDirectory)
        guard !fileManager.fileExists(atPath: currentRoot.path) else {
            return currentRoot
        }

        let legacyDirectoryName = ["Mac", "Any", "Door"].joined()
        let legacyRoot = applicationSupport.appending(path: legacyDirectoryName, directoryHint: .isDirectory)
        guard fileManager.fileExists(atPath: legacyRoot.path) else {
            return currentRoot
        }

        do {
            try fileManager.moveItem(at: legacyRoot, to: currentRoot)
            return currentRoot
        } catch {
            return legacyRoot
        }
    }

    private static func validAreaName(_ value: String?, fallback: String) -> String {
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedValue.isEmpty ? fallback : trimmedValue
    }
}
