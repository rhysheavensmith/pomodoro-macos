# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Pomodoro Focus is a personal-use, single-user **native macOS menu-bar app** (SwiftUI + SwiftData) that fuses a Pomodoro timer, anti-distraction tracking, and a daily execution system, with gamification grounded in Nir Eyal's *Hooked* loop (streaks + a stats/insight dashboard). It runs as an `LSUIElement` agent: **no Dock icon** — the timer lives in the menu bar and the main window opens from there. Full product spec: `docs/plans/2026-06-18-pomodoro-focus-design.md`.

## Build, run & test

The `.xcodeproj` is **generated from `project.yml` via [XcodeGen](https://github.com/yonyz/XcodeGen)** — never hand-edit or commit it. Regenerate after adding, removing, or renaming any source file (sources are globbed by folder, so new files won't compile until you regenerate):

```sh
xcodegen generate                                                                 # after any file add/remove/rename
xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' test  CODE_SIGNING_ALLOWED=NO
```

Run a single test class or method by appending `-only-testing:` (tests are XCTest — `final class … : XCTestCase`):

```sh
xcodebuild ... test -only-testing:PomodoroFocusTests/StreakServiceTests
xcodebuild ... test -only-testing:PomodoroFocusTests/StreakServiceTests/testCleanSevenDayStreakBanksOneFreeze
```

There is no separate linter. Builds are local/unsigned (`CODE_SIGN_IDENTITY: "-"`), so no Developer Team is required.

## Architecture

Layered, with **`AppModel` (`PomodoroFocus/App/AppModel.swift`) as the single coordinator and dependency root**. There is no DI container or protocols: `AppModel` is a `@MainActor @Observable` instantiated once as App-scoped `@State`, injected everywhere via `@Environment(AppModel.self)`. It owns the engines as plain `let`s, holds the lone SwiftData `ModelContext`, is the **only writer** to the store, and is the only place orchestration/policy lives.

Data flows in **one direction**:

```
SwiftData @Model  ──Projections──▶  pure Engine logic  ──▶  value-type results
   (truth)          (adapter)        (decisions)              │
        ▲                                                     ▼
        └────────── AppModel methods (writes) ◀──  @Observable state on AppModel  ──▶  SwiftUI views
```

Views read persisted entities via `@Query` and read derived/app state via `AppModel`; **all mutations funnel through `AppModel` methods** — views never write to the context or touch engines directly. Pure engines never call back into `AppModel`, persistence, or views.

### Two persistence stores (deliberate split)

- **SwiftData** — per-day instance data. Five `@Model`s in one `Schema` (`PomodoroFocusApp.swift`): `Day → TaskItem → PomodoroSession → DistractionEvent` (cascade-owned chain) plus a singleton `AppSettings`. `DistractionEvent` hangs off the *session* (not the day) on purpose, so analytics can attribute distractions to specific tasks.
- **UserDefaults** — the reusable **day "rhythm"/template** (`[TemplateSegment]` JSON under key `dayTemplate.v1`, via `Engine/TemplateStore.swift`) and lightweight toggles (`completionSoundEnabled`, `PrefKeys.autoStartBreaks`). The rhythm is intentionally *not* a SwiftData entity — it's a value-type list kept out of the schema to avoid migrations and stay unit-testable without a `ModelContainer`.

### Engine layer: stateful shell vs. pure logic (the key pattern)

`PomodoroFocus/Engine/` is split into two halves, and the split is the central testability decision:

- **Stateful, side-effecting services** (the I/O shell): `TimerEngine` (the `@Observable` phase state machine — counts down in `tick()`, fires lifecycle closures, **has no policy**: it never auto-starts a break or persists anything), `DistractionMonitor` (watches `NSWorkspace` app-switches against a blocklist — requires **no Accessibility permission** by design), `NotificationScheduler`, plus stateless `enum` namespaces `AudioFeedback`, `LoginItem`, `InstalledApps`, `TemplateStore`. These integrate via **closure callbacks** (`onFocusCompleted`, `onDistraction`, …) wired in `AppModel.configure`; OS wiring is "verified by running," not unit-tested.
- **Pure, deterministic logic** (decisions): `DayLayout`/`TemplateSchedule`, `StreakService`, `StatsService`, `InsightEngine`, `RewardEngine`, `Projections`, `SettingsLogic`. Each is a stateless `enum`/value struct that takes value-type inputs and returns `Equatable` value-type outputs — **no SwiftData, UserDefaults, clock, or UI**. `Projections.swift` is the single adapter mapping `@Model` arrays into value-type mirrors (`SessionStat`, `PlanStat`, etc.) so the math never meets the database. **Determinism is enforced by injection**: `Calendar` is a parameter (tests pin a fixed UTC Gregorian) and "now"/"today" is always passed in, never `Date()` inside a function. Every pure file has a matching `…Tests.swift`.

### App lifecycle (menu-bar agent)

`PomodoroFocusApp` defines two scenes — a `MenuBarExtra(.window)` (always-on control center) and one `Window(id: WindowID.main)` hosting `RootWindowView` (a `TabView` of Plan / Dashboard / Settings). `AppModel.configure(context:)` is called from **multiple racing `.task` hooks** and is made idempotent by a `configured` flag (first caller wins) — keep one-time launch side effects (notification auth, reminder scheduling) inside that guard. Window reopen-on-icon-click is bridged through `AppDelegate` → `.pfReopenMainWindow` NotificationCenter post → `MenuBarLabel` `openWindow`, because the delegate has no access to SwiftUI's `openWindow`.

### UI & design system

Views are "dumb": they receive value types + closures, not `@Model`s or engines (e.g. `DayTimelineView` knows only `DaySegment` + a `TimelineActions` closure bag; `PlanView` resolves titles back to `TaskItem`s). **All styling goes through tokens** in `DesignSystem/Theme.swift` (`Palette`, `Spacing`, `Radius`, `Typography`, `Motion`) and shared modifiers in `DesignSystem/Surfaces.swift` (`.warmCanvas()`, borderless `.card()`, `SoftPillButtonStyle`, `ScreenHeader`).

## Conventions

- **Strict TDD for logic.** Pure Engine logic is developed red-green-refactor — write the failing test first, then fill in the body (several files still carry "stub until tests drive it" comments). Do **not** write tests-after for the Engine layer. New domain decisions belong in a pure, injected-`Calendar`, value-in/value-out unit, not inline in `AppModel` or a view.
- **Never hardcode colors / spacing / radii / fonts** — always use `Theme.*` tokens. Color is never the only signal: pair every state color with an SF Symbol + text label (colorblind safety). Cards are **borderless** by design (soft shadow, no stroke). Honor `accessibilityReduceMotion` wherever you animate.
- **All persistence goes through `AppModel`**; views mutate via its methods only. Edit the day rhythm only through `TemplateStore` / the `TemplateEditorView` binding (the editor doesn't save itself — `PlanView`'s `.onChange` persists).

## Gotchas

- **No SwiftData migration path:** `ModelContainer` creation `fatalError`s on failure. Changing any of the five `@Model`s without a migration will hard-crash on launch against an existing store.
- **`Day` uniqueness is by convention, not a DB constraint** — `date` must be `Calendar.startOfDay`-normalized and created via `AppModel.ensureToday()`; bypassing it creates duplicate days. `AppSettings` is likewise a singleton only by fetch-first-else-create convention.
- **Cascade deletes chain the full depth** — deleting a `Day` wipes its tasks, sessions, and distraction events. Be deliberate with `delete()`.
- **Stale comment:** a comment (and the design doc) references a "Focus Shield" always-on-top panel managed by the coordinator. **It is not implemented** — there's no `NSPanel`/`NSWindow`/shield view in the codebase. Don't assume `AppModel` owns it.
- `Insight` has a random `UUID` id and is compared by `kind`/text in tests, not identity. `StreakService` freeze accounting is subtle (`max(0, min(2, current/7) - used)`; the "natural start" rule distinguishes a streak's beginning from a real break) — preserve it when editing the walk.

## Scope / non-goals

This is **personal-use, local-only, single-user**. Do **not** introduce: a backend, accounts, or cloud/multi-device sync; an iOS/iPadOS companion (macOS 14+ only); forced app/website blocking (distraction handling is observe-and-nudge via public `NSWorkspace` only); RNG-based rewards (variability must come from real data — a streak milestone or a data-derived insight); or cut gamification (garden/avatar, XP/levels, social). App Store distribution and signing-for-others are out of scope.
