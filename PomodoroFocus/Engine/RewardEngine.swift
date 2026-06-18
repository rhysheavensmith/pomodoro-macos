import Foundation

/// Chooses which "variable reward" to surface when a pomodoro completes. The
/// variability is real, not RNG: a milestone trumps everything; otherwise a
/// fresh insight surfaces periodically; otherwise a simple progress line.
/// Stub until tests drive it.
enum RewardEngine {
    static func message(milestone: Int?, currentStreak: Int, insight: Insight?, todayCompleted: Int) -> String {
        if let milestone { return "🔥 \(milestone)-day streak!" }
        if let insight, todayCompleted % 3 == 0 { return insight.headline }
        return "\(todayCompleted) done today 🍅"
    }
}
