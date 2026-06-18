# Daily Journaling — Design

**Date:** 2026-06-18
**Status:** Approved, ready for implementation

## Summary

Add a daily **Journal** to Pomodoro Focus: a fourth top-level tab where the user
writes one structured reflection per day. It is the *evening bookend* to the
existing morning `dayIntention` — closing the *Hooked* "investment" loop. The
user can browse and edit past entries, and an opt-in evening notification nudges
them to reflect.

## Decisions

| Question | Decision |
|---|---|
| Entry shape | **Structured prompts** — three fixed fields |
| History | **Browse + edit** all past entries |
| Reminder | **Evening reminder** (opt-in, on by default) |
| Storage | **Extend the `Day` model** (Option A), not a separate entity |

The three prompts:
1. **What went well**
2. **What got in the way**
3. **Tomorrow's focus**

## Data model — fields on `Day`

A journal entry is strictly one-per-day, so it lives on the existing `Day`
aggregate alongside `dayIntention` and `plannedAt`:

```
Day:
  + journalWentWell:      String?
  + journalGotInWay:      String?
  + journalTomorrowFocus: String?
  + journaledAt:          Date?     // set on first non-empty save
```

This keeps history a plain `@Query` over days we already archive (no new
relationship, no join). All fields are optional → an **additive** SwiftData
change eligible for automatic lightweight migration. Because the
`ModelContainer` `fatalError`s on failure, we verify the app still launches
against an existing store as a build-time check (worst case in this personal,
local-only app: reset the dev store).

## Logic layer — `Engine/JournalLogic.swift` (pure, TDD'd)

A stateless namespace holding the value types and the real decisions, with a
matching `JournalLogicTests.swift`. Pure, value-in/value-out, no SwiftData/UI:

- `JournalDraft` — the three prompt strings as a value type.
- **`normalize(_:)`** — trims whitespace and collapses blank fields to `nil`, so
  an all-blank entry never persists as "journaled" (mirrors `BlocklistEditor`).
- **`completeness(_:)`** — derives `none / partial / complete` from a draft;
  drives the UI "done" badge.
- **`history(from days:)`** — `[Day] → [JournalEntrySummary]`: filters to days
  with content, sorts by date descending, builds a short preview snippet. A
  `Projections`-style adapter that keeps the DB away from the formatting/sorting.
- `JournalEntrySummary` — `date`, the fields, a `preview`, and completeness.

## Stateful shell (thin, verified by running)

- **`AppModel.saveJournal(for:draft:)`** — the *only* writer. Normalizes via
  `JournalLogic`, writes the fields onto the `Day`, stamps `journaledAt` on first
  non-empty save, `ctx.save()`s.
- **`NotificationScheduler.scheduleJournalReminder(at:)` / `cancelJournalReminder()`**
  — a daily repeating notification with a **stable identifier** (re-scheduling
  replaces, never stacks), matching the existing plan-reminder pattern. Time
  conversion reuses the already-tested `ReminderTime` from `SettingsLogic`.
- **`AppModel`** schedules or cancels the reminder on `configure()` (inside the
  idempotent guard) and whenever settings change.

## Settings — `AppSettings`

Mirroring `planReminderMinutes` + `streakRiskNudgeEnabled`:

```
AppSettings:
  + journalReminderEnabled: Bool   // default true (user opted in)
  + journalReminderMinutes: Int    // default 1260 (21:00)
```

`SettingsView` gains a toggle + time picker, calling `app.applySettings()`.

## UI — `Views/JournalView.swift`

Added to `RootWindowView` as the 4th tab; order **Plan → Journal → Dashboard →
Settings** (the two daily-ritual tabs adjacent). SF Symbol `book.closed`.

Token-driven throughout (`.warmCanvas()`, `ScreenHeader`, `.card()`, `Theme.*`):

- **Today's entry** — a `.card()` at top. Shows this morning's `dayIntention`
  read-only above the prompts ("This morning: …") as the bookend. Three labelled
  `TextEditor` prompts. **Autosave on change** through `AppModel.saveJournal`
  (like `TemplateEditorView`'s `.onChange` persistence — no manual Save button).
- **History** — scrollable list of past `JournalEntrySummary` cards (date +
  preview), each tappable to expand and edit in place via `AppModel.saveJournal(for:)`.
  Completeness shown as a checkmark **symbol + label** (not color alone).
- Gentle empty states; `accessibilityReduceMotion` honored on the expand animation.
- **`JournalPromptField`** — small reusable component (label + carded `TextEditor`)
  shared by the today editor and the history editors.

## Data flow

```
Day @Model ──@Query──▶ JournalLogic (pure) ──▶ value types ──▶ JournalView
                                                                   │ edits
                                          AppModel.saveJournal ◀────┘
                                                   │
                                                   ▼  ctx.save()
                                                 Day @Model
```

## Testing plan

**TDD (red-green-refactor) — `JournalLogicTests`:**
- `normalize`: blank/whitespace fields → `nil`; non-blank trimmed; all-blank draft → empty.
- `completeness`: none / partial / complete across field combinations.
- `history`: empty-content days excluded; sorted date-descending; preview snippet
  derived correctly; entries with any one field included.

Reminder-time conversion is already covered by `ReminderTimeTests` (reused, not
re-written).

**Verified by build + launch** (no logic left to unit-test): the SwiftData field
additions, `AppModel.saveJournal` wiring, `NotificationScheduler` scheduling, the
`SettingsView` controls, and `JournalView`/`JournalPromptField` rendering.

## Scope / non-goals (deferred refinements)

- The reminder fires at its fixed time **regardless of whether today is already
  journaled**. "Skip the nudge if done" needs daily re-evaluation — later, if wanted.
- Tapping the notification opens the main window but **does not auto-select the
  Journal tab** (`RootWindowView` selection is local `@State` with no
  deep-linking). Deep-linking is a separate follow-up.
- No separate `JournalEntry` model, no rich text, no media — three text prompts only.
