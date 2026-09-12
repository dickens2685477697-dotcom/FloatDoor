import Foundation

/// Minute-level labels keep a shelf of items quiet and easy to scan.
enum PortalItemTimeLabel {
    static func created(at date: Date, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        guard seconds >= 60 else { return "刚刚保存" }
        return "\(duration(seconds, roundingUp: false))前"
    }

    static func remaining(until date: Date, now: Date) -> String {
        let seconds = date.timeIntervalSince(now)
        guard seconds > 0 else { return "已到期" }
        guard seconds >= 60 else { return "不足 1 分钟后清理" }
        return "剩余 \(duration(seconds, roundingUp: true))"
    }

    private static func duration(_ seconds: TimeInterval, roundingUp: Bool) -> String {
        let unit: (seconds: Double, label: String)
        if seconds >= 86400 {
            unit = (86400, "天")
        } else if seconds >= 3600 {
            unit = (3600, "小时")
        } else {
            unit = (60, "分钟")
        }
        let value = seconds / unit.seconds
        let amount = Int(roundingUp ? ceil(value) : floor(value))
        return "\(amount) \(unit.label)"
    }
}
