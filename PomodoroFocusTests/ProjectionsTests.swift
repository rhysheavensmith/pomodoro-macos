import XCTest
@testable import PomodoroFocus

final class ProjectionsTests: XCTestCase {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()
    private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func testSessionStatsMapsFields() {
        let task = TaskItem(title: "Write", plannedPomodoros: 3)
        let session = PomodoroSession(startedAt: at(2024, 1, 15, 9), plannedDuration: 1500, task: task)
        session.focusedDuration = 1500
        session.wasCompleted = true
        session.distractions = [
            DistractionEvent(appName: "Slack", appBundleID: "a"),
            DistractionEvent(appName: "Twitter", appBundleID: "b"),
        ]

        let stats = Projections.sessionStats(from: [session])
        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats[0].startedAt, at(2024, 1, 15, 9))
        XCTAssertEqual(stats[0].focusedSeconds, 1500, accuracy: 0.0001)
        XCTAssertTrue(stats[0].wasCompleted)
        XCTAssertEqual(stats[0].taskTitle, "Write")
        XCTAssertEqual(stats[0].distractionCount, 2)
    }

    func testDayStatsCountsCompletedPerDay() {
        func completed(_ d: Int, _ h: Int, done: Bool) -> PomodoroSession {
            let s = PomodoroSession(startedAt: at(2024, 1, d, h), plannedDuration: 1500)
            s.wasCompleted = done
            return s
        }
        let sessions = [
            completed(15, 9, done: true),
            completed(15, 10, done: true),
            completed(15, 11, done: false), // not completed -> ignored
            completed(14, 9, done: true),
        ]
        let stats = Projections.dayStats(from: sessions, calendar: cal)
        XCTAssertEqual(stats.count, 2)
        XCTAssertEqual(stats.first { $0.date == cal.startOfDay(for: at(2024, 1, 15)) }?.completedPomodoros, 2)
        XCTAssertEqual(stats.first { $0.date == cal.startOfDay(for: at(2024, 1, 14)) }?.completedPomodoros, 1)
    }

    func testPlanStatsSumsTaskAllocations() {
        let day = Day(date: at(2024, 1, 15))
        let t1 = TaskItem(title: "a", plannedPomodoros: 3); t1.completedPomodoros = 1
        let t2 = TaskItem(title: "b", plannedPomodoros: 2); t2.completedPomodoros = 2
        day.tasks = [t1, t2]

        let stats = Projections.planStats(from: [day])
        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats[0].planned, 5)
        XCTAssertEqual(stats[0].completed, 3)
        XCTAssertEqual(stats[0].date, at(2024, 1, 15))
    }

    func testDistractionStatsOnePerEvent() {
        let events = [
            DistractionEvent(appName: "Slack", appBundleID: "a"),
            DistractionEvent(appName: "Twitter", appBundleID: "b"),
            DistractionEvent(appName: "Slack", appBundleID: "a"),
        ]
        let stats = Projections.distractionStats(from: events)
        XCTAssertEqual(stats.count, 3)
        XCTAssertTrue(stats.allSatisfy { $0.count == 1 })
        XCTAssertEqual(stats.filter { $0.appName == "Slack" }.count, 2)
    }

    func testJournalEntriesMapsDayFields() {
        let day = Day(date: at(2026, 6, 17))
        day.journalWentWell = "shipped the plan"
        day.journalGotInWay = nil
        day.journalTomorrowFocus = "review"

        let entries = Projections.journalEntries(from: [day])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].date, at(2026, 6, 17))
        XCTAssertEqual(entries[0].wentWell, "shipped the plan")
        XCTAssertNil(entries[0].gotInWay)
        XCTAssertEqual(entries[0].tomorrowFocus, "review")
    }
}
