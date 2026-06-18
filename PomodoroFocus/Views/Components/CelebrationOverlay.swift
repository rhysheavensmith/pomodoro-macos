import SwiftUI

/// The in-app "variable reward" moment: a celebratory card that springs in when a
/// pomodoro completes and auto-dismisses. Driven by `AppModel.rewardNonce` so it
/// fires on every completion, even when the reward text repeats.
struct CelebrationOverlay: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var show = false
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if show, let reward = app.latestReward {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.Palette.accent)
                        .symbolEffect(.bounce, value: reduceMotion ? false : show)
                    Text("Pomodoro complete")
                        .font(Theme.Typography.titleRounded)
                    Text(reward)
                        .font(Theme.Typography.insight)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(Theme.Spacing.xl)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.lg))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .strokeBorder(Theme.Palette.accent.opacity(0.25))
                )
                .shadow(radius: 24, y: 8)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
                .accessibilityAddTraits(.isStaticText)
                .accessibilityLabel("Pomodoro complete. \(reward)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .animation(reduceMotion ? .easeInOut : Theme.Motion.celebrate, value: show)
        .onChange(of: app.rewardNonce) {
            dismissTask?.cancel()
            show = true
            dismissTask = Task {
                try? await Task.sleep(for: .seconds(2.6))
                if !Task.isCancelled { show = false }
            }
        }
    }
}
