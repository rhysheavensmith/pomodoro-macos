import Foundation

enum InsightKind: Equatable {
    case focusTime
    case distraction
    case consistency
    case planning
}

/// A single surfaced observation. `id` is random so SwiftUI can list them;
/// equality is intentionally not synthesized (compare `kind`/text in tests).
struct Insight: Identifiable {
    let id = UUID()
    let headline: String
    let detail: String
    let kind: InsightKind
}

/// Turns a `StatsSummary` into human-readable insights, ranked by how
/// surprising/actionable they are. The "variable reward" surfaces the top one.
struct InsightEngine {

    func insights(from summary: StatsSummary) -> [Insight] {
        var scored: [(score: Int, insight: Insight)] = []

        // Distraction — most actionable.
        if let top = summary.distractionsByApp.first {
            let total = summary.distractionsByApp.reduce(0) { $0 + $1.count }
            if total > 0 {
                let share = Int((Double(top.count) / Double(total) * 100).rounded())
                scored.append((80, Insight(
                    headline: "Biggest distraction: \(top.appName)",
                    detail: "\(top.appName) caused \(share)% of your distractions.",
                    kind: .distraction)))
            }
        }

        // Planning accuracy.
        let pa = summary.planAccuracy
        if pa.planned >= 4 {
            if pa.ratio < 0.75 {
                scored.append((70, Insight(
                    headline: "You're over-allocating",
                    detail: "You finished \(pa.completed) of \(pa.planned) planned pomodoros — try planning fewer.",
                    kind: .planning)))
            } else if pa.ratio > 1.1 {
                scored.append((70, Insight(
                    headline: "You're under-allocating",
                    detail: "You finish more than you plan — aim a little higher.",
                    kind: .planning)))
            }
        }

        // Best focus window.
        if let range = summary.bestFocusHourRange, summary.bestFocusStartHour != nil {
            scored.append((60, Insight(
                headline: "You focus best \(range)",
                detail: "That's when you complete the most pomodoros — protect that window.",
                kind: .focusTime)))
        }

        // Strongest weekday.
        if let wd = summary.strongestWeekday {
            let name = Self.weekdayName(wd)
            scored.append((50, Insight(
                headline: "\(name)s are your strongest day",
                detail: "You complete the most focus sessions on \(name)s.",
                kind: .consistency)))
        }

        return scored.sorted { $0.score > $1.score }.map { $0.insight }
    }

    func insightOfTheDay(from summary: StatsSummary) -> Insight? {
        insights(from: summary).first
    }

    static func weekdayName(_ weekday: Int) -> String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let idx = weekday - 1
        return names.indices.contains(idx) ? names[idx] : "That day"
    }
}
