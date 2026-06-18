import Foundation
import SwiftData

/// Logged when the user switches to a blocklisted app during a pomodoro.
/// Feeds the stats dashboard (the "reward of the Hunt").
@Model
final class DistractionEvent {
    var timestamp: Date
    var appName: String
    var appBundleID: String
    /// How long the user stayed away before returning, in seconds.
    var secondsAway: TimeInterval

    var session: PomodoroSession?

    init(
        timestamp: Date = .now,
        appName: String,
        appBundleID: String,
        secondsAway: TimeInterval = 0,
        session: PomodoroSession? = nil
    ) {
        self.timestamp = timestamp
        self.appName = appName
        self.appBundleID = appBundleID
        self.secondsAway = secondsAway
        self.session = session
    }
}
