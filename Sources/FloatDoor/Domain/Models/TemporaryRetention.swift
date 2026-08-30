import Foundation

enum TemporaryRetention: Int, CaseIterable, Identifiable {
    case oneHour = 1
    case oneDay = 24
    case manual = 0

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .oneHour:
            return "保存 1 小时"
        case .oneDay:
            return "保存 24 小时"
        case .manual:
            return "手动清除"
        }
    }

    func expirationDate(from date: Date = .now) -> Date? {
        guard rawValue > 0 else { return nil }
        return date.addingTimeInterval(TimeInterval(rawValue * 60 * 60))
    }
}
