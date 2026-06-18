# Daily Journaling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a daily Journal tab where the user writes a structured three-prompt reflection per day, browses/edits past entries, and is nudged by an opt-in evening reminder.

**Architecture:** A journal entry is one-per-day, stored as optional fields on the existing `Day` `@Model` (the evening bookend to `dayIntention`). All decisions (normalization, completeness, history assembly) live in a new pure `Engine/JournalLogic.swift` (red-green TDD'd); the `@Model → value-type` boundary is a new `Projections.journalEntries` adapter (also TDD'd). `AppModel` is the only writer; `JournalView` reads via `@Query` + pure logic and writes through `AppModel.saveJournal`. The evening reminder reuses `NotificationScheduler`'s stable-identifier repeating pattern and the already-tested `ReminderTime`.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, XCTest, XcodeGen (project generated from `project.yml`). macOS 14+, menu-bar agent.

## Global Constraints

- **macOS 14+, SwiftUI + SwiftData, Swift 5.** No new dependencies.
- **Strict TDD for pure logic** (`JournalLogic`, `Projections`): write the failing test, run it and watch it fail for the right reason (RED), implement minimal code (GREEN), refactor. UI / `@Model` / OS-glue (`AppModel`, `NotificationScheduler`, `JournalView`, `SettingsView`) is verified by build + launch — there must be no logic left in it to unit-test.
- **SwiftData changes must be additive optional fields only** (no renames/removals) so automatic lightweight migration applies — there is no migration plan and `ModelContainer` creation `fatalError`s on failure. Each schema-touching task must launch the app to confirm it opens against the existing store.
- **Design tokens only:** colors/spacing/radii/fonts come from `Theme.*`; surfaces use `.warmCanvas()`, `.card()` (borderless — soft shadow, no stroke), `ScreenHeader`, `SoftPillButtonStyle`. Color is never the only signal — pair every state color with an SF Symbol + label. Honor `accessibilityReduceMotion` on animations.
- **Persistence funnels through `AppModel`;** views read with `@Query` and may call pure logic directly (as `PlanView` calls `DayLayout.build`).
- **Run `xcodegen generate` after adding/removing/renaming any file** (sources are globbed; the `.xcodeproj` is gitignored). Path to xcodegen: `/opt/homebrew/bin/xcodegen`.
- **Build:** `xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
- **Test:** `xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO` (single class: append `-only-testing:PomodoroFocusTests/<Class>`). Baseline before any change: **65 tests, 0 failures.**
- **Commit** after each task; end every commit message with the trailer:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

## File Structure

**Create:**
- `PomodoroFocus/Engine/JournalLogic.swift` — pure value types (`JournalDraft`, `JournalEntryInput`, `JournalEntrySummary`, `JournalCompleteness`) + decisions (`normalize`, `completeness`, `isEmpty`, `summaries`, `previewText`).
- `PomodoroFocusTests/JournalLogicTests.swift` — tests for the above.
- `PomodoroFocus/Views/JournalView.swift` — the Journal tab (today editor + history + edit sheet + `JournalPromptField`).

**Modify:**
- `PomodoroFocus/Models/Day.swift` — add four optional journal fields.
- `PomodoroFocus/Models/AppSettings.swift` — add `journalReminderEnabled`, `journalReminderMinutes`.
- `PomodoroFocus/Engine/Projections.swift` — add `journalEntries(from:)`.
- `PomodoroFocusTests/ProjectionsTests.swift` — add adapter test.
- `PomodoroFocus/App/AppModel.swift` — add `saveJournal`, `journalDraft`, `day(on:)`, `updateJournalReminder` + wiring.
- `PomodoroFocus/Engine/NotificationScheduler.swift` — add journal-reminder identifier/category + schedule/cancel.
- `PomodoroFocus/Views/SettingsView.swift` — add evening-journal-reminder controls.
- `PomodoroFocus/Views/RootWindowView.swift` — add the Journal tab.

---

### Task 1: `JournalLogic` pure logic

**Files:**
- Create: `PomodoroFocus/Engine/JournalLogic.swift`
- Test: `PomodoroFocusTests/JournalLogicTests.swift`

**Interfaces:**
- Produces:
  - `struct JournalDraft: Equatable` with `var wentWell/gotInWay/tomorrowFocus: String` (default `""`).
  - `enum JournalCompleteness { case empty, partial, complete }` (Equatable).
  - `struct JournalEntryInput: Equatable` — `let date: Date`, `let wentWell/gotInWay/tomorrowFocus: String?`.
  - `struct JournalEntrySummary: Equatable, Identifiable` — `date`, `wentWell/gotInWay/tomorrowFocus: String?`, `preview: String`, `completeness: JournalCompleteness`, `var id: Date { date }`.
  - `enum JournalLogic` with `normalize(_ String?) -> String?`, `completeness(_ JournalDraft) -> JournalCompleteness`, `isEmpty(_ JournalDraft) -> Bool`, `summaries(from [JournalEntryInput]) -> [JournalEntrySummary]`, `previewText(from String, limit: Int = 80) -> String`.

- [ ] **Step 1: Create the file with types + STUB bodies (so the test compiles and fails on assertions)**

Create `PomodoroFocus/Engine/JournalLogic.swift`:

```swift
import Foundation

