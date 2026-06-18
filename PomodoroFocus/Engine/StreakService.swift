import Foundation

/// One day's completed-pomodoro total (value type so streak logic is testable
/// without SwiftData).
struct DayStat: Equatable {
    let date: Date
    let completedPomodoros: Int
}

/// The computed streak picture for "today".
struct StreakSnapshot: Equatable {
    let current: Int
    let longest: Int
    let freezesBanked: Int
    let isTodayQualified: Bool
    let lastQualifiedDate: Date?
    let isAtRisk: Bool

    static let empty = StreakSnapshot(
        current: 0, longest: 0, freezesBanked: 0,
        isTodayQualified: false, lastQualifiedDate: nil, isAtRisk: false
    )
}

/// Pure streak calculation. `Calendar` is injectable so tests can pin the
/// timezone; production uses `.current`.
struct StreakService {
    static let milestones = [3, 7, 14, 30, 50, 100, 150, 200, 365]

    var calendar: Calendar
    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func snapshot(stats: [DayStat], today: Date, streakBar: Int, activeWeekdays: [Int]) -> StreakSnapshot {
        let active = Set(activeWeekdays)

        // Sum completed pomodoros per calendar day.
        var completed: [Date: Int] = [:]
        for stat in stats {
            let day = calendar.startOfDay(for: stat.date)
            completed[day, default: 0] += stat.completedPomodoros
        }
        let today0 = calendar.startOfDay(for: today)

        func isActive(_ d: Date) -> Bool { active.contains(calendar.component(.weekday, from: d)) }
        func qualified(_ d: Date) -> Bool { isActive(d) && (completed[d] ?? 0) >= streakBar }
        func prevDay(_ d: Date) -> Date { calendar.date(byAdding: .day, value: -1, to: d)! }

        let qualifiedDates = completed.keys.filter { qualified($0) }
        let minQualified = qualifiedDates.min()
        let lastQualifiedDate = qualifiedDates.filter { $0 <= today0 }.max()

        // A missed day only matters if qualified history exists *before* it;
        // otherwise it's simply where the streak began.
        func hasQualifiedBefore(_ d: Date) -> Bool {
            guard let m = minQualified else { return false }
            return m < d
        }

        // Walk backward from an anchor, counting qualified active days and
        // bridging real gaps with earned freezes (1 per 7 qualified days, max 2).
        func walk(from anchor: Date) -> (count: Int, used: Int) {
            var cursor = anchor
            var count = 0
            var used = 0
            var guardCounter = 0
            while guardCounter < 4000 {
                guardCounter += 1
                if !isActive(cursor) { cursor = prevDay(cursor); continue }  // skip off-days
                if qualified(cursor) {
                    count += 1
                } else if hasQualifiedBefore(cursor) {
                    let allowed = min(2, count / 7)
                    if used < allowed { used += 1 } else { break }
                } else {
                    break  // natural start of the streak
                }
                cursor = prevDay(cursor)
            }
            return (count, used)
        }

        let isTodayQualified = qualified(today0)
        // If today isn't done yet, anchor on yesterday so an in-progress day
        // doesn't count as a break.
        let anchor = isTodayQualified ? today0 : prevDay(today0)
        let (current, used) = walk(from: anchor)

        let freezesBanked = max(0, min(2, current / 7) - used)
        let isAtRisk = !isTodayQualified && isActive(today0) && current > 0

        var longest = current
        for d in qualifiedDates {
            longest = max(longest, walk(from: d).count)
        }

        return StreakSnapshot(
            current: current,
            longest: longest,
            freezesBanked: freezesBanked,
            isTodayQualified: isTodayQualified,
            lastQualifiedDate: lastQualifiedDate,
            isAtRisk: isAtRisk
        )
    }

    func milestone(for streak: Int) -> Int? {
        Self.milestones.contains(streak) ? streak : nil
    }
}
