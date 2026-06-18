import XCTest
@testable import PomodoroFocus

final class RewardEngineTests: XCTestCase {

    private func insight() -> Insight {
        Insight(headline: "You focus best 9–11am", detail: "…", kind: .focusTime)
    }

    func testMilestoneTrumpsEverything() {
        let msg = RewardEngine.message(milestone: 7, currentStreak: 7, insight: insight(), todayCompleted: 6)
        XCTAssertEqual(msg, "🔥 7-day streak!")
    }

    func testInsightSurfacesEveryThirdCompletion() {
        let msg = RewardEngine.message(milestone: nil, currentStreak: 4, insight: insight(), todayCompleted: 3)
        XCTAssertEqual(msg, "You focus best 9–11am")
    }

    func testProgressLineWhenNoInsight() {
        let msg = RewardEngine.message(milestone: nil, currentStreak: 4, insight: nil, todayCompleted: 2)
        XCTAssertEqual(msg, "2 done today 🍅")
    }

    func testProgressLineWhenNotThirdCompletion() {
        let msg = RewardEngine.message(milestone: nil, currentStreak: 4, insight: insight(), todayCompleted: 2)
        XCTAssertEqual(msg, "2 done today 🍅")
    }
}
