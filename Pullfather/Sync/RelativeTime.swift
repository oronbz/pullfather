import Foundation

nonisolated enum RelativeTime {
    static func format(_ date: Date, relativeTo now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        let hours = minutes / 60
        let days = hours / 24
        return switch true {
        case minutes < 1: "now"
        case hours < 1: "\(minutes)m"
        case days < 1: "\(hours)h"
        case days < 7: "\(days)d"
        case days < 30: "\(days / 7)w"
        default: "\(days / 30)mo"
        }
    }
}
