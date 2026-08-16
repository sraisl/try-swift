import Foundation

/// Port of `Time.now.strftime("%Y-%m-%d")`, used throughout for directory naming.
public enum DatePrefix {
    public static func today(_ date: Date = Date()) -> String {
        formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
