import Foundation
import SwiftData

/// A single to-do for a day, with a planned pomodoro allocation.
@Model
final class TaskItem {
    var title: String
    /// Pomodoros allocated to this task during planning.
    var plannedPomodoros: Int
    /// Pomodoros actually completed against this task.
    var completedPomodoros: Int
    var isDone: Bool
    /// Manual sort order within the day.
    var order: Int
    /// If this task was carried over from a previous day, the origin day's date.
    var carriedFromDate: Date?
    var createdAt: Date

    var day: Day?

    @Relationship(deleteRule: .cascade, inverse: \PomodoroSession.task)
    var sessions: [PomodoroSession] = []

    init(
        title: String,
        plannedPomodoros: Int = 1,
        order: Int = 0,
        day: Day? = nil,
        carriedFromDate: Date? = nil
    ) {
        self.title = title
        self.plannedPomodoros = plannedPomodoros
        self.completedPomodoros = 0
        self.isDone = false
        self.order = order
        self.carriedFromDate = carriedFromDate
        self.createdAt = .now
        self.day = day
    }

    /// True when the planned allocation has been met.
    var isFullyWorked: Bool { completedPomodoros >= plannedPomodoros }
}
