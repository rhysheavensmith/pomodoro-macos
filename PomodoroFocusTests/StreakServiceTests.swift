import XCTest
@testable import PomodoroFocus

final class StreakServiceTests: XCTestCase {

    // Fixed UTC Gregorian calendar so weekday math is deterministic.
    // Reference: 2024-01-01 is a Monday (weekday 2). 2024-01-15 is also a Monday.
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }
    private func service() -> StreakService { StreakService(calendar: cal) }
    private let allDays = [1, 2, 3, 4, 5, 6, 7]
    private let weekdaysOnly = [2, 3, 4, 5, 6] // Mon–Fri

    private func stats(_ days: [Int], month: Int = 1, year: Int = 2024, pomodoros: Int = 1) -> [DayStat] {
        days.map { DayStat(date: date(year, month, $0), completedPomodoros: pomodoros) }
    }

    func testNoHistory() {
        let s = service().snapshot(stats: [], today: date(2024, 1, 15), streakBar: 1, activeWeekdays: allDays)
        XCTAssertEqual(s.current, 0)
        XCTAssertEqual(s.longest, 0)
        XCTAssertFalse(s.isTodayQualified)
        XCTAssertNil(s.lastQualifiedDate)
        XCTAssertFalse(s.isAtRisk)
    }

    func testThreeConsecutiveEndingToday() {
        let s = service().snapshot(stats: stats([13, 14, 15]), today: date(2024, 1, 15), streakBar: 1, activeWeekdays: allDays)
        XCTAssertEqual(s.current, 3)
        XCTAssertTrue(s.isTodayQualified)
        XCTAssertEqual(s.lastQualifiedDate, date(2024, 1, 15))
        XCTAssertFalse(s.isAtRisk)
    }

    func testStreakPreservedWhileTodayInProgress() {
        // Done 12,13,14; today (15) not done yet but it's an active day.
        let s = service().snapshot(stats: stats([12, 13, 14]), today: date(2024, 1, 15), streakBar: 1, activeWeekdays: allDays)
        XCTAssertEqual(s.current, 3)
        XCTAssertFalse(s.isTodayQualified)
        XCTAssertTrue(s.isAtRisk)
        XCTAssertEqual(s.lastQualifiedDate, date(2024, 1, 14))
    }

    func testGapBreaksStreakWhenNoFreezeEarned() {
        // 11,12 done, 13 missed, 14,15 done. Streak before the miss is only 2,
        // so no freeze earned -> the miss breaks it. current = 14+15 = 2.
        let s = service().snapshot(stats: stats([11, 12, 14, 15]), today: date(2024, 1, 15), streakBar: 1, activeWeekdays: allDays)
        XCTAssertEqual(s.current, 2)
    }

    func testFreezeBridgesGapOnLongStreak() {
        // Qualified 3,4,5,6 then 8..15 (8 days). 7 missed, 2 missing (natural start).
        // Walking back: 8 qualified, freeze bridges the gap at day 7, then 4 more -> 12.
        let s = service().snapshot(stats: stats([3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15]),
                                   today: date(2024, 1, 15), streakBar: 1, activeWeekdays: allDays)
        XCTAssertEqual(s.current, 12)
        XCTAssertEqual(s.freezesBanked, 0) // the one earned freeze was spent bridging day 7
    }

    func testCleanSevenDayStreakBanksOneFreeze() {
        // 9..15 = 7 consecutive, nothing before -> natural start, freeze NOT spent.
        let s = service().snapshot(stats: stats([9, 10, 11, 12, 13, 14, 15]),
                                   today: date(2024, 1, 15), streakBar: 1, activeWeekdays: allDays)
        XCTAssertEqual(s.current, 7)
        XCTAssertEqual(s.freezesBanked, 1)
    }

    func testWeekendsOffDoNotBreakStreak() {
        // Mon–Fri active. Done Mon 8 .. Fri 12, then Sat/Sun off, then Mon 15.
        // Weekend is skipped (not a break). current = 8,9,10,11,12,15 = 6.
        let s = service().snapshot(stats: stats([8, 9, 10, 11, 12, 15]),
                                   today: date(2024, 1, 15), streakBar: 1, activeWeekdays: weekdaysOnly)
        XCTAssertEqual(s.current, 6)
    }

    func testStreakBarRequiresEnoughPomodoros() {
        // streakBar 3: a day with 2 pomodoros does NOT qualify.
        let mixed = [DayStat(date: date(2024, 1, 15), completedPomodoros: 2)]
        let s = service().snapshot(stats: mixed, today: date(2024, 1, 15), streakBar: 3, activeWeekdays: allDays)
        XCTAssertEqual(s.current, 0)
        XCTAssertFalse(s.isTodayQualified)
    }

    func testLongestStreakAcrossHistory() {
        // A 5-run (Jan 1–5), a gap, then a 3-run ending today (Jan 13–15).
        let s = service().snapshot(stats: stats([1, 2, 3, 4, 5, 13, 14, 15]),
                                   today: date(2024, 1, 15), streakBar: 1, activeWeekdays: allDays)
        XCTAssertEqual(s.current, 3)
        XCTAssertEqual(s.longest, 5)
    }

    func testMilestones() {
        let svc = service()
        XCTAssertEqual(svc.milestone(for: 3), 3)
        XCTAssertEqual(svc.milestone(for: 7), 7)
        XCTAssertEqual(svc.milestone(for: 30), 30)
        XCTAssertEqual(svc.milestone(for: 100), 100)
        XCTAssertNil(svc.milestone(for: 5))
        XCTAssertNil(svc.milestone(for: 0))
    }
}
