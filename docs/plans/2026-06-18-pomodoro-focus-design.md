# Pomodoro Focus — Design Document

**Date:** 2026-06-18
**Author:** Rhys (with Claude Code)
**Status:** Approved design, pre-implementation

---

## 1. Purpose

A personal-use, native macOS Pomodoro timer that doubles as an anti-distraction
tool and a daily execution system. Each day you plan a task list, allocate
pomodoros per task, and work through them. Gamification — grounded in Nir Eyal's
*Hooked* habit-loop model — keeps you coming back. **Single user, not for the
App Store.**

## 2. Key decisions

| Dimension | Decision |
|---|---|
| **Stack** | Native **SwiftUI**, Swift, Xcode-buildable. Target **macOS 14 (Sonoma)+**. |
| **Gamification** | **Streaks/momentum** + **stats & insight dashboard**. (Garden/XP mechanics explicitly cut.) |
| **Variable reward** | Honest, no-RNG: unpredictable *milestone* celebrations + a genuinely-fresh *daily insight* surfaced from real data. |
| **Anti-distraction** | **Focus shield** + distraction tracking. No forced app/site blocking (gated/fragile on macOS). Detection via public `NSWorkspace` API. |
| **Daily rhythm** | **Fresh daily plan** with smart carry-over of yesterday's unfinished tasks; history archived for stats. |

## 3. The Hooked loop (how the design maps to the model)

- **Trigger** — *External:* morning "plan your day" notification; pomodoro-complete,
  break-over, and evening "streak at risk" nudges. *Internal:* the itch to make
  progress / relieve task-anxiety.
- **Action** — the simplest possible behavior: **Start a pomodoro in one click**
  from the menu bar.
- **Variable Reward** — on completion, **one** reward surfaces, and *which* one is
  unpredictable: sometimes a streak milestone, sometimes a fresh self-insight
  ("3rd focused hour today — your best this week"). Variability comes from real,
  changing data — not a slot machine.
- **Investment** — the **morning planning ritual** (building the list, allocating
  pomodoros) plus the accumulating **streak** and **history**. Each day's planning
  makes the next session smarter (plan-accuracy feedback closes the loop).

## 4. Architecture

Three UI **surfaces**, backed by plain-Swift engine pieces and a local store.

**Surfaces**
1. **Menu-bar timer** (`MenuBarExtra`) — always-accessible control center: current
   task, big countdown, Start/Pause/Skip, today's progress dots. Home of the Action.
2. **Main window** — two tabs: **Plan** and **Dashboard**.
3. **Focus Shield** — small always-on-top panel shown *only during a pomodoro*:
   huge timer + current task + tiny pause/end. `.ultraThinMaterial` background.

**Engine (UI-free, testable)**
- `TimerEngine` — `@Observable` state machine (`idle → running → break → idle…`),
  single source of truth for time. Observed by all three surfaces.
- `DistractionMonitor` — observes `NSWorkspace.didActivateApplicationNotification`;
  on switch to a blocklisted app, fires a nudge and logs a `DistractionEvent`.
- `NotificationScheduler` — schedules the external triggers via `UserNotifications`.
- `StreakService` — qualified-day calculation, freezes, milestone detection.
- `InsightEngine` — ranks candidate insights by surprise/actionability over aggregates.

**Persistence:** SwiftData, local-only.

## 5. Data model (SwiftData `@Model`)

```
Day              date · plannedAt? · dayIntention? · tasks[]
TaskItem         title · plannedPomodoros · completedPomodoros · isDone ·
                 order · carriedFromDate? · day · sessions[]
PomodoroSession  startedAt · endedAt? · plannedDuration · focusedDuration ·
                 wasCompleted · task · distractions[]
DistractionEvent timestamp · appName · appBundleID · secondsAway · session
Settings         workMins(25) · shortBreakMins(5) · longBreakMins(15) ·
                 longBreakEvery(4) · dailyGoal? · planReminderTime ·
                 streakBar(1) · activeDays · blocklist[bundleIDs] · streakState
```

