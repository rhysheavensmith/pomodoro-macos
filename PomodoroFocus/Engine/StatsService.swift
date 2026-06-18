import Foundation

// MARK: - Value-type inputs (the view layer maps SwiftData models -> these,
// keeping the analytics pure and unit-testable without a ModelContainer).

struct SessionStat {
    let startedAt: Date
    let focusedSeconds: Double
    let wasCompleted: Bool
    let taskTitle: String?
    let distractionCount: Int

    init(startedAt: Date, focusedSeconds: Double, wasCompleted: Bool,
         taskTitle: String? = nil, distractionCount: Int = 0) {
        self.startedAt = startedAt
        self.focusedSeconds = focusedSeconds
        self.wasCompleted = wasCompleted
        self.taskTitle = taskTitle
        self.distractionCount = distractionCount
    }
}

struct PlanStat: Equatable {
    let date: Date
    let planned: Int
    let completed: Int
}

struct DistractionStat: Equatable {
    let appName: String
    let count: Int
}

// MARK: - Output

struct DailyHours: Identifiable, Equatable {
    let date: Date
    let hours: Double
    var id: Date { date }
}

struct HourBucket: Identifiable, Equatable {
    let hour: Int
    let completedCount: Int
    var id: Int { hour }
}

struct WeekdayBucket: Identifiable, Equatable {
    let weekday: Int
    let completedCount: Int
    var id: Int { weekday }
}

struct AppCount: Identifiable, Equatable {
    let appName: String
    let count: Int
    var id: String { appName }
}

struct PlanAccuracy: Equatable {
    let planned: Int
    let completed: Int
    var ratio: Double { planned > 0 ? Double(completed) / Double(planned) : 0 }
    var delta: Int { completed - planned }
}

struct StatsSummary: Equatable {
    var todayFocusedPomodoros: Int
    var todayFocusHours: Double
    var todayCompletionRate: Double
    var todayDistractions: Int
    var dailyFocusHours: [DailyHours]
    var timeOfDay: [HourBucket]
    var weekday: [WeekdayBucket]
    var distractionsByApp: [AppCount]
    var planAccuracy: PlanAccuracy
    var bestFocusHourRange: String?
    var bestFocusStartHour: Int?
    var strongestWeekday: Int?
    var totalCompletedPomodoros: Int
    var totalFocusHours: Double

    static let empty = StatsSummary(
        todayFocusedPomodoros: 0, todayFocusHours: 0, todayCompletionRate: 0, todayDistractions: 0,
        dailyFocusHours: [], timeOfDay: [], weekday: [], distractionsByApp: [],
        planAccuracy: PlanAccuracy(planned: 0, completed: 0),
        bestFocusHourRange: nil, bestFocusStartHour: nil, strongestWeekday: nil,
        totalCompletedPomodoros: 0, totalFocusHours: 0
    )
}

// MARK: - StatsService

struct StatsService {
    var calendar: Calendar
    init(calendar: Calendar = .current) { self.calendar = calendar }

    func summarize(sessions: [SessionStat], plans: [PlanStat], distractions: [DistractionStat],
                   today: Date, days: Int) -> StatsSummary {
        let today0 = calendar.startOfDay(for: today)
        let completedSessions = sessions.filter { $0.wasCompleted }

        // --- Today ---
        let todaySessions = sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: today0) }
        let todayFocusedPomodoros = todaySessions.filter { $0.wasCompleted }.count
        let todayFocusHours = todaySessions.reduce(0.0) { $0 + $1.focusedSeconds } / 3600.0
        let todayDistractions = todaySessions.reduce(0) { $0 + $1.distractionCount }

        let todayPlans = plans.filter { calendar.isDate($0.date, inSameDayAs: today0) }
        let todayPlanned = todayPlans.reduce(0) { $0 + $1.planned }
        let todayDone = todayPlans.reduce(0) { $0 + $1.completed }
        let todayCompletionRate = todayPlanned > 0 ? Double(todayDone) / Double(todayPlanned) : 0

        // --- Time of day (24 buckets, completed sessions) ---
        var hourCounts = Array(repeating: 0, count: 24)
        for s in completedSessions {
            let h = calendar.component(.hour, from: s.startedAt)
            if (0..<24).contains(h) { hourCounts[h] += 1 }
        }
        let timeOfDay = (0..<24).map { HourBucket(hour: $0, completedCount: hourCounts[$0]) }
        let peakHour = hourCounts.indices.max(by: { hourCounts[$0] < hourCounts[$1] })
        let bestFocusStartHour: Int? = (peakHour != nil && hourCounts[peakHour!] > 0) ? peakHour : nil
        let bestFocusHourRange = bestFocusStartHour.map { Self.formatHourRange($0) }

        // --- Weekday (1...7, completed sessions) ---
        var wdCounts: [Int: Int] = [:]
        for s in completedSessions {
            wdCounts[calendar.component(.weekday, from: s.startedAt), default: 0] += 1
        }
        let weekday = (1...7).map { WeekdayBucket(weekday: $0, completedCount: wdCounts[$0] ?? 0) }
        let strongestWeekday: Int? = {
            guard let best = (1...7).max(by: { (wdCounts[$0] ?? 0) < (wdCounts[$1] ?? 0) }),
                  (wdCounts[best] ?? 0) > 0 else { return nil }
            return best
        }()

        // --- Distractions by app (aggregate + sort desc) ---
        var appCounts: [String: Int] = [:]
        for d in distractions { appCounts[d.appName, default: 0] += d.count }
        let distractionsByApp = appCounts
            .map { AppCount(appName: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.appName < $1.appName }

        // --- Plan accuracy (totals across the window) ---
        let planAccuracy = PlanAccuracy(
            planned: plans.reduce(0) { $0 + $1.planned },
            completed: plans.reduce(0) { $0 + $1.completed }
        )

        // --- Daily focus hours (last `days`, ending today, zero-filled) ---
        var dailyFocusHours: [DailyHours] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: today0)!)
            let secs = sessions
                .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
                .reduce(0.0) { $0 + $1.focusedSeconds }
            dailyFocusHours.append(DailyHours(date: day, hours: secs / 3600.0))
        }

        return StatsSummary(
            todayFocusedPomodoros: todayFocusedPomodoros,
            todayFocusHours: todayFocusHours,
            todayCompletionRate: todayCompletionRate,
            todayDistractions: todayDistractions,
            dailyFocusHours: dailyFocusHours,
            timeOfDay: timeOfDay,
            weekday: weekday,
            distractionsByApp: distractionsByApp,
            planAccuracy: planAccuracy,
            bestFocusHourRange: bestFocusHourRange,
            bestFocusStartHour: bestFocusStartHour,
            strongestWeekday: strongestWeekday,
            totalCompletedPomodoros: completedSessions.count,
            totalFocusHours: sessions.reduce(0.0) { $0 + $1.focusedSeconds } / 3600.0
        )
    }

    /// Formats a 2-hour focus window, e.g. 9 -> "9–11am", 13 -> "1–3pm".
    static func formatHourRange(_ start: Int) -> String {
        let end = start + 2
        func h12(_ h: Int) -> Int { let x = h % 12; return x == 0 ? 12 : x }
        func ampm(_ h: Int) -> String { (h % 24) < 12 ? "am" : "pm" }
        return ampm(start) == ampm(end)
            ? "\(h12(start))–\(h12(end))\(ampm(end))"
            : "\(h12(start))\(ampm(start))–\(h12(end))\(ampm(end))"
    }
}
