import SwiftUI

/// In-window running-timer bar shown across all tabs while a focus or break is
/// active: phase, task/break name, big countdown, and pause/skip/stop controls.
/// (Replaces the old always-on-top Focus Shield — the menu bar remains the
/// at-a-glance indicator.)
struct ActiveTimerBar: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let timer = app.timer
        Group {
            if timer.isActive {
                bar(timer)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : Theme.Motion.gentle, value: timer.isActive)
    }

    private func bar(_ timer: TimerEngine) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: timer.phase.symbol)
                .font(.title2)
                .foregroundStyle(Theme.Palette.color(for: timer.phase))

            VStack(alignment: .leading, spacing: 0) {
                Text(timer.phase.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Palette.color(for: timer.phase))
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            Spacer()

            Text(timer.displayTime)
                .font(Theme.Typography.timer(size: 30))
                .foregroundStyle(Theme.Palette.color(for: timer.phase))

            controls(timer)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var subtitle: String? {
        app.timer.phase.isBreak ? app.currentBreakName : app.timer.currentTaskTitle
    }

    @ViewBuilder private func controls(_ timer: TimerEngine) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Button { app.pauseOrResume() } label: {
                Image(systemName: timer.phase == .paused ? "play.fill" : "pause.fill")
            }
            .accessibilityLabel(timer.phase == .paused ? "Resume" : "Pause")

            if timer.phase.isBreak {
                Button { app.skip() } label: { Image(systemName: "forward.fill") }
                    .accessibilityLabel("Skip break")
            }

            Button(role: .destructive) { app.stop() } label: { Image(systemName: "stop.fill") }
                .accessibilityLabel("Stop")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
