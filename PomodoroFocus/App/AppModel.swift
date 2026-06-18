import SwiftUI
import SwiftData
import AppKit
import UserNotifications

/// Central app coordinator, injected into every surface via `.environment(app)`.
/// Owns the long-lived engines, wires their callbacks, runs the planning +
/// pomodoro commands, and derives the view-facing state (streak, stats, insight,
/// reward) from SwiftData using the pure, TDD'd services.
@MainActor
@Observable
final class AppModel {

    // MARK: Engines
    let timer = TimerEngine()
    let distractionMonitor = DistractionMonitor()
    let notifications = NotificationScheduler()

    // MARK: View-facing derived state
    var streak: StreakSnapshot = .empty
    var stats: StatsSummary = .empty
    var insightOfTheDay: Insight?
    var latestReward: String?
    /// Bumped on every focus completion so the UI can fire a celebration even
    /// when the reward text repeats.
    var rewardNonce = 0
    /// Name of the named break currently running (Coffee/Lunch/Walk), if any.
    var currentBreakName: String?

    // MARK: Infrastructure
    var modelContext: ModelContext?
    @ObservationIgnored private(set) var settings = AppSettings()
    @ObservationIgnored private var activeSession: PomodoroSession?
    @ObservationIgnored private var activeTask: TaskItem?
    @ObservationIgnored private var configured = false
    @ObservationIgnored private let notificationHandler = NotificationActionHandler()
    /// Guards the open-Plan-window-on-launch trigger (once per app launch).
    @ObservationIgnored var didOpenLaunchWindow = false

    // MARK: - Lifecycle

    func configure(context: ModelContext) {
        guard !configured else { return }
        configured = true
        modelContext = context
        settings = loadSettings(context)
        wireCallbacks()
        notificationHandler.app = self
        UNUserNotificationCenter.current().delegate = notificationHandler
        refreshDerived()
        notifications.schedulePlanReminder(atMinutesFromMidnight: settings.planReminderMinutes)
        updateStreakRiskNudge()
        Task { await notifications.requestAuthorization() }
    }

    private func wireCallbacks() {
        timer.onFocusStarted = { [weak self] in self?.handleFocusStarted() }
        timer.onFocusCompleted = { [weak self] in self?.handleFocusCompleted() }
        timer.onBreakCompleted = { [weak self] in self?.handleBreakCompleted() }
        distractionMonitor.onDistraction = { [weak self] name, bundleID, secondsAway in
            self?.logDistraction(name: name, bundleID: bundleID, secondsAway: secondsAway)
        }
    }

    // MARK: - Planning commands

    @discardableResult
    func ensureToday() -> Day? {
        guard let ctx = modelContext else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<Day>(predicate: #Predicate { $0.date == start })
        if let existing = try? ctx.fetch(descriptor).first { return existing }
        let day = Day(date: start)
        ctx.insert(day)
        try? ctx.save()
        return day
    }

    func todaysTasks() -> [TaskItem] {
        (ensureToday()?.tasks ?? []).sorted { $0.order < $1.order }
    }

    func addTask(title: String, plannedPomodoros: Int) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let day = ensureToday(), let ctx = modelContext else { return }
        let task = TaskItem(title: trimmed, plannedPomodoros: max(1, plannedPomodoros),
                            order: nextOrder(in: day), day: day)
        ctx.insert(task)
        try? ctx.save()
    }

    func delete(_ task: TaskItem) {
        guard let ctx = modelContext else { return }
        ctx.delete(task)
        try? ctx.save()
    }

    func setIntention(_ text: String) {
        guard let day = ensureToday() else { return }
        day.dayIntention = text
        try? modelContext?.save()
    }

    func setAllocation(_ task: TaskItem, to value: Int) {
        task.plannedPomodoros = max(1, value)
        try? modelContext?.save()
    }

    func toggleDone(_ task: TaskItem) {
        task.isDone.toggle()
        try? modelContext?.save()
        refreshDerived()
    }

