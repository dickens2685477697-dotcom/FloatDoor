enum PortalSection: String, CaseIterable, Identifiable {
    case temporary
    case permanent

    var id: Self { self }

    var storageScope: StorageScope {
        switch self {
        case .temporary: return .temporary
        case .permanent: return .permanent
        }
    }

    var title: String {
        switch self {
        case .temporary: return "一次性"
        case .permanent: return "长期"
        }
    }

    var subtitle: String {
        switch self {
        case .temporary: return "默认保存 24 小时"
        case .permanent: return "长期保留"
        }
    }

}

/// The concrete destinations used by the AppKit drag bridge. SwiftUI's
/// `onDrop` can describe these zones declaratively, but the outer panel also
/// needs to know where a drag is hovering when it owns the drag session.
enum PortalDropDestination: Equatable {
    case temporaryTab
    case permanentTab
    case temporaryArea
    case permanentArea
    case customArea

    var section: PortalSection {
        switch self {
        case .temporaryTab, .temporaryArea:
            return .temporary
        case .permanentTab, .permanentArea, .customArea:
            return .permanent
        }
    }

    var storageScope: StorageScope {
        switch self {
        case .temporaryTab, .temporaryArea:
            return .temporary
        case .permanentTab, .permanentArea:
            return .permanent
        case .customArea:
            return .custom
        }
    }

    var isTab: Bool {
        switch self {
        case .temporaryTab, .permanentTab:
            return true
        case .temporaryArea, .permanentArea, .customArea:
            return false
        }
    }
}
