import Foundation

enum PortalNoticeStyle {
    case success
    case error
    case information
}

struct PortalNotice: Identifiable {
    let id = UUID()
    let text: String
    let style: PortalNoticeStyle
}
