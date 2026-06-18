import Foundation
import UserNotifications

/// Thin wrapper around `UNUserNotificationCenter` that owns every local
/// notification PomodoroFocus can post.
///
/// The scheduler is intentionally self-contained: it has no knowledge of
/// `AppModel`, SwiftData, or any SwiftUI view. The coordinator calls these
/// methods directly (e.g. from `TimerEngine.onFocusCompleted`) and supplies the
/// already-computed copy (the variable reward line, the current streak, etc.).
///
/// All scheduling is best-effort. If the user has denied authorization the
/// underlying center quietly drops the request, so callers never have to branch
/// on permission state — they just ask, and it either appears or it doesn't.
@MainActor
final class NotificationScheduler {

    // MARK: - Stable identifiers

    /// Identifiers for notifications we may later want to update or cancel.
    /// Repeating notifications reuse their identifier so that re-adding a
    /// request transparently *replaces* the previously scheduled one.
    enum Identifier {
        /// Daily "plan your day" nudge.
        static let planReminder = "com.pomodorofocus.notification.planReminder"
        /// Evening "your streak needs a pomodoro" nudge.
        static let streakRisk = "com.pomodorofocus.notification.streakRisk"
        /// Evening "reflect on your day" journal reminder.
        static let journalReminder = "com.pomodorofocus.notification.journalReminder"
        /// Per-focus-completion celebration. A timestamp suffix is appended so
        /// rapid completions never collide.
        static let focusCompletePrefix = "com.pomodorofocus.notification.focusComplete"
        /// Break-over prompt.
        static let breakOverPrefix = "com.pomodorofocus.notification.breakOver"
    }

    /// Categories let us attach actionable buttons later and let the system
    /// group/route notifications consistently.
    enum Category {
        static let planReminder = "PLAN_REMINDER"
        static let focusComplete = "FOCUS_COMPLETE"
        static let breakOver = "BREAK_OVER"
        static let streakRisk = "STREAK_RISK"
        static let journalReminder = "JOURNAL_REMINDER"
    }

    /// Action identifiers exposed on the categories above. Registered up front
    /// so the delegate (wired by the coordinator) can react to taps.
    enum Action {
        static let startBreak = "ACTION_START_BREAK"
        static let startFocus = "ACTION_START_FOCUS"
        static let openPlan = "ACTION_OPEN_PLAN"
    }

    // MARK: - Dependencies

    private let center: UNUserNotificationCenter

