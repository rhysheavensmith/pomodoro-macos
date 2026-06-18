import AppKit

/// Plays a real, local completion chime — independent of notification permission
/// or Focus/Do-Not-Disturb — so the end of a pomodoro is always audible. Gated by
/// a user toggle (UserDefaults, shared with the Settings `@AppStorage` switch).
enum AudioFeedback {
    static let enabledKey = "completionSoundEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static func playFocusComplete() {
        guard isEnabled else { return }
        NSSound(named: "Glass")?.play()
    }

    static func playBreakOver() {
        guard isEnabled else { return }
        NSSound(named: "Submarine")?.play()
    }
}
