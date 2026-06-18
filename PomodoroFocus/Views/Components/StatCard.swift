import SwiftUI

/// A single labeled statistic on the dashboard.
struct StatCard: View {
    let title: String
    let value: String
    var systemImage: String?
    var tint: Color = Theme.Palette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xxs) {
                if let systemImage {
                    Image(systemName: systemImage).foregroundStyle(tint)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(Theme.Typography.statNumber)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}