    /// - Parameter center: defaults to the shared current center; injectable so
    ///   the coordinator can substitute a configured instance if needed.
    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        registerCategories()
    }

    // MARK: - Authorization

    /// Requests alert + sound permission. Errors (including the user denying)
    /// are swallowed — there is nothing actionable to do and callers treat
    /// scheduling as best-effort regardless of the outcome.
    func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            // Intentionally ignored: denial / restriction simply means our
            // later schedule calls are no-ops from the user's perspective.
        }
    }

    // MARK: - Plan reminder (daily, repeating)

    /// Schedules a daily repeating "plan your day" reminder.
    ///
    /// Using the stable `Identifier.planReminder` means calling this again
    /// (e.g. after the user changes their reminder time in settings) replaces
    /// the existing reminder rather than stacking a second one.
    ///
    /// - Parameter minutes: minutes from local midnight (e.g. 540 == 09:00).
    func schedulePlanReminder(atMinutesFromMidnight minutes: Int) {
        let content = makeContent(
            title: "Plan your day",
            body: "Take a minute to build today's list and set your intention.",
            categoryIdentifier: Category.planReminder
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents(fromMinutesPastMidnight: minutes),
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: Identifier.planReminder,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Focus complete (immediate)

    /// Fires an effectively-immediate "Pomodoro complete" notification whose
    /// body is the supplied variable-reward line.
    ///
    /// A unique identifier (prefix + timestamp) is used so back-to-back
    /// completions each surface their own notification.
    ///
    /// - Parameter rewardText: the variable reward copy to show as the body.
    func notifyFocusComplete(rewardText: String) {
        let content = makeContent(
            title: "Pomodoro complete",
            body: rewardText,
            categoryIdentifier: Category.focusComplete
        )

        let request = UNNotificationRequest(
            identifier: uniqueIdentifier(prefix: Identifier.focusCompletePrefix),
            content: content,
            trigger: immediateTrigger()
        )
        center.add(request)
    }

    // MARK: - Break over (immediate)

    /// Fires an effectively-immediate "Break's over" prompt.
    func notifyBreakOver() {
        let content = makeContent(
            title: "Break's over — ready for the next?",
            body: "Pick your next task and start a focus block.",
            categoryIdentifier: Category.breakOver
        )

        let request = UNNotificationRequest(
            identifier: uniqueIdentifier(prefix: Identifier.breakOverPrefix),
            content: content,
            trigger: immediateTrigger()
        )
        center.add(request)
    }

    // MARK: - Streak risk (daily-ish, repeating)

    /// Schedules a daily evening reminder warning that the streak is at risk.
    ///
    /// Reuses the stable `Identifier.streakRisk`, so calling it again updates
    /// both the time and the streak count in the body.
    ///
    /// - Parameters:
    ///   - streak: the current streak length, surfaced in the body.
    ///   - minutes: minutes from local midnight for the reminder (e.g. 1200 == 20:00).
    func scheduleStreakRisk(streak: Int, atMinutesFromMidnight minutes: Int) {
        let content = makeContent(
            title: "Don't break the chain",
            body: "Your \(streak)-day streak needs 1 pomodoro.",
            categoryIdentifier: Category.streakRisk
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents(fromMinutesPastMidnight: minutes),
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: Identifier.streakRisk,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    /// Cancels the streak-risk reminder (pending and delivered) — call once the
    /// user has qualified for the day so they aren't nagged needlessly.
    func cancelStreakRisk() {
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.streakRisk])
        center.removeDeliveredNotifications(withIdentifiers: [Identifier.streakRisk])
    }

    // MARK: - Journal reminder (daily, repeating)

    /// Schedules a daily evening reminder to journal. Reuses the stable
    /// `Identifier.journalReminder`, so re-scheduling (e.g. after a settings
    /// change) replaces rather than stacks.
    func scheduleJournalReminder(atMinutesFromMidnight minutes: Int) {
        let content = makeContent(
            title: "Reflect on your day",
            body: "What went well, what got in the way, and tomorrow's focus.",
            categoryIdentifier: Category.journalReminder
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents(fromMinutesPastMidnight: minutes),
            repeats: true
        )
        let request = UNNotificationRequest(
            identifier: Identifier.journalReminder,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    /// Cancels the journal reminder (pending and delivered).
    func cancelJournalReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.journalReminder])
        center.removeDeliveredNotifications(withIdentifiers: [Identifier.journalReminder])
    }

    // MARK: - Bulk cancellation

    /// Removes every pending and delivered notification this app owns.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Private helpers

    /// Registers our categories (and their actions) so the system knows how to
    /// present any actionable buttons we attach.
    private func registerCategories() {
        let openPlan = UNNotificationAction(
            identifier: Action.openPlan,
            title: "Plan now",
            options: [.foreground]
        )
        let startBreak = UNNotificationAction(
            identifier: Action.startBreak,
            title: "Start break",
            options: [.foreground]
        )
        let startFocus = UNNotificationAction(
            identifier: Action.startFocus,
            title: "Start focus",
            options: [.foreground]
        )

        let planCategory = UNNotificationCategory(
            identifier: Category.planReminder,
            actions: [openPlan],
            intentIdentifiers: [],
            options: []
        )
        let focusCompleteCategory = UNNotificationCategory(
            identifier: Category.focusComplete,
            actions: [startBreak],
            intentIdentifiers: [],
            options: []
        )
        let breakOverCategory = UNNotificationCategory(
            identifier: Category.breakOver,
            actions: [startFocus],
            intentIdentifiers: [],
            options: []
        )
        let streakRiskCategory = UNNotificationCategory(
            identifier: Category.streakRisk,
            actions: [startFocus],
            intentIdentifiers: [],
            options: []
        )
        let journalCategory = UNNotificationCategory(
            identifier: Category.journalReminder,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([
            planCategory,
            focusCompleteCategory,
            breakOverCategory,
            streakRiskCategory,
            journalCategory,
        ])
    }

    /// Builds notification content with a default sound and the given category.
    private func makeContent(
        title: String,
        body: String,
        categoryIdentifier: String
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        return content
    }

    /// A short (1s) one-shot trigger. `UNTimeIntervalNotificationTrigger`
    /// requires a strictly positive interval, so we use 1 second to get an
    /// effectively-immediate notification.
    private func immediateTrigger() -> UNTimeIntervalNotificationTrigger {
        UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    }

    /// Normalizes minutes-from-midnight into `hour`/`minute` components for a
    /// repeating calendar trigger. Out-of-range input is clamped into a valid
    /// 24-hour window so the trigger never fails to fire.
    private func dateComponents(fromMinutesPastMidnight minutes: Int) -> DateComponents {
        let clamped = min(max(minutes, 0), 24 * 60 - 1)
        var components = DateComponents()
        components.hour = clamped / 60
        components.minute = clamped % 60
        return components
    }

    /// A collision-free identifier for one-shot notifications.
    private func uniqueIdentifier(prefix: String) -> String {
        "\(prefix).\(Date().timeIntervalSince1970)"
    }
}
