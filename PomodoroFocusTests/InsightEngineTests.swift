import XCTest
@testable import PomodoroFocus

final class InsightEngineTests: XCTestCase {

    private func makeSummary(
        distractionsByApp: [AppCount] = [],
        planAccuracy: PlanAccuracy = PlanAccuracy(planned: 0, completed: 0),
        bestFocusHourRange: String? = nil,
        bestFocusStartHour: Int? = nil,
        strongestWeekday: Int? = nil
    ) -> StatsSummary {
        StatsSummary(
            todayFocusedPomodoros: 0, todayFocusHours: 0, todayCompletionRate: 0, todayDistractions: 0,
            dailyFocusHours: [], timeOfDay: [], weekday: [], distractionsByApp: distractionsByApp,
            planAccuracy: planAccuracy, bestFocusHourRange: bestFocusHourRange,
            bestFocusStartHour: bestFocusStartHour, strongestWeekday: strongestWeekday,
            totalCompletedPomodoros: 0, totalFocusHours: 0
        )
    }

    func testNoDataYieldsNoInsight() {
        let engine = InsightEngine()
        XCTAssertTrue(engine.insights(from: makeSummary()).isEmpty)
        XCTAssertNil(engine.insightOfTheDay(from: makeSummary()))
    }

    func testFocusTimeInsight() {
        let s = makeSummary(bestFocusHourRange: "9–11am", bestFocusStartHour: 9)
        let top = InsightEngine().insightOfTheDay(from: s)
        XCTAssertEqual(top?.kind, .focusTime)
        XCTAssertTrue(top?.headline.contains("9–11am") == true || top?.detail.contains("9–11am") == true)
    }

    func testDistractionBeatsFocusTime() {
        // Distraction is more actionable than a focus-time observation -> ranks higher.
        let s = makeSummary(
            distractionsByApp: [AppCount(appName: "Slack", count: 8), AppCount(appName: "Twitter", count: 2)],
            bestFocusHourRange: "9–11am", bestFocusStartHour: 9
        )
        let top = InsightEngine().insightOfTheDay(from: s)
        XCTAssertEqual(top?.kind, .distraction)
        XCTAssertTrue(top?.detail.contains("Slack") == true)
        XCTAssertTrue(top?.detail.contains("80%") == true)
    }

    func testPlanningOverAllocationInsight() {
        let s = makeSummary(planAccuracy: PlanAccuracy(planned: 20, completed: 10))
        let insights = InsightEngine().insights(from: s)
        XCTAssertTrue(insights.contains { $0.kind == .planning })
        XCTAssertEqual(InsightEngine().insightOfTheDay(from: s)?.kind, .planning)
    }

    func testConsistencyInsightNamesWeekday() {
        let s = makeSummary(strongestWeekday: 2) // Monday
        let top = InsightEngine().insightOfTheDay(from: s)
        XCTAssertEqual(top?.kind, .consistency)
        XCTAssertTrue(top?.detail.contains("Monday") == true || top?.headline.contains("Monday") == true)
    }
}
