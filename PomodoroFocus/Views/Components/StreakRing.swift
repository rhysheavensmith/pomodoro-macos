import SwiftUI

/// Headline streak ring: current streak in the center, the arc filling toward
/// the next milestone, plus banked freezes.
struct StreakRing: View {
    let streak: StreakSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var nextMilestone: Int {
        StreakService.milestones.first { $0 > streak.current } ?? max(streak.current, 1)
    }

    private var progress: Double {
        let prev = StreakService.milestones.last { $0 <= streak.current } ?? 0
        let span = max(1, nextMilestone - prev)
        return min(1, Double(streak.current - prev) / Double(span))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.Palette.streak,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : Theme.Motion.gentle, value: progress)

            VStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Theme.Palette.streak)
                Text("\(streak.current)")
                    .font(Theme.Typography.statNumber)
                Text("day streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if streak.freezesBanked > 0 {
                    Label("\(streak.freezesBanked)", systemImage: "snowflake")
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                }
            }
        }
        .frame(width: 140, height: 140)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current streak")
        .accessibilityValue("\(streak.current) days, longest \(streak.longest), \(streak.freezesBanked) freezes banked")
        .accessibilityHint("Progressing toward a \(nextMilestone)-day milestone")
    }
}
