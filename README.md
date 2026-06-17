# Pomodoro Focus

A personal-use, native macOS Pomodoro timer + anti-distraction tool + daily
execution system. Plan a task list each day, allocate pomodoros per task, and
work through them — with gamification grounded in Nir Eyal's *Hooked* habit loop
(streaks + a stats/insight dashboard, focus shield + distraction tracking).

See [`docs/plans/2026-06-18-pomodoro-focus-design.md`](docs/plans/2026-06-18-pomodoro-focus-design.md)
for the full design.

## Requirements

- macOS 14+ (built & tested on macOS 26.5 / Xcode 26)
- [XcodeGen](https://github.com/yonyz/XcodeGen) — `brew install xcodegen`

## Build & run

The Xcode project is generated from [`project.yml`](project.yml) so it never
needs to be hand-edited or committed.

```sh
# 1. Generate the Xcode project from project.yml
xcodegen generate

# 2a. Open in Xcode and run (⌘R)
open PomodoroFocus.xcodeproj

# 2b. …or build from the command line
xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO

# 3. Run the test suite
xcodebuild -scheme PomodoroFocus -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

The app runs as a **menu-bar agent** (`LSUIElement`) — look for the timer icon in
the menu bar; the Plan/Dashboard window opens from there.

## Architecture

| Layer | Files |
|---|---|
| Design tokens | `PomodoroFocus/DesignSystem/Theme.swift` |
| Data (SwiftData) | `PomodoroFocus/Models/` |
| Engine / services | `PomodoroFocus/Engine/` (timer, streak, stats, insight, distraction, notifications) |
| UI surfaces | `PomodoroFocus/Views/` (menu bar, focus shield, plan, dashboard) |
| App entry & coordinator | `PomodoroFocus/App/` |
| Tests | `PomodoroFocusTests/` |
