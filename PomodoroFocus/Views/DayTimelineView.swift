import SwiftUI

/// Per-task-run actions, resolved by PlanView (title → TaskItem).
struct TimelineActions {
    var isRunning: Bool
    var onStart: (String) -> Void
    var onToggleDone: (String) -> Void
    var onAdjust: (String, Int) -> Void
    var onDelete: (String) -> Void
}

/// The "A Day in Pomodoros" timeline: a vertical spine threading focus sets
/// (rows of tomatoes grouped by task) and named break ribbons.
struct DayTimelineView: View {
    let segments: [DaySegment]
    let actions: TimelineActions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                row(segment, isFirst: index == 0, isLast: index == segments.count - 1)
            }
        }
    }

    @ViewBuilder
    private func row(_ segment: DaySegment, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            SpineColumn(isFirst: isFirst, isLast: isLast, isBreak: segment.isRest)
            content(segment)
                .padding(.bottom, Theme.Spacing.lg)
        }
    }

    @ViewBuilder
    private func content(_ segment: DaySegment) -> some View {
        switch segment {
        case .focus(let runs):
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(runs) { run in
                    FocusRunView(run: run, actions: actions)
                }
            }
        case let .rest(name, minutes, symbol):
            BreakRibbon(name: name, minutes: minutes, symbol: symbol)
                .padding(.top, 2)
        }
    }
}

private extension DaySegment {
    var isRest: Bool { if case .rest = self { return true } else { return false } }
}

// MARK: - Spine

private struct SpineColumn: View {
    let isFirst: Bool
    let isLast: Bool
    let isBreak: Bool

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .padding(.top, isFirst ? 10 : 0)
            Circle()
                .fill(isBreak ? Theme.Palette.breakColor : Theme.Palette.focus)
                .frame(width: 11, height: 11)
                .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 2))
                .offset(y: 6)
        }
        .frame(width: 16)
    }
}

// MARK: - Focus run

private struct FocusRunView: View {
    let run: DayFocusRun
    let actions: TimelineActions

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(run.tomatoes) { tomato in
                    TomatoTile(tomato: tomato, onPress: pressAction(for: tomato))
                }
            }
            if let title = run.taskTitle {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(title).font(.headline.weight(.semibold))
                    Spacer(minLength: 0)
                    Menu {
                        Button { actions.onAdjust(title, 1) } label: { Label("Add a pomodoro", systemImage: "plus") }
                        Button { actions.onAdjust(title, -1) } label: { Label("Remove a pomodoro", systemImage: "minus") }
                        Button { actions.onToggleDone(title) } label: { Label("Toggle done", systemImage: "checkmark.circle") }
                        Divider()
                        Button(role: .destructive) { actions.onDelete(title) } label: { Label("Delete task", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(title), \(run.tomatoes.count) pomodoros")
            } else {
                Text("Open slots")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Only the current tile (and only when not already running) is startable.
    private func pressAction(for tomato: DayTomato) -> (() -> Void)? {
        guard tomato.isCurrent, !actions.isRunning, let title = tomato.taskTitle else { return nil }
        return { actions.onStart(title) }
    }
}

// MARK: - Break ribbon

struct BreakRibbon: View {
    let name: String
    let minutes: Int
    let symbol: String

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: symbol).foregroundStyle(Theme.Palette.breakColor)
            Text(name).font(.subheadline.weight(.semibold))
            Text("· \(minutes) min").font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.md)
        .background(Capsule().fill(Theme.Palette.ribbonWarm))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) break, \(minutes) minutes")
    }
}
