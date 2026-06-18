import Foundation
import Observation

/// The phase of the pomodoro cycle. The semantic color/label is derived from
/// this everywhere (see `Theme.Palette.color(for:)`).
enum TimerPhase: Equatable {
    case idle
    case running
    case paused
    case shortBreak
    case longBreak

    var isFocus: Bool { self == .running }
    var isBreak: Bool { self == .shortBreak || self == .longBreak }

    /// Short user-facing label (always shown alongside color — never color alone).
    var label: String {
        switch self {
        case .idle: return "Ready"
        case .running: return "Focus"
        case .paused: return "Paused"
        case .shortBreak: return "Break"
        case .longBreak: return "Long break"
        }
    }

    /// SF Symbol paired with the phase.
    var symbol: String {
        switch self {
        case .idle: return "timer"
        case .running: return "timer"
        case .paused: return "pause.circle"
        case .shortBreak: return "cup.and.saucer"
        case .longBreak: return "figure.walk"
        }
    }
}

// MARK: - TimerEngine
//
// Built test-first. All countdown/transition logic lives in `tick()` so it is
// driven deterministically by tests; the production run-loop `Timer` does nothing
// but call `tick()` once per second. The engine has no policy of its own — it
// never auto-starts a break. It reports lifecycle moments through the three
// closures so the coordinator can persist sessions and choose what happens next.

@MainActor
@Observable
final class TimerEngine {

    private(set) var phase: TimerPhase = .idle
    private(set) var secondsRemaining: Int = 0
    private(set) var completedInCycle: Int = 0
    private(set) var currentTaskTitle: String?

    var onFocusCompleted: (() -> Void)?
    var onBreakCompleted: (() -> Void)?
    var onFocusStarted: (() -> Void)?

    /// Retained run-loop timer; non-observable so ticking doesn't churn views.
    @ObservationIgnored private var timer: Timer?
    /// Phase to restore on `resume()` after a `pause()`.
    @ObservationIgnored private var pausedPhase: TimerPhase?

    // MARK: Commands

    func startWork(taskTitle: String?, durationSeconds: Int) {
        invalidateTimer()
        pausedPhase = nil
        currentTaskTitle = taskTitle
        secondsRemaining = max(0, durationSeconds)
        phase = .running
        onFocusStarted?()
        scheduleTimer()
    }

    func startBreak(isLong: Bool, durationSeconds: Int) {
        invalidateTimer()
        pausedPhase = nil
        secondsRemaining = max(0, durationSeconds)
        phase = isLong ? .longBreak : .shortBreak
        scheduleTimer()
    }

    func pause() {
        guard phase == .running || phase.isBreak else { return }
        pausedPhase = phase
        phase = .paused
        invalidateTimer()
    }

    func resume() {
        guard phase == .paused, let resumed = pausedPhase else { return }
        phase = resumed
        pausedPhase = nil
        scheduleTimer()
    }

    /// End the current interval immediately.
    /// - Focus: the user abandoned it — do NOT count it, fire nothing, go idle.
    /// - Break: go idle and fire `onBreakCompleted`.
    func skip() {
        let wasBreak: Bool
        switch phase {
        case .running: wasBreak = false
        case .shortBreak, .longBreak: wasBreak = true
        case .paused: wasBreak = (pausedPhase?.isBreak ?? false)
        case .idle: return
        }
        invalidateTimer()
        resetToIdle()
        if wasBreak { onBreakCompleted?() }
    }

    func stop() {
        invalidateTimer()
        resetToIdle()
    }

    // MARK: Tick

    /// One countdown step. Decrements `secondsRemaining` and performs the
    /// end-of-interval transition when it reaches zero. Driven by the run-loop
    /// timer in production; called directly by tests.
    func tick() {
        guard phase == .running || phase.isBreak else { return }

        if secondsRemaining > 0 { secondsRemaining -= 1 }
        guard secondsRemaining <= 0 else { return }

        let finishedFocus = (phase == .running)
        invalidateTimer()
        secondsRemaining = 0
        phase = .idle
        if finishedFocus {
            completedInCycle += 1
            onFocusCompleted?()
        } else {
            onBreakCompleted?()
        }
    }

    // MARK: Timer plumbing (production glue — not unit-tested; verified by running)

    private func scheduleTimer() {
        invalidateTimer()
        let t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func resetToIdle() {
        phase = .idle
        secondsRemaining = 0
        pausedPhase = nil
    }

    // MARK: Derived

    var displayTime: String {
        let m = max(0, secondsRemaining) / 60
        let s = max(0, secondsRemaining) % 60
        return String(format: "%02d:%02d", m, s)
    }

    var isActive: Bool { phase != .idle }
}