/// The three reflection prompts as edited in the UI (raw, untrimmed).
struct JournalDraft: Equatable {
    var wentWell: String = ""
    var gotInWay: String = ""
    var tomorrowFocus: String = ""
}

/// How fully a day's reflection is filled in.
enum JournalCompleteness: Equatable { case empty, partial, complete }

/// A day's stored journal mirrored as a value type (no SwiftData), so the
/// history logic stays unit-testable without a ModelContainer.
struct JournalEntryInput: Equatable {
    let date: Date
    let wentWell: String?
    let gotInWay: String?
    let tomorrowFocus: String?
}

/// A history row ready for display.
struct JournalEntrySummary: Equatable, Identifiable {
    let date: Date
    let wentWell: String?
    let gotInWay: String?
    let tomorrowFocus: String?
    let preview: String
    let completeness: JournalCompleteness
    var id: Date { date }
}

/// Pure journaling decisions: normalization, completeness, history assembly.
/// Stubs until tests drive them.
enum JournalLogic {
    static func normalize(_ text: String?) -> String? { text }

    static func completeness(_ draft: JournalDraft) -> JournalCompleteness { .empty }

    static func isEmpty(_ draft: JournalDraft) -> Bool { completeness(draft) == .empty }

    static func summaries(from entries: [JournalEntryInput]) -> [JournalEntrySummary] { [] }

