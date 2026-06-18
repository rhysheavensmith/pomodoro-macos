import XCTest
@testable import PomodoroFocus

final class StatsServiceTests: XCTestCase {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()
    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
    private func service() -> StatsService { StatsService(calendar: cal) }

    func testTodayAggregates() {
        let sessions = [
            SessionStat(startedAt: at(2024, 1, 15, 9), focusedSeconds: 1500, wasCompleted: true, distractionCount: 1),
            SessionStat(startedAt: at(2024, 1, 15, 9, 30), focusedSeconds: 1500, wasCompleted: true, distractionCount: 0),
            SessionStat(startedAt: at(2024, 1, 15, 14), focusedSeconds: 600, wasCompleted: false, distractionCount: 2),
        ]
        let plans = [PlanStat(date: at(2024, 1, 15), planned: 5, completed: 2)]
        let s = service().summarize(sessions: sessions, plans: plans, distractions: [],
                                    today: at(2024, 1, 15), days: 7)
        XCTAssertEqual(s.todayFocusedPomodoros, 2)
        XCTAssertEqual(s.todayFocusHours, 1.0, accuracy: 0.0001) // 3600s
        XCTAssertEqual(s.todayCompletionRate, 0.4, accuracy: 0.0001)
        XCTAssertEqual(s.todayDistractions, 3)
        XCTAssertEqual(s.totalCompletedPomodoros, 2)
    }

    func testTimeOfDayAndBestHour() {
        let sessions = [
            SessionStat(startedAt: at(2024, 1, 15, 9), focusedSeconds: 1500, wasCompleted: true),
            SessionStat(startedAt: at(2024, 1, 16, 9, 45), focusedSeconds: 1500, wasCompleted: true),
            SessionStat(startedAt: at(2024, 1, 16, 14), focusedSeconds: 1500, wasCompleted: true),
        ]
        let s = service().summarize(sessions: sessions, plans: [], distractions: [],
                                    today: at(2024, 1, 16), days: 7)
        XCTAssertEqual(s.timeOfDay.count, 24)
        XCTAssertEqual(s.timeOfDay[9].completedCount, 2)
        XCTAssertEqual(s.timeOfDay[14].completedCount, 1)
        XCTAssertEqual(s.bestFocusStartHour, 9)
        XCTAssertEqual(s.bestFocusHourRange, "9–11am")
    }

    func testWeekdayAndStrongest() {
        // Jan 15 2024 = Monday (wd 2), Jan 17 = Wednesday (wd 4).
        let sessions = [
            SessionStat(startedAt: at(2024, 1, 15, 10), focusedSeconds: 1500, wasCompleted: true),
            SessionStat(startedAt: at(2024, 1, 15, 11), focusedSeconds: 1500, wasCompleted: true),
            SessionStat(startedAt: at(2024, 1, 17, 10), focusedSeconds: 1500, wasCompleted: true),
        ]
        let s = service().summarize(sessions: sessions, plans: [], distractions: [],
                                    today: at(2024, 1, 17), days: 7)
        XCTAssertEqual(s.weekday.count, 7)
        XCTAssertEqual(s.weekday.first { $0.weekday == 2 }?.completedCount, 2)
        XCTAssertEqual(s.weekday.first { $0.weekday == 4 }?.completedCount, 1)
        XCTAssertEqual(s.strongestWeekday, 2)
    }

    func testPlanAccuracy() {
        let plans = [
            PlanStat(date: at(2024, 1, 14), planned: 5, completed: 2),
            PlanStat(date: at(2024, 1, 15), planned: 3, completed: 4),
        ]
        let s = service().summarize(sessions: [], plans: plans, distractions: [],
                                    today: at(2024, 1, 15), days: 7)
        XCTAssertEqual(s.planAccuracy.planned, 8)
        XCTAssertEqual(s.planAccuracy.completed, 6)
        XCTAssertEqual(s.planAccuracy.delta, -2)
        XCTAssertEqual(s.planAccuracy.ratio, 0.75, accuracy: 0.0001)
    }

    func testDistractionsByAppAggregatedAndSorted() {
        let distractions = [
            DistractionStat(appName: "Slack", count: 3),
            DistractionStat(appName: "Twitter", count: 1),
            DistractionStat(appName: "Slack", count: 2),
        ]
        let s = service().summarize(sessions: [], plans: [], distractions: distractions,
                                    today: at(2024, 1, 15), days: 7)
        XCTAssertEqual(s.distractionsByApp.count, 2)
        XCTAssertEqual(s.distractionsByApp[0], AppCount(appName: "Slack", count: 5))
        XCTAssertEqual(s.distractionsByApp[1], AppCount(appName: "Twitter", count: 1))
    }

    func testDailyFocusHoursZeroFilled() {
        let sessions = [
            SessionStat(startedAt: at(2024, 1, 13, 9), focusedSeconds: 1800, wasCompleted: true),
            SessionStat(startedAt: at(2024, 1, 15, 9), focusedSeconds: 3600, wasCompleted: true),
        ]
        let s = service().summarize(sessions: sessions, plans: [], distractions: [],
                                    today: at(2024, 1, 15), days: 3)
        XCTAssertEqual(s.dailyFocusHours.count, 3)
        XCTAssertEqual(s.dailyFocusHours[0].date, cal.startOfDay(for: at(2024, 1, 13)))
        XCTAssertEqual(s.dailyFocusHours[0].hours, 0.5, accuracy: 0.0001)
        XCTAssertEqual(s.dailyFocusHours[1].hours, 0.0, accuracy: 0.0001)  // Jan 14 zero-filled
        XCTAssertEqual(s.dailyFocusHours[2].hours, 1.0, accuracy: 0.0001)
    }
}
