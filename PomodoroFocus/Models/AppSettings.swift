import Foundation
import SwiftData

/// Singleton settings + streak state. Named `AppSettings` to avoid colliding
/// with SwiftUI's `Settings` scene.
@Model
final class AppSettings {
    // MARK: Timer configuration
    var workMins: Int
    var shortBreakMins: Int
    var longBreakMins: Int
    /// A long break occurs after every Nth completed pomodoro.
    var longBreakEvery: Int
    /// Optional daily pomodoro goal.
    var dailyGoal: Int?

    // MARK: Triggers
    /// Minutes from midnight for the morning "plan your day" nudge (540 = 09:00).
    var planReminderMinutes: Int
    /// Whether the evening "streak at risk" nudge is enabled.
    var streakRiskNudgeEnabled: Bool

    // MARK: Streak rules
    /// Minimum completed pomodoros for a day to "qualify" toward the streak.
    var streakBar: Int
    /// Calendar weekday numbers (1=Sun … 7=Sat) that count toward streaks.
    /// Weekends omitted here never break the chain.
    var activeWeekdays: [Int]

    // MARK: Anti-distraction
    /// Bundle identifiers considered distracting during a pomodoro.
    var blocklistBundleIDs: [String]

    // MARK: Streak state (persisted)
    var currentStreak: Int
    var longestStreak: Int
    var lastQualifiedDate: Date?
    var freezesBanked: Int

    init() {
        self.workMins = 25
        self.shortBreakMins = 5
        self.longBreakMins = 15
        self.longBreakEvery = 4
        self.dailyGoal = 8
        self.planReminderMinutes = 9 * 60
        self.streakRiskNudgeEnabled = true
        self.streakBar = 1
        self.activeWeekdays = [1, 2, 3, 4, 5, 6, 7]
        self.blocklistBundleIDs = []
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastQualifiedDate = nil
        self.freezesBanked = 0
    }

    var workSeconds: TimeInterval { TimeInterval(workMins * 60) }
    var shortBreakSeconds: TimeInterval { TimeInterval(shortBreakMins * 60) }
    var longBreakSeconds: TimeInterval { TimeInterval(longBreakMins * 60) }
}