`DistractionEvent` intentionally hangs off `PomodoroSession` (not `Day`) so the
dashboard can answer "which *tasks* trigger the most app-switching?".

## 6. Daily loop

1. **Trigger:** at `planReminderTime` (default 09:00) → "Plan your day" → Plan tab.
2. **Investment:** create today's `Day`, add tasks, allocate `plannedPomodoros`.
   Yesterday's unfinished tasks appear in a **carry-over strip**; one tap brings a
   task forward (stamps `carriedFromDate`).
3. **Action:** pick a task → **Start**. `TimerEngine` opens a session bound to the
   task; Focus Shield appears; `DistractionMonitor` arms.
4. **During:** switching to a blocklisted app → nudge + logged `DistractionEvent`.
5. **Variable reward:** `completedPomodoros++`, completion check, one reward surfaces.
6. **Break:** short break; long break every `longBreakEvery` (4th). Repeat.

## 7. Streak rules

- **Qualified day** = ≥ `streakBar` completed pomodoros (default 1; raisable).
- **Streak freezes:** bank 1 per 7 qualified days (max 2). A missed day silently
  consumes a freeze if available — streak survives, that day shows as *frozen*.
  Deliberate counter to loss-aversion backfire.
- **Active days:** weekends optionally marked off so they never break the chain.
- **"Streak at risk" trigger:** gentle evening notification only when a streak is
  active and today isn't yet qualified.
- **Milestones:** 3 / 7 / 14 / 30 / 50 / 100… celebratory surfaces (variable reward).

## 8. Stats dashboard (reward of the Hunt)

Built with **Swift Charts**:
- **Streak ring** headline (current · longest · freezes banked).
- **Today:** focused pomodoros vs goal · focus hours · completion rate · distractions.
- **Trends:** focus-hours bar (14/30d) · best-time-of-day heatmap · day-of-week strength.
- **Plan accuracy:** planned vs actual pomodoros (improves future planning).
- **Insight of the day:** auto-generated line, ranked by surprise/actionability.
- Every chart has an empty state ("No data yet — finish your first pomodoro").

## 9. UI / UX & visual language

- **Style:** Bold/Exaggerated Minimalism — timer as a huge calm centerpiece,
  generous negative space, one primary CTA per surface.
- **Color (light + dark):** **Focus = red** `#DC2626`, **Break = green** `#059669`,
  deep slate surface `#0F172A`. Color is never the only signal — every state also
  carries a label + SF Symbol (colorblind-safe).
- **Typography (all native, no bundled fonts):** **SF Pro** system text; **SF Pro
  Rounded** for the big timer (calm + tabular figures → no pixel jitter as it ticks);
  **New York** (Apple's system serif) for the reflective "Insight of the day" copy.
- **Icons:** **SF Symbols** only — no emoji.
- **Motion:** 150–300ms springs, transform/opacity only; completion check is the one
  delight moment; full `prefers-reduced-motion` support.
- **Notifications/triggers:** morning plan · pomodoro-complete (carries reward) ·
  break-over · evening streak-at-risk. Focus/DND-aware, actionable buttons.

## 10. Build / run

- Xcode project, macOS 14+, runs as a **menu-bar agent** (`LSUIElement`); the main
  window opens from the menu bar.
- Run via Xcode ⌘R; CI/compile-verify via `xcodebuild`.

## 11. Out of scope (YAGNI)

- App Store packaging, sandboxing-for-distribution, code signing for others.
- Cloud sync / multi-device / accounts.
- Forced app/website blocking (Screen Time / content-filter extensions).
- Social features, XP/levels, garden/avatar mechanics.
- iOS/iPadOS companion.

## 12. Testing strategy

Pure-logic engine pieces are unit-tested (TDD where it pays):
`TimerEngine` state transitions, `StreakService` (qualification, freezes,
milestones), `InsightEngine` ranking, plan-accuracy math. UI is verified by
building (`xcodebuild`) and manual run.
