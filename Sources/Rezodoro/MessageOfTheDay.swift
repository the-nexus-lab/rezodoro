import Foundation

/// The rotating message shown above the countdown. Messages take turns in
/// list order, each staying up for the configured number of hours; slots
/// are aligned to local midnight, so with 12 hours they switch at 00:00
/// and 12:00.
enum MessageOfTheDay {
    /// Add new messages here.
    static let messages = [
        "Slow is smooth, smooth is fast.",
        "Hard climb starts years before the crux.",
    ]

    static func message(at date: Date, intervalHours: Int) -> String {
        let slot = slotIndex(at: date, intervalHours: intervalHours)
        let count = messages.count
        return messages[((slot % count) + count) % count]
    }

    /// When the slot containing `date` began, i.e. when the message last
    /// switched.
    static func slotStart(at date: Date, intervalHours: Int) -> Date {
        let length = slotLength(intervalHours)
        let offset = Double(TimeZone.current.secondsFromGMT(for: date))
        let slot = Double(slotIndex(at: date, intervalHours: intervalHours))
        return Date(timeIntervalSince1970: slot * length - offset)
    }

    static func slotLength(_ intervalHours: Int) -> TimeInterval {
        TimeInterval(max(intervalHours, 1) * 3600)
    }

    private static func slotIndex(at date: Date, intervalHours: Int) -> Int {
        let local = date.timeIntervalSince1970 + Double(TimeZone.current.secondsFromGMT(for: date))
        return Int((local / slotLength(intervalHours)).rounded(.down))
    }
}
