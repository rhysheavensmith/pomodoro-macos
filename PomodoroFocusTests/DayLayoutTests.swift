import XCTest
@testable import PomodoroFocus

final class DayLayoutTests: XCTestCase {

    /// Compact, Equatable description of a focus segment's runs: ["Write:4", "_:2"].
    private func runDesc(_ seg: DaySegment) -> [String] {
        guard case let .focus(runs) = seg else { return [] }
        return runs.map { "\($0.taskTitle ?? "_"):\($0.tomatoes.count)" }
    }

    func testEmptyTasksFillEmptySlotsAndKeepBreaks() {
        let segments: [TemplateSegment] = [.focus(2), .rest("Coffee", 20, "cup.and.saucer"), .focus(2)]
        let day = DayLayout.build(segments: segments, tasks: [])
        XCTAssertEqual(day.count, 3)
        XCTAssertEqual(runDesc(day[0]), ["_:2"])
        XCTAssertEqual(day[1], .rest(name: "Coffee", minutes: 20, symbol: "cup.and.saucer"))
        XCTAssertEqual(runDesc(day[2]), ["_:2"])
    }

    func testTasksFlowAcrossABreak() {
        let segments: [TemplateSegment] = [.focus(4), .rest("Coffee", 20, "cup.and.saucer"), .focus(4)]
        let day = DayLayout.build(segments: segments, tasks: [PlannedTask(title: "Write", planned: 6, done: 0)])
        XCTAssertEqual(runDesc(day[0]), ["Write:4"])
        XCTAssertEqual(day[1], .rest(name: "Coffee", minutes: 20, symbol: "cup.and.saucer"))
        XCTAssertEqual(runDesc(day[2]), ["Write:2", "_:2"])
    }

    func testMultipleTasksGroupIntoRunsWithinASet() {
        let segments: [TemplateSegment] = [.focus(4)]
        let tasks = [PlannedTask(title: "A", planned: 3, done: 0), PlannedTask(title: "B", planned: 1, done: 0)]
        XCTAssertEqual(runDesc(DayLayout.build(segments: segments, tasks: tasks)[0]), ["A:3", "B:1"])
    }

    func testDoneAndCurrentMarking() {
        let segments: [TemplateSegment] = [.focus(4)]
        let day = DayLayout.build(segments: segments, tasks: [PlannedTask(title: "Write", planned: 4, done: 2)])
        guard case let .focus(runs) = day[0], let run = runs.first else { return XCTFail() }
        XCTAssertEqual(run.tomatoes.map { $0.isDone }, [true, true, false, false])
        XCTAssertEqual(run.tomatoes.map { $0.isCurrent }, [false, false, true, false])
    }

    func testCurrentIsGlobalFirstIncompleteAcrossTasks() {
        let segments: [TemplateSegment] = [.focus(4), .rest("Lunch", 30, "fork.knife"), .focus(2)]
        let tasks = [PlannedTask(title: "A", planned: 4, done: 4), PlannedTask(title: "B", planned: 2, done: 0)]
        let day = DayLayout.build(segments: segments, tasks: tasks)
        if case let .focus(runs) = day[0] {
            XCTAssertTrue(runs.allSatisfy { $0.tomatoes.allSatisfy { $0.isDone } })
            XCTAssertFalse(runs.contains { $0.tomatoes.contains { $0.isCurrent } })
        } else { XCTFail() }
        if case let .focus(runs) = day[2], let b = runs.first {
            XCTAssertTrue(b.tomatoes.first?.isCurrent == true)
        } else { XCTFail() }
    }

    func testOverflowBeyondTemplateCapacity() {
        let segments: [TemplateSegment] = [.focus(4)]
        let day = DayLayout.build(segments: segments, tasks: [PlannedTask(title: "A", planned: 6, done: 0)])
        XCTAssertEqual(day.count, 2)
        XCTAssertEqual(runDesc(day[0]), ["A:4"])
        XCTAssertEqual(runDesc(day[1]), ["A:2"])
    }
}

final class TemplateScheduleTests: XCTestCase {
    private let template: [TemplateSegment] = [
        .focus(4), .rest("Coffee", 20, "cup.and.saucer.fill"),
        .focus(4), .rest("Lunch", 30, "fork.knife"),
        .focus(4), .rest("Walk", 20, "figure.walk"),
        .focus(2),
    ]

    func testRestAtSetBoundaries() {
        XCTAssertEqual(TemplateSchedule.restAfter(focusCount: 4, segments: template)?.name, "Coffee")
        XCTAssertEqual(TemplateSchedule.restAfter(focusCount: 4, segments: template)?.minutes, 20)
        XCTAssertEqual(TemplateSchedule.restAfter(focusCount: 8, segments: template)?.name, "Lunch")
        XCTAssertEqual(TemplateSchedule.restAfter(focusCount: 12, segments: template)?.name, "Walk")
    }

    func testNoRestMidSetOrAtEnd() {
        XCTAssertNil(TemplateSchedule.restAfter(focusCount: 2, segments: template))   // mid-set
        XCTAssertNil(TemplateSchedule.restAfter(focusCount: 14, segments: template))  // after final set
        XCTAssertNil(TemplateSchedule.restAfter(focusCount: 0, segments: template))
    }
}
