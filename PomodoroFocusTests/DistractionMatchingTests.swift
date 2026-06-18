import XCTest
@testable import PomodoroFocus

final class DistractionMatchingTests: XCTestCase {

    func testExactMatch() {
        XCTAssertTrue(DistractionMonitor.isBlocklisted("com.tinyspeck.slackmacgap",
                                                       in: ["com.tinyspeck.slackmacgap"]))
    }

    func testCaseInsensitiveMatch() {
        XCTAssertTrue(DistractionMonitor.isBlocklisted("com.Tinyspeck.Slack",
                                                       in: ["com.tinyspeck.slack"]))
    }

    func testNotInListIsFalse() {
        XCTAssertFalse(DistractionMonitor.isBlocklisted("com.apple.dt.Xcode",
                                                        in: ["com.tinyspeck.slack"]))
    }

    func testNilBundleIDIsFalse() {
        XCTAssertFalse(DistractionMonitor.isBlocklisted(nil, in: ["com.tinyspeck.slack"]))
    }

    func testEmptyListIsFalse() {
        XCTAssertFalse(DistractionMonitor.isBlocklisted("com.tinyspeck.slack", in: []))
    }
}
