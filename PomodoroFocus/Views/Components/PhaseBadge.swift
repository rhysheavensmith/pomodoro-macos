import SwiftUI

/// Phase label + SF Symbol in the phase's semantic color. Color is never the
/// only signal — the label and icon always accompany it.
struct PhaseBadge: View {
    let phase: TimerPhase

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: phase.symbol)
            Text(phase.label)
                .font(Theme.Typography.headlineRounded)
        }
        .foregroundStyle(Theme.Palette.color(for: phase))
    }
}
