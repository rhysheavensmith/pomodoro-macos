import SwiftUI
import SwiftData
import AppKit
import Combine

/// The label rendered *in the menu bar*: live countdown while active, else a
/// calm timer glyph. The label view is created at launch, so it's also where we
/// reliably configure the coordinator and fire the "plan your day" trigger by
/// opening the Plan window once per launch.
struct MenuBarLabel: View {
    @Environment(AppModel.self) private var app
    @Environment(\.openWindow) private var openWindow
    let context: ModelContext

    var body: some View {
        content
            .task {
                app.configure(context: context)
                if !app.didOpenLaunchWindow {
                    app.didOpenLaunchWindow = true
                    openWindow(id: WindowID.main)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .pfReopenMainWindow)) { _ in
                openWindow(id: WindowID.main)
                NSApp.activate(ignoringOtherApps: true)
            }
    }

    @ViewBuilder private var content: some View {
        let timer = app.timer
        if timer.isActive {
            HStack(spacing: Theme.Spacing.xxs) {
                Image(systemName: timer.phase.symbol)
                Text(timer.displayTime).font(Theme.Typography.menuBarTime)
            }
        } else {
            Image(systemName: "timer")
        }
    }
}

/// Dropdown control center: current phase, big countdown, controls, today's
/// tasks, and a jump to the dashboard. Home of the one-click Action.
struct MenuBarView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \TaskItem.order) private var allTasks: [TaskItem]

    private var todays: [TaskItem] {
        allTasks.filter { task in
            guard let date = task.day?.date else { return false }
            return Calendar.current.isDate(date, inSameDayAs: Date())
        }
    }

    private var nextTask: TaskItem? {
        todays.first { !$0.isDone && $0.completedPomodoros < $0.plannedPomodoros } ?? todays.first
    }

    private var completedToday: Int {
        todays.reduce(0) { $0 + $1.completedPomodoros }
    }

    private var namedBreaks: [TemplateSegment] {
        TemplateStore.load().filter { $0.kind == .rest }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            header
            timerBlock
            Divider()
            if todays.isEmpty {
                emptyState
            } else {
                taskList
            }
            Divider()
            footer
        }
        .padding(Theme.Spacing.md)
        .frame(width: 320)
    }

    private var header: some View {
        HStack {
            Text("Pomodoro Focus").font(Theme.Typography.headlineRounded)
            Spacer()
            if app.streak.current > 0 {
                Label("\(app.streak.current)", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Palette.streak)
            }
        }
    }

    private var timerBlock: some View {
        let timer = app.timer
        return VStack(spacing: Theme.Spacing.xs) {
            PhaseBadge(phase: timer.phase)
            Text(timer.isActive ? timer.displayTime : "--:--")
                .font(Theme.Typography.timer(size: 44))
                .foregroundStyle(Theme.Palette.color(for: timer.phase))
            if timer.phase.isBreak, let name = app.currentBreakName {
                Text(name).font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Palette.breakColor).lineLimit(1)
            } else if let title = timer.currentTaskTitle, timer.isActive {
                Text(title).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            controls
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var controls: some View {
        let timer = app.timer
        if timer.isActive {
            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    app.pauseOrResume()
                } label: {
                    Label(timer.phase == .paused ? "Resume" : "Pause",
                          systemImage: timer.phase == .paused ? "play.fill" : "pause.fill")
                }
                Button(role: .destructive) {
                    app.stop()
                } label: {
                    Label("End", systemImage: "stop.fill")
                }
                if timer.phase.isBreak {
                    Button {
                        app.skip()
                    } label: {
                        Label("Skip break", systemImage: "forward.fill")
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else {
            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    if let task = nextTask { app.startPomodoro(for: task) }
                } label: {
                    Label("Start focus", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Palette.focus)
                .disabled(nextTask == nil)

                Menu {
                    Button("Short break · \(app.settings.shortBreakMins) min") { app.startShortBreak() }
                    ForEach(namedBreaks) { seg in
                        Button("\(seg.name) · \(seg.minutes) min") {
                            app.startNamedBreak(name: seg.name, minutes: seg.minutes)
                        }
                    }
                } label: {
                    Label("Break", systemImage: "cup.and.saucer")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    private var taskList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("TODAY").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
            ForEach(todays) { task in
                HStack(spacing: Theme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .lineLimit(1)
                            .strikethrough(task.isDone)
                            .foregroundStyle(task.isDone ? .secondary : .primary)
                        ProgressDots(completed: task.completedPomodoros, planned: task.plannedPomodoros)
                    }
                    Spacer()
                    Button {
                        app.startPomodoro(for: task)
                    } label: {
                        Image(systemName: "play.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.Palette.focus)
                    .disabled(app.timer.phase == .running)
                    .accessibilityLabel("Start pomodoro for \(task.title)")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("No tasks yet for today")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("Plan your day") { openWindow(id: WindowID.main) }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Palette.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var footer: some View {
        HStack {
            Label("\(completedToday) done", systemImage: "checkmark.circle")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button {
                openWindow(id: WindowID.main)
            } label: {
                Label("Plan & stats", systemImage: "chart.bar.xaxis")
            }
            .buttonStyle(.link)
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Quit Pomodoro Focus")
        }
    }
}
