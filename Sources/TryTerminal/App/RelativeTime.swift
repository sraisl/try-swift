import Foundation

/// Port of try.rb's `format_relative_time`.
public enum RelativeTime {
    public static func format(_ time: Date, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(time)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24

        if seconds < 60 {
            return "just now"
        } else if minutes < 60 {
            return "\(Int(minutes))m ago"
        } else if hours < 24 {
            return "\(Int(hours))h ago"
        } else if days < 7 {
            return "\(Int(days))d ago"
        } else {
            return "\(Int(days / 7))w ago"
        }
    }
}
