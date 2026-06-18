import SwiftUI

/// Compact ●●●○○ representation of completed vs planned pomodoros.
struct ProgressDots: View {
    let completed: Int
    let planned: Int
    var color: Color = Theme.Palette.accent
    var dot: CGFloat = 8

    private var total: Int { max(planned, completed, 1) }

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < completed ? color : Color.secondary.opacity(0.22))
                    .frame(width: dot, height: dot)
            }
        }
        .accessibilityLabel("\(completed) of \(planned) pomodoros done")
    }
}
