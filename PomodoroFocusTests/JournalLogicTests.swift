import XCTest
@testable import PomodoroFocus

final class JournalLogicTests: XCTestCase {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()
    private func at(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testNormalizeTrimsAndDropsBlank() {
        XCTAssertEqual(JournalLogic.normalize("  hello \n"), "hello")
        XCTAssertNil(JournalLogic.normalize("   "))
        XCTAssertNil(JournalLogic.normalize(""))
        XCTAssertNil(JournalLogic.normalize(nil))
    }

    func testCompletenessClassifies() {
        XCTAssertEqual(JournalLogic.completeness(JournalDraft()), .empty)
        XCTAssertEqual(JournalLogic.completeness(JournalDraft(wentWell: "   ")), .empty)
        XCTAssertEqual(JournalLogic.completeness(JournalDraft(wentWell: "x")), .partial)
        XCTAssertEqual(JournalLogic.completeness(JournalDraft(wentWell: "  ", gotInWay: "y")), .partial)
        XCTAssertEqual(
            JournalLogic.completeness(JournalDraft(wentWell: "a", gotInWay: "b", tomorrowFocus: "c")),
            .complete
        )
    }

    func testIsEmptyMatchesCompleteness() {
        XCTAssertTrue(JournalLogic.isEmpty(JournalDraft(gotInWay: "  ")))
        XCTAssertFalse(JournalLogic.isEmpty(JournalDraft(gotInWay: "y")))
    }

    func testSummariesExcludeEmptyAndSortDescending() {
        let entries = [
            JournalEntryInput(date: at(2026, 6, 16), wentWell: "older", gotInWay: nil, tomorrowFocus: nil),
            JournalEntryInput(date: at(2026, 6, 18), wentWell: nil, gotInWay: "  ", tomorrowFocus: nil),
            JournalEntryInput(date: at(2026, 6, 17), wentWell: "newer", gotInWay: "x", tomorrowFocus: "y"),
        ]
        let s = JournalLogic.summaries(from: entries)
        XCTAssertEqual(s.count, 2)                       // all-blank 6/18 excluded
        XCTAssertEqual(s[0].date, at(2026, 6, 17))       // sorted newest first
        XCTAssertEqual(s[1].date, at(2026, 6, 16))
        XCTAssertEqual(s[0].completeness, .complete)
        XCTAssertEqual(s[1].completeness, .partial)
        XCTAssertEqual(s[0].preview, "newer")            // first non-empty field
    }

    func testPreviewCollapsesNewlinesAndTruncates() {
        let multiline = JournalEntryInput(date: at(2026, 6, 18), wentWell: "line1\nline2",
                                          gotInWay: nil, tomorrowFocus: nil)
        XCTAssertEqual(JournalLogic.summaries(from: [multiline])[0].preview, "line1 line2")

        let long = JournalEntryInput(date: at(2026, 6, 18), wentWell: String(repeating: "a", count: 100),
                                     gotInWay: nil, tomorrowFocus: nil)
        let preview = JournalLogic.summaries(from: [long])[0].preview
        XCTAssertTrue(preview.hasSuffix("…"))
        XCTAssertEqual(preview.count, 81)                // 80 chars + ellipsis
    }
}