    func carryOverCandidates() -> [TaskItem] {
        guard let ctx = modelContext else { return [] }
        let start = Calendar.current.startOfDay(for: Date())
        var descriptor = FetchDescriptor<Day>(
            predicate: #Predicate { $0.date < start },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let previous = try? ctx.fetch(descriptor).first else { return [] }
        return previous.tasks
            .filter { !$0.isDone && $0.completedPomodoros < $0.plannedPomodoros }
            .sorted { $0.order < $1.order }
    }

    func carryOver(_ task: TaskItem) {
        guard let day = ensureToday(), let ctx = modelContext else { return }
        let remaining = max(1, task.plannedPomodoros - task.completedPomodoros)
        let copy = TaskItem(title: task.title, plannedPomodoros: remaining,
                            order: nextOrder(in: day), day: day, carriedFromDate: task.day?.date)
        ctx.insert(copy)
        try? ctx.save()
    }

    private func nextOrder(in day: Day) -> Int {
        (day.tasks.map(\.order).max() ?? -1) + 1
    }

    // MARK: - Timer commands

    func startPomodoro(for task: TaskItem) {
        activeTask = task
        timer.startWork(taskTitle: task.title, durationSeconds: Int(settings.workSeconds))
    }

    func pauseOrResume() {
        timer.phase == .paused ? timer.resume() : timer.pause()
    }

    func skip() {
        timer.skip()
        endFocusUI()
    }

    func stop() {
        timer.stop()
        endFocusUI()
    }

    private func endFocusUI() {
        distractionMonitor.disarm()
        currentBreakName = nil
    }

    func startShortBreak() {
        endFocusUI()
        timer.startBreak(isLong: false, durationSeconds: Int(settings.shortBreakSeconds))
    }

    func startLongBreak() {
        endFocusUI()
        timer.startBreak(isLong: true, durationSeconds: Int(settings.longBreakSeconds))
    }

    /// Start one of the template's named breaks (Coffee/Lunch/Walk) on demand.
    func startNamedBreak(name: String, minutes: Int) {
        endFocusUI()
        currentBreakName = name
        timer.startBreak(isLong: true, durationSeconds: max(60, minutes * 60))
    }

    /// The task a "start next" action should pick: first unfinished, else first.
    func nextUnfinishedTask() -> TaskItem? {
        let tasks = todaysTasks()
        return tasks.first { !$0.isDone && $0.completedPomodoros < $0.plannedPomodoros } ?? tasks.first
    }

    // MARK: - Timer callbacks

    private func handleFocusStarted() {
        guard let ctx = modelContext else { return }
        let session = PomodoroSession(plannedDuration: settings.workSeconds, task: activeTask)
        ctx.insert(session)
        try? ctx.save()
        activeSession = session
        currentBreakName = nil
        distractionMonitor.arm(blocklist: settings.blocklistBundleIDs)
    }

    private func handleFocusCompleted() {
        guard let ctx = modelContext else { return }
        if let session = activeSession {
            session.wasCompleted = true
            session.endedAt = Date()
            session.focusedDuration = session.plannedDuration
        }
        activeTask?.completedPomodoros += 1
        try? ctx.save()

        endFocusUI()
        activeSession = nil
        refreshDerived()

        let milestone = StreakService().milestone(for: streak.current)
        let reward = RewardEngine.message(milestone: milestone, currentStreak: streak.current,
                                          insight: insightOfTheDay, todayCompleted: stats.todayFocusedPomodoros)
        latestReward = reward
        rewardNonce += 1
        AudioFeedback.playFocusComplete()
        notifications.notifyFocusComplete(rewardText: reward)
        updateStreakRiskNudge()

        // Auto-flow into a break — unless disabled. Finishing a focus *set*
        // starts the template's named break (Coffee/Lunch/Walk) with its real
        // duration; otherwise a short break.
        let autoBreaks = UserDefaults.standard.object(forKey: PrefKeys.autoStartBreaks) as? Bool ?? true
        if autoBreaks {
            let completedToday = todaysTasks().reduce(0) { $0 + $1.completedPomodoros }
            if let rest = TemplateSchedule.restAfter(focusCount: completedToday, segments: TemplateStore.load()) {
                currentBreakName = rest.name
                timer.startBreak(isLong: true, durationSeconds: max(60, rest.minutes * 60))
            } else {
                currentBreakName = nil
                timer.startBreak(isLong: false, durationSeconds: Int(settings.shortBreakSeconds))
            }
        }
    }

    private func handleBreakCompleted() {
        currentBreakName = nil
        AudioFeedback.playBreakOver()
        notifications.notifyBreakOver()
    }

    private func logDistraction(name: String, bundleID: String, secondsAway: TimeInterval) {
        guard let ctx = modelContext, let session = activeSession else { return }
        let event = DistractionEvent(appName: name, appBundleID: bundleID,
                                     secondsAway: secondsAway, session: session)
        ctx.insert(event)
        try? ctx.save()
    }

    // MARK: - Derived state

    func refreshDerived() {
        guard let ctx = modelContext else { return }
        let sessions = (try? ctx.fetch(FetchDescriptor<PomodoroSession>())) ?? []
        let days = (try? ctx.fetch(FetchDescriptor<Day>())) ?? []
        let events = (try? ctx.fetch(FetchDescriptor<DistractionEvent>())) ?? []
        let now = Date()

        let snapshot = StreakService().snapshot(
            stats: Projections.dayStats(from: sessions),
            today: now, streakBar: settings.streakBar, activeWeekdays: settings.activeWeekdays
        )
        streak = snapshot
        settings.currentStreak = snapshot.current
        settings.longestStreak = max(settings.longestStreak, snapshot.longest)
        settings.freezesBanked = snapshot.freezesBanked
        settings.lastQualifiedDate = snapshot.lastQualifiedDate

        let summary = StatsService().summarize(
            sessions: Projections.sessionStats(from: sessions),
            plans: Projections.planStats(from: days),
            distractions: Projections.distractionStats(from: events),
            today: now, days: 14
        )
        stats = summary
        insightOfTheDay = InsightEngine().insightOfTheDay(from: summary)
        try? ctx.save()
    }

    private func updateStreakRiskNudge() {
        if settings.streakRiskNudgeEnabled && streak.isAtRisk && streak.current > 0 {
            notifications.scheduleStreakRisk(streak: streak.current, atMinutesFromMidnight: 20 * 60)
        } else {
            notifications.cancelStreakRisk()
        }
    }

    /// Persist setting edits and re-apply anything time-sensitive (the daily
    /// plan reminder, the streak-risk nudge).
    func applySettings() {
        try? modelContext?.save()
        notifications.schedulePlanReminder(atMinutesFromMidnight: settings.planReminderMinutes)
        updateStreakRiskNudge()
    }

    func addToBlocklist(_ bundleID: String) {
        settings.blocklistBundleIDs = BlocklistEditor.adding(bundleID, to: settings.blocklistBundleIDs)
        try? modelContext?.save()
    }

    func removeFromBlocklist(_ bundleID: String) {
        settings.blocklistBundleIDs = BlocklistEditor.removing(bundleID, from: settings.blocklistBundleIDs)
        try? modelContext?.save()
    }

    // MARK: - Settings

    private func loadSettings(_ ctx: ModelContext) -> AppSettings {
        if let existing = try? ctx.fetch(FetchDescriptor<AppSettings>()).first { return existing }
        let created = AppSettings()
        ctx.insert(created)
        try? ctx.save()
        return created
    }
}
