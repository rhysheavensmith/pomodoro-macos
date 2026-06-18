import XCTest
@testable import PomodoroFocus

@MainActor
final class TimerEngineTests: XCTestCase {

    // MARK: starting work

    func testStartWorkEntersRunningWithFullDuration() {
        let engine = TimerEngine()
        engine.startWork(taskTitle: "Write spec", durationSeconds: 1500)
        XCTAssertEqual(engine.phase, .running)
        XCTAssertEqual(engine.secondsRemaining, 1500)
        XCTAssertEqual(engine.currentTaskTitle, "Write spec")
        XCTAssertTrue(engine.isActive)
    }

    func testStartWorkFiresFocusStarted() {
        let engine = TimerEngine()
        var started = false
        engine.onFocusStarted = { started = true }
        engine.startWork(taskTitle: nil, durationSeconds: 60)
        XCTAssertTrue(started)
    }

    // MARK: ticking

    func testTickDecrementsRemainingWhileRunning() {
        let engine = TimerEngine()
        engine.startWork(taskTitle: nil, durationSeconds: 1500)
        engine.tick()
        XCTAssertEqual(engine.secondsRemaining, 1499)
        XCTAssertEqual(engine.phase, .running)
    }

    func testFocusCompletionIncrementsCycleAndFiresCallback() {
        let engine = TimerEngine()
        var completed = 0
        engine.onFocusCompleted = { completed += 1 }
        engine.startWork(taskTitle: nil, durationSeconds: 2)
        engine.tick()                 // 1
        XCTAssertEqual(engine.phase, .running)
        engine.tick()                 // 0 -> complete
        XCTAssertEqual(engine.secondsRemaining, 0)
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(engine.completedInCycle, 1)
        XCTAssertEqual(completed, 1)
    }

    // MARK: breaks

    func testStartShortBreakEntersBreakPhase() {
        let engine = TimerEngine()
        engine.startBreak(isLong: false, durationSeconds: 300)
        XCTAssertEqual(engine.phase, .shortBreak)
        XCTAssertEqual(engine.secondsRemaining, 300)
    }

    func testStartLongBreakEntersLongBreakPhase() {
        let engine = TimerEngine()
        engine.startBreak(isLong: true, durationSeconds: 900)
        XCTAssertEqual(engine.phase, .longBreak)
    }

    func testBreakCompletionFiresBreakCallbackAndGoesIdle() {
        let engine = TimerEngine()
        var breakDone = 0
        engine.onBreakCompleted = { breakDone += 1 }
        engine.startBreak(isLong: false, durationSeconds: 1)
        engine.tick()                 // 0 -> complete
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(breakDone, 1)
        XCTAssertEqual(engine.completedInCycle, 0)  // breaks don't count as pomodoros
    }

    // MARK: pause / resume

    func testPausePreservesRemainingAndResumeContinues() {
        let engine = TimerEngine()
        engine.startWork(taskTitle: nil, durationSeconds: 100)
        engine.tick()                 // 99
        engine.pause()
        XCTAssertEqual(engine.phase, .paused)
        engine.tick()                 // no effect while paused
        XCTAssertEqual(engine.secondsRemaining, 99)
        engine.resume()
        XCTAssertEqual(engine.phase, .running)
        engine.tick()                 // 98
        XCTAssertEqual(engine.secondsRemaining, 98)
    }

    // MARK: skip

    func testSkipDuringFocusDoesNotCountAndGoesIdle() {
        let engine = TimerEngine()
        var focusDone = 0, breakDone = 0
        engine.onFocusCompleted = { focusDone += 1 }
        engine.onBreakCompleted = { breakDone += 1 }
        engine.startWork(taskTitle: nil, durationSeconds: 100)
        engine.skip()
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(engine.completedInCycle, 0)
        XCTAssertEqual(focusDone, 0)
        XCTAssertEqual(breakDone, 0)
    }

    func testSkipDuringBreakFiresBreakCompleted() {
        let engine = TimerEngine()
        var breakDone = 0
        engine.onBreakCompleted = { breakDone += 1 }
        engine.startBreak(isLong: false, durationSeconds: 300)
        engine.skip()
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(breakDone, 1)
    }

    // MARK: stop

    func testStopResetsToIdle() {
        let engine = TimerEngine()
        engine.startWork(taskTitle: "x", durationSeconds: 100)
        engine.tick()
        engine.stop()
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(engine.secondsRemaining, 0)
        XCTAssertFalse(engine.isActive)
    }

    // MARK: display

    func testDisplayTimeFormatsMinutesAndSeconds() {
        let engine = TimerEngine()
        engine.startWork(taskTitle: nil, durationSeconds: 65)
        XCTAssertEqual(engine.displayTime, "01:05")
    }

    func testIdleDisplayTimeIsZero() {
        let engine = TimerEngine()
        XCTAssertEqual(engine.displayTime, "00:00")
    }
}
