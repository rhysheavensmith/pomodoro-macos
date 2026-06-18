import Foundation

/// Pure mappers from SwiftData models into the value-type inputs the analytics
/// services consume. Keeping these separate is what lets the coordinator stay
/// thin and the analytics stay database-free. Stubs until tests drive them.
enum Projections {
    static func sessionStats(from sessions: [PomodoroSession]) -> [SessionStat] {
        sessions.map {
            SessionStat(
                startedAt: $0.startedAt,
                focusedSeconds: $0.focusedDuration,
                wasCompleted: $0.wasCompleted,
                taskTitle: $0.task?.title,
                distractionCount: $0.distractions.count
            )
        }
    }

    static func dayStats(from sessions: [PomodoroSession], calendar: Calendar = .current) -> [DayStat] {
        var byDay: [Date: Int] = [:]
        for s in sessions where s.wasCompleted {
            byDay[calendar.startOfDay(for: s.startedAt), default: 0] += 1
        }
        return byDay.map { DayStat(date: $0.key, completedPomodoros: $0.value) }
    }

    static func planStats(from days: [Day]) -> [PlanStat] {
        days.map { day in
            PlanStat(
                date: day.date,
                planned: day.tasks.reduce(0) { $0 + $1.plannedPomodoros },
                completed: day.tasks.reduce(0) { $0 + $1.completedPomodoros }
            )
        }
    }

    static func distractionStats(from events: [DistractionEvent]) -> [DistractionStat] {
        events.map { DistractionStat(appName: $0.appName, count: 1) }
    }
}