    static func previewText(from text: String, limit: Int = 80) -> String { text }
}
```

- [ ] **Step 2: Write the failing tests**

Create `PomodoroFocusTests/JournalLogicTests.swift`:

```swift
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
```

- [ ] **Step 3: Regenerate the project and run the new tests — verify they FAIL**

Run:
```bash
cd /Users/rhysheaven-smith/Projects/my-pomodoro/.claude/worktrees/feature+daily-journaling
/opt/homebrew/bin/xcodegen generate
xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO -only-testing:PomodoroFocusTests/JournalLogicTests 2>&1 | tail -25
```
Expected: builds, then **FAILS** — `testCompletenessClassifies`, `testSummariesExcludeEmptyAndSortDescending`, `testPreviewCollapsesNewlinesAndTruncates` fail their assertions (stubs return `.empty` / `[]` / unchanged text). `testNormalizeTrimsAndDropsBlank` also fails (stub returns input). This is RED for the right reason.

- [ ] **Step 4: Implement the real logic**

Replace the `enum JournalLogic { ... }` body in `JournalLogic.swift` with:

```swift
enum JournalLogic {
    /// Trim whitespace/newlines; blank → nil.
    static func normalize(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    static func completeness(_ draft: JournalDraft) -> JournalCompleteness {
        let filled = [draft.wentWell, draft.gotInWay, draft.tomorrowFocus]
            .compactMap(normalize).count
        switch filled {
        case 0: return .empty
        case 3: return .complete
        default: return .partial
        }
    }

    static func isEmpty(_ draft: JournalDraft) -> Bool {
        completeness(draft) == .empty
    }

    static func summaries(from entries: [JournalEntryInput]) -> [JournalEntrySummary] {
        entries.compactMap(summary(from:)).sorted { $0.date > $1.date }
    }

    /// nil when the entry has no content in any field.
    private static func summary(from entry: JournalEntryInput) -> JournalEntrySummary? {
        let well = normalize(entry.wentWell)
        let blocked = normalize(entry.gotInWay)
        let next = normalize(entry.tomorrowFocus)
        let filled = [well, blocked, next].compactMap { $0 }
        guard let first = filled.first else { return nil }
        return JournalEntrySummary(
            date: entry.date,
            wentWell: well, gotInWay: blocked, tomorrowFocus: next,
            preview: previewText(from: first),
            completeness: filled.count == 3 ? .complete : .partial
        )
    }

    static func previewText(from text: String, limit: Int = 80) -> String {
        let collapsed = text.replacingOccurrences(of: "\n", with: " ")
        guard collapsed.count > limit else { return collapsed }
        return String(collapsed.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
```

- [ ] **Step 5: Run the tests — verify they PASS**

Run:
```bash
xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO -only-testing:PomodoroFocusTests/JournalLogicTests 2>&1 | tail -8
```
Expected: **PASS** — `Executed 5 tests, with 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add PomodoroFocus/Engine/JournalLogic.swift PomodoroFocusTests/JournalLogicTests.swift PomodoroFocus.xcodeproj/project.pbxproj
git commit -m "$(printf 'Add pure JournalLogic (normalize, completeness, history)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```
(The `.pbxproj` is gitignored, so the `git add` of it is a no-op — included only in case the ignore changes. If git reports it ignored, ignore the warning.)

---

### Task 2: `Day` journal fields

**Files:**
- Modify: `PomodoroFocus/Models/Day.swift`

**Interfaces:**
- Produces (on `Day`): `var journalWentWell: String?`, `var journalGotInWay: String?`, `var journalTomorrowFocus: String?`, `var journaledAt: Date?`. All optional, default `nil`.

- [ ] **Step 1: Add the fields**

In `PomodoroFocus/Models/Day.swift`, after the `dayIntention` property (line 13) add:

```swift
    // MARK: Evening reflection (journal) — the bookend to dayIntention.
    var journalWentWell: String?
    var journalGotInWay: String?
    var journalTomorrowFocus: String?
    /// First time any journal field was saved non-empty (nil = not journaled).
    var journaledAt: Date?
```

The existing `init(date:plannedAt:dayIntention:)` does **not** need new parameters — SwiftData defaults the new optionals to `nil`. Leave `init` unchanged.

- [ ] **Step 2: Regenerate, build, and run the full suite**

Run:
```bash
/opt/homebrew/bin/xcodegen generate
xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO 2>&1 | tail -6
```
Expected: **PASS** — `Executed 70 tests, with 0 failures` (65 prior + 5 from Task 1).

- [ ] **Step 3: Launch the app to confirm the additive migration opens the existing store**

Run:
```bash
xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
APP=$(find ~/Library/Developer/Xcode/DerivedData/PomodoroFocus-*/Build/Products/Debug -maxdepth 1 -name 'PomodoroFocus.app' | head -1)
open "$APP"
```
Expected: the menu-bar icon appears with no crash (additive optional fields → automatic lightweight migration). Quit the app afterward (menu-bar → Quit, or `osascript -e 'quit app "Pomodoro Focus"'`).

- [ ] **Step 4: Commit**

```bash
git add PomodoroFocus/Models/Day.swift
git commit -m "$(printf 'Add journal fields to Day model\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 3: `Projections.journalEntries` adapter

**Files:**
- Modify: `PomodoroFocus/Engine/Projections.swift`
- Test: `PomodoroFocusTests/ProjectionsTests.swift`

**Interfaces:**
- Consumes: `Day` journal fields (Task 2), `JournalEntryInput` (Task 1).
- Produces: `Projections.journalEntries(from days: [Day]) -> [JournalEntryInput]`.

- [ ] **Step 1: Add a STUB to `Projections.swift`**

In `PomodoroFocus/Engine/Projections.swift`, before the closing `}` of `enum Projections`, add:

```swift
    static func journalEntries(from days: [Day]) -> [JournalEntryInput] { [] }
```

- [ ] **Step 2: Write the failing test**

In `PomodoroFocusTests/ProjectionsTests.swift`, before the final closing `}`, add:

```swift
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
```

- [ ] **Step 3: Run the test — verify it FAILS**

Run:
```bash
/opt/homebrew/bin/xcodegen generate
xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO -only-testing:PomodoroFocusTests/ProjectionsTests/testJournalEntriesMapsDayFields 2>&1 | tail -15
```
Expected: **FAIL** — `entries.count` is 0 (stub returns `[]`).

- [ ] **Step 4: Implement**

Replace the stub line with:

```swift
    static func journalEntries(from days: [Day]) -> [JournalEntryInput] {
        days.map {
            JournalEntryInput(
                date: $0.date,
                wentWell: $0.journalWentWell,
                gotInWay: $0.journalGotInWay,
                tomorrowFocus: $0.journalTomorrowFocus
            )
        }
    }
```

- [ ] **Step 5: Run the test — verify it PASSES**

Run:
```bash
xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO -only-testing:PomodoroFocusTests/ProjectionsTests 2>&1 | tail -6
```
Expected: **PASS** — `Executed 5 tests, with 0 failures` (4 existing + 1 new).

- [ ] **Step 6: Commit**

```bash
git add PomodoroFocus/Engine/Projections.swift PomodoroFocusTests/ProjectionsTests.swift
git commit -m "$(printf 'Add Projections.journalEntries Day adapter\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 4: `AppModel` journal commands

**Files:**
- Modify: `PomodoroFocus/App/AppModel.swift`

**Interfaces:**
- Consumes: `JournalDraft`, `JournalLogic` (Task 1); `Day` fields (Task 2).
- Produces:
  - `func journalDraft(for day: Day) -> JournalDraft`
  - `func saveJournal(for day: Day, draft: JournalDraft)`
  - `func day(on date: Date) -> Day?`

- [ ] **Step 1: Add the methods**

In `PomodoroFocus/App/AppModel.swift`, after `setIntention(_:)` (ends line 102) add:

```swift
    // MARK: - Journal

    /// Load a day's stored reflection into an editable draft.
    func journalDraft(for day: Day) -> JournalDraft {
        JournalDraft(
            wentWell: day.journalWentWell ?? "",
            gotInWay: day.journalGotInWay ?? "",
            tomorrowFocus: day.journalTomorrowFocus ?? ""
        )
    }

    /// Persist a draft onto a day. Normalizes blanks to nil and stamps
    /// `journaledAt` on the first non-empty save.
    func saveJournal(for day: Day, draft: JournalDraft) {
        guard let ctx = modelContext else { return }
        day.journalWentWell = JournalLogic.normalize(draft.wentWell)
        day.journalGotInWay = JournalLogic.normalize(draft.gotInWay)
        day.journalTomorrowFocus = JournalLogic.normalize(draft.tomorrowFocus)
        if day.journaledAt == nil && !JournalLogic.isEmpty(draft) {
            day.journaledAt = Date()
        }
        try? ctx.save()
    }

    /// Fetch the persisted Day for a given calendar date (for editing history).
    func day(on date: Date) -> Day? {
        guard let ctx = modelContext else { return nil }
        let start = Calendar.current.startOfDay(for: date)
        return try? ctx.fetch(FetchDescriptor<Day>(predicate: #Predicate { $0.date == start })).first
    }
```

- [ ] **Step 2: Build and run the full suite**

Run:
```bash
/opt/homebrew/bin/xcodegen generate
xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO 2>&1 | tail -6
```
Expected: **PASS** — `Executed 71 tests, with 0 failures`.

- [ ] **Step 3: Commit**

```bash
git add PomodoroFocus/App/AppModel.swift
git commit -m "$(printf 'Add AppModel journal load/save commands\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 5: Evening journal reminder (settings field + scheduler + wiring)

**Files:**
- Modify: `PomodoroFocus/Models/AppSettings.swift`
- Modify: `PomodoroFocus/Engine/NotificationScheduler.swift`
- Modify: `PomodoroFocus/App/AppModel.swift`

**Interfaces:**
- Produces (on `AppSettings`): `var journalReminderEnabled: Bool`, `var journalReminderMinutes: Int`.
- Produces (on `NotificationScheduler`): `func scheduleJournalReminder(atMinutesFromMidnight: Int)`, `func cancelJournalReminder()`, `Identifier.journalReminder`, `Category.journalReminder`.
- Produces (on `AppModel`): `private func updateJournalReminder()`, called from `configure()` and `applySettings()`.

- [ ] **Step 1: Add the AppSettings fields**

In `PomodoroFocus/Models/AppSettings.swift`, after `streakRiskNudgeEnabled` (line 21) add:

```swift
    /// Whether the evening "reflect on your day" journal reminder is enabled.
    var journalReminderEnabled: Bool
    /// Minutes from midnight for the journal reminder (1260 = 21:00).
    var journalReminderMinutes: Int
```

In `init()`, after `self.streakRiskNudgeEnabled = true` (line 47) add:

```swift
        self.journalReminderEnabled = true
        self.journalReminderMinutes = 21 * 60
```

- [ ] **Step 2: Add the scheduler methods + category**

In `PomodoroFocus/Engine/NotificationScheduler.swift`:

(a) In `enum Identifier`, after `streakRisk` (line 27) add:
```swift
        /// Evening "reflect on your day" journal reminder.
        static let journalReminder = "com.pomodorofocus.notification.journalReminder"
```

(b) In `enum Category`, after `streakRisk` (line 41) add:
```swift
        static let journalReminder = "JOURNAL_REMINDER"
```

(c) In `registerCategories()`, before the `center.setNotificationCategories([` call (line 239), add:
```swift
        let journalCategory = UNNotificationCategory(
            identifier: Category.journalReminder,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
```
and add `journalCategory,` to the array passed to `center.setNotificationCategories([...])`.

(d) After `cancelStreakRisk()` (ends line 183) add:
```swift
    // MARK: - Journal reminder (daily, repeating)

    /// Schedules a daily evening reminder to journal. Reuses the stable
    /// `Identifier.journalReminder`, so re-scheduling (e.g. after a settings
    /// change) replaces rather than stacks.
    func scheduleJournalReminder(atMinutesFromMidnight minutes: Int) {
        let content = makeContent(
            title: "Reflect on your day",
            body: "What went well, what got in the way, and tomorrow's focus.",
            categoryIdentifier: Category.journalReminder
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents(fromMinutesPastMidnight: minutes),
            repeats: true
        )
        let request = UNNotificationRequest(
            identifier: Identifier.journalReminder,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    /// Cancels the journal reminder (pending and delivered).
    func cancelJournalReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Identifier.journalReminder])
        center.removeDeliveredNotifications(withIdentifiers: [Identifier.journalReminder])
    }
```

- [ ] **Step 3: Wire it into AppModel**

In `PomodoroFocus/App/AppModel.swift`:

(a) In `configure(context:)`, after `updateStreakRiskNudge()` (line 52) add:
```swift
        updateJournalReminder()
```

(b) In `applySettings()`, after `updateStreakRiskNudge()` (line 299) add:
```swift
        updateJournalReminder()
```

(c) After the `updateStreakRiskNudge()` method (ends line 292) add:
```swift
    private func updateJournalReminder() {
        if settings.journalReminderEnabled {
            notifications.scheduleJournalReminder(atMinutesFromMidnight: settings.journalReminderMinutes)
        } else {
            notifications.cancelJournalReminder()
        }
    }
```

- [ ] **Step 4: Build, test, and launch**

Run:
```bash
/opt/homebrew/bin/xcodegen generate
xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO 2>&1 | tail -6
```
Expected: **PASS** — `Executed 71 tests, with 0 failures` (AppSettings is a schema change but additive optional/defaulted; no new unit tests).

Then launch to confirm the store still opens (additive `AppSettings` fields):
```bash
xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
APP=$(find ~/Library/Developer/Xcode/DerivedData/PomodoroFocus-*/Build/Products/Debug -maxdepth 1 -name 'PomodoroFocus.app' | head -1)
open "$APP"
```
Expected: launches without crash. Quit afterward.

- [ ] **Step 5: Commit**

```bash
git add PomodoroFocus/Models/AppSettings.swift PomodoroFocus/Engine/NotificationScheduler.swift PomodoroFocus/App/AppModel.swift
git commit -m "$(printf 'Add evening journal reminder scheduling\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 6: SettingsView journal-reminder controls

**Files:**
- Modify: `PomodoroFocus/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `AppSettings.journalReminderEnabled/journalReminderMinutes` (Task 5), `ReminderTime`, `app.applySettings()`.

- [ ] **Step 1: Add the controls to the "Alerts" section**

In `PomodoroFocus/Views/SettingsView.swift`, inside `Section("Alerts")` (after the streak-risk toggle, line 47) add:

```swift
                Toggle("Evening journal reminder", isOn: $settings.journalReminderEnabled)
                    .onChange(of: settings.journalReminderEnabled) { app.applySettings() }
                DatePicker("Journal reminder time", selection: journalReminderBinding,
                           displayedComponents: .hourAndMinute)
                    .disabled(!settings.journalReminderEnabled)
```

- [ ] **Step 2: Add the binding**

After the `reminderBinding` computed property (ends line 139) add:

```swift
    private var journalReminderBinding: Binding<Date> {
        Binding(
            get: {
                let c = ReminderTime.components(fromMinutes: app.settings.journalReminderMinutes)
                return Calendar.current.date(bySettingHour: c.hour, minute: c.minute, second: 0, of: Date()) ?? Date()
            },
            set: { newDate in
                let comp = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                app.settings.journalReminderMinutes = ReminderTime.minutes(hour: comp.hour ?? 21, minute: comp.minute ?? 0)
                app.applySettings()
            }
        )
    }
```

- [ ] **Step 3: Build, test, and verify by launch**

Run:
```bash
/opt/homebrew/bin/xcodegen generate
xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO 2>&1 | tail -6
```
Expected: **PASS** — `Executed 71 tests, with 0 failures`.

Launch, open Settings (menu bar → window → Settings tab), and confirm the "Evening journal reminder" toggle + "Journal reminder time" picker appear under Alerts, the time defaults to 9:00 PM, and the picker disables when the toggle is off. Quit afterward.

- [ ] **Step 4: Commit**

```bash
git add PomodoroFocus/Views/SettingsView.swift
git commit -m "$(printf 'Add journal reminder controls to Settings\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 7: Journal tab + today editor

**Files:**
- Create: `PomodoroFocus/Views/JournalView.swift`
- Modify: `PomodoroFocus/Views/RootWindowView.swift`

**Interfaces:**
- Consumes: `app.ensureToday()`, `app.journalDraft(for:)`, `app.saveJournal(for:draft:)` (Task 4); `JournalDraft` (Task 1); design tokens/surfaces.
- Produces: `struct JournalView` (the tab), `fileprivate struct JournalPromptField`.

- [ ] **Step 1: Create `JournalView.swift` (today editor + prompt field; history is a stub for Task 8)**

Create `PomodoroFocus/Views/JournalView.swift`:

```swift
import SwiftUI
import SwiftData

/// The evening reflection: a structured journal entry per day, plus browsable
/// history. The bookend to the morning intention set in Plan.
struct JournalView: View {
    @Environment(AppModel.self) private var app
    @Query private var allDays: [Day]

    @State private var draft = JournalDraft()
    @State private var todayIntention: String?
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                ScreenHeader(eyebrow: "REFLECT", title: "Journal")
                todayCard
                historySection
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .warmCanvas()
        .onAppear(perform: loadToday)
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if let intention = todayIntention, !intention.isEmpty {
                Label("This morning: \(intention)", systemImage: "target")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            JournalPromptField(label: "What went well", text: $draft.wentWell)
            JournalPromptField(label: "What got in the way", text: $draft.gotInWay)
            JournalPromptField(label: "Tomorrow's focus", text: $draft.tomorrowFocus)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .onChange(of: draft) { saveToday() }
    }

    // Filled in by Task 8.
    @ViewBuilder private var historySection: some View { EmptyView() }

    private func loadToday() {
        guard !loaded, let day = app.ensureToday() else { return }
        draft = app.journalDraft(for: day)
        todayIntention = day.dayIntention
        loaded = true
    }

    private func saveToday() {
        guard loaded, let day = app.ensureToday() else { return }
        app.saveJournal(for: day, draft: draft)
    }
}

/// A labelled, carded multiline prompt field shared by the today and history editors.
fileprivate struct JournalPromptField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 64)
                .padding(Theme.Spacing.xs)
                .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).strokeBorder(.quaternary))
        }
    }
}
```

- [ ] **Step 2: Add the Journal tab to `RootWindowView`**

In `PomodoroFocus/Views/RootWindowView.swift`:

(a) Change the `Tab` enum (line 5) to:
```swift
    enum Tab: Hashable { case plan, journal, dashboard, settings }
```

(b) After the `PlanView()` `.tag(Tab.plan)` block (line 14) insert:
```swift
                JournalView()
                    .tabItem { Label("Journal", systemImage: "book.closed") }
                    .tag(Tab.journal)
```

- [ ] **Step 3: Build, test, and verify by launch**

Run:
```bash
/opt/homebrew/bin/xcodegen generate
xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO 2>&1 | tail -6
```
Expected: **PASS** — `Executed 71 tests, with 0 failures`.

Launch, open the window from the menu bar, and confirm: a **Journal** tab appears between Plan and Dashboard; it shows the REFLECT/Journal header, this-morning's intention (if set in Plan), and three prompt editors. Type into each, switch to another tab and back (or quit + relaunch) and confirm the text persists. Quit afterward.

- [ ] **Step 4: Commit**

```bash
git add PomodoroFocus/Views/JournalView.swift PomodoroFocus/Views/RootWindowView.swift
git commit -m "$(printf 'Add Journal tab with today reflection editor\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 8: Journal history — browse + edit past entries

**Files:**
- Modify: `PomodoroFocus/Views/JournalView.swift`

**Interfaces:**
- Consumes: `@Query allDays`, `JournalLogic.summaries`, `Projections.journalEntries` (Tasks 1, 3); `app.day(on:)`, `app.journalDraft(for:)`, `app.saveJournal(for:draft:)` (Task 4).

- [ ] **Step 1: Add history state, the derived list, the section, and the edit sheet**

In `PomodoroFocus/Views/JournalView.swift`:

(a) Add state below `@State private var loaded = false`:
```swift
    @State private var editingDate: Date?
```

(b) Replace the `historySection` stub with:
```swift
    private var history: [JournalEntrySummary] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return JournalLogic.summaries(from: Projections.journalEntries(from: allDays))
            .filter { $0.date != todayStart }
    }

    @ViewBuilder private var historySection: some View {
        if !history.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("PAST ENTRIES")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(Theme.Palette.focus.opacity(0.75))
                ForEach(history) { entry in
                    Button { editingDate = entry.date } label: { historyRow(entry) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func historyRow(_ entry: JournalEntrySummary) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: entry.completeness == .complete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(entry.completeness == .complete ? Theme.Palette.accent : .secondary)
                .accessibilityLabel(entry.completeness == .complete ? "Complete entry" : "Partial entry")
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(entry.date.formatted(.dateTime.weekday(.abbreviated).month().day()))
                    .font(.subheadline.weight(.semibold))
                Text(entry.preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
```

(c) Attach the edit sheet — add this modifier to the `ScrollView` in `body`, right after `.onAppear(perform: loadToday)`:
```swift
        .sheet(item: $editingDate) { date in
            JournalEntryEditor(date: date)
                .environment(app)
        }
```

(d) Make `Date` usable as a sheet item by adding, at the bottom of the file (outside any type):
```swift
extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSinceReferenceDate }
}
```

(e) Add the editor view at the bottom of the file:
```swift
/// Edits a single past day's reflection in a sheet; autosaves on change.
fileprivate struct JournalEntryEditor: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let date: Date

    @State private var draft = JournalDraft()
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ScreenHeader(eyebrow: "ENTRY",
                         title: date.formatted(.dateTime.weekday(.wide).month().day()))
            JournalPromptField(label: "What went well", text: $draft.wentWell)
            JournalPromptField(label: "What got in the way", text: $draft.gotInWay)
            JournalPromptField(label: "Tomorrow's focus", text: $draft.tomorrowFocus)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(SoftPillButtonStyle(tint: Theme.Palette.accent))
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(minWidth: 440, minHeight: 460, alignment: .leading)
        .warmCanvas()
        .onChange(of: draft) { save() }
        .onAppear {
            guard !loaded, let day = app.day(on: date) else { return }
            draft = app.journalDraft(for: day)
            loaded = true
        }
    }

    private func save() {
        guard loaded, let day = app.day(on: date) else { return }
        app.saveJournal(for: day, draft: draft)
    }
}
```

- [ ] **Step 2: Build, test, and verify by launch**

Run:
```bash
/opt/homebrew/bin/xcodegen generate
xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO 2>&1 | tail -6
```
Expected: **PASS** — `Executed 71 tests, with 0 failures`.

Launch and verify: with at least one prior day journaled, the Journal tab shows a **PAST ENTRIES** list (today excluded), each row with a completeness icon + label, date, and a one/two-line preview. Tapping a row opens an editor sheet pre-filled with that day's text; editing and closing persists the change (the row preview/icon updates). Quit afterward.

> If there is no prior journaled day to see history, create one: in the app, journal today, then quit. Re-launch with the system clock unchanged shows it as "today" (excluded). To see a row without time travel, this is acceptable to verify visually by temporarily removing the `.filter { $0.date != todayStart }` line, confirming the row + edit sheet work, then restoring the filter and rebuilding. Note in your report that the today-exclusion filter was restored.

- [ ] **Step 3: Commit**

```bash
git add PomodoroFocus/Views/JournalView.swift
git commit -m "$(printf 'Add journal history browse and edit\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Self-Review

**Spec coverage** (against `docs/plans/2026-06-18-journaling-design.md`):
- Structured three prompts → `JournalDraft` (Task 1), UI fields (Tasks 7–8). ✓
- Fields on `Day` → Task 2. ✓
- Pure `JournalLogic` (normalize/completeness/history) → Task 1; `Projections` adapter → Task 3. ✓
- `AppModel.saveJournal` as sole writer → Task 4; UI writes route through it (Tasks 7–8). ✓
- Browse + edit history → Task 8. ✓
- Evening reminder (opt-in, default on, 21:00, reuses `ReminderTime` + stable id) → Task 5; settings UI → Task 6. ✓
- 4th tab, order Plan → Journal → Dashboard → Settings, `book.closed` → Task 7. ✓
- Autosave on change → Tasks 7–8. ✓ `JournalPromptField` reuse → Tasks 7–8. ✓
- Bookend to morning intention (read-only display) → Task 7. ✓
- Completeness as symbol + label (not color alone) → Task 8. ✓
- Deferred non-goals respected: no "skip nudge if done" (fixed-time reminder), no tab deep-link, no separate `JournalEntry` model, no media. ✓

**Type consistency:** `JournalDraft`, `JournalEntryInput`, `JournalEntrySummary`, `JournalCompleteness`, `JournalLogic.{normalize, completeness, isEmpty, summaries, previewText}`, `Projections.journalEntries`, `AppModel.{journalDraft, saveJournal, day(on:)}`, `NotificationScheduler.{scheduleJournalReminder, cancelJournalReminder, Identifier.journalReminder, Category.journalReminder}`, `AppSettings.{journalReminderEnabled, journalReminderMinutes}`, `Day.{journalWentWell, journalGotInWay, journalTomorrowFocus, journaledAt}` — names match across all tasks.

**Placeholder scan:** none — every code step contains complete code; every run step has an exact command + expected output.
