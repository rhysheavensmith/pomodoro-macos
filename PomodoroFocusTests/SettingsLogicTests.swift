import XCTest
@testable import PomodoroFocus

final class ReminderTimeTests: XCTestCase {

    func testFormatMorning() {
        XCTAssertEqual(ReminderTime.format(minutesFromMidnight: 540), "9:00 AM")
    }
    func testFormatMidnightAndNoon() {
        XCTAssertEqual(ReminderTime.format(minutesFromMidnight: 0), "12:00 AM")
        XCTAssertEqual(ReminderTime.format(minutesFromMidnight: 720), "12:00 PM")
    }
    func testFormatEvening() {
        XCTAssertEqual(ReminderTime.format(minutesFromMidnight: 1230), "8:30 PM")
    }
    func testFormatPadsMinutes() {
        XCTAssertEqual(ReminderTime.format(minutesFromMidnight: 75), "1:15 AM")
    }
    func testComponentsRoundTrip() {
        XCTAssertEqual(ReminderTime.components(fromMinutes: 540).hour, 9)
        XCTAssertEqual(ReminderTime.components(fromMinutes: 1230).minute, 30)
        XCTAssertEqual(ReminderTime.minutes(hour: 20, minute: 30), 1230)
        XCTAssertEqual(ReminderTime.minutes(hour: 9, minute: 0), 540)
    }
}

final class BlocklistEditorTests: XCTestCase {

    func testAddsNew() {
        XCTAssertEqual(BlocklistEditor.adding("com.x", to: []), ["com.x"])
    }
    func testIgnoresExactDuplicate() {
        XCTAssertEqual(BlocklistEditor.adding("com.x", to: ["com.x"]), ["com.x"])
    }
    func testIgnoresCaseInsensitiveDuplicate() {
        XCTAssertEqual(BlocklistEditor.adding("COM.X", to: ["com.x"]), ["com.x"])
    }
    func testIgnoresBlank() {
        XCTAssertEqual(BlocklistEditor.adding("   ", to: ["com.x"]), ["com.x"])
    }
    func testRemovesCaseInsensitively() {
        XCTAssertEqual(BlocklistEditor.removing("COM.X", from: ["com.x", "com.y"]), ["com.y"])
    }
}
