import Foundation

/// UserDefaults-backed preference keys (kept out of the SwiftData model to avoid
/// schema migrations for simple on/off switches).
enum PrefKeys {
    static let autoStartBreaks = "autoStartBreaks"
}

/// Pure conversions for the daily reminder time (minutes-from-midnight ⇄ clock).
enum ReminderTime {
    static func components(fromMinutes minutes: Int) -> (hour: Int, minute: Int) {
        let clamped = ((minutes % 1440) + 1440) % 1440
        return (clamped / 60, clamped % 60)
    }

    static func minutes(hour: Int, minute: Int) -> Int {
        (((hour * 60 + minute) % 1440) + 1440) % 1440
    }

    static func format(minutesFromMidnight minutes: Int) -> String {
        let (hour, minute) = components(fromMinutes: minutes)
        let period = hour < 12 ? "AM" : "PM"
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", hour12, minute, period)
    }
}

/// Pure blocklist editing — case-insensitive dedupe, ignores blank entries.
enum BlocklistEditor {
    static func adding(_ bundleID: String, to list: [String]) -> [String] {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !list.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame })
        else { return list }
        return list + [trimmed]
    }

    static func removing(_ bundleID: String, from list: [String]) -> [String] {
        list.filter { $0.caseInsensitiveCompare(bundleID) != .orderedSame }
    }
}
