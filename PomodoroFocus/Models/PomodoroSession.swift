import Foundation
import SwiftData

/// A single pomodoro attempt bound to a task. Distraction events hang off the
/// *session* (not the day) so the dashboard can answer "which tasks trigger the
/// most app-switching?".
@Model
final class PomodoroSession {
    var startedAt: Date
    var endedAt: Date?
    /// The intended length in seconds (e.g. 25 * 60).
    var plannedDuration: TimeInterval
    /// Seconds actually spent focused (may be less if abandoned early).
    var focusedDuration: TimeInterval
    /// True only when the full pomodoro elapsed (not skipped/abandoned).
    var wasCompleted: Bool

    var task: TaskItem?

    @Relationship(deleteRule: .cascade, inverse: \DistractionEvent.session)
    var distractions: [DistractionEvent] = []

    init(startedAt: Date = .now, plannedDuration: TimeInterval, task: TaskItem? = nil) {
        self.startedAt = startedAt
        self.plannedDuration = plannedDuration
        self.focusedDuration = 0
        self.wasCompleted = false
        self.task = task
    }
}
