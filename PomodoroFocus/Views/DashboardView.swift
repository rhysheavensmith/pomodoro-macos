import SwiftUI
import SwiftData
import Charts

/// Streaks + stats (Hooked "reward of the Hunt"): streak ring, today's numbers,
/// trend charts, and the serif Insight of the Day.
struct DashboardView: View {
    @Environment(AppModel.self) private var app

    private var stats: StatsSummary { app.stats }
    private var hasData: Bool { stats.totalCompletedPomodoros > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                ScreenHeader(eyebrow: "YOUR PROGRESS", title: "Dashboard")
                topRow
                insightCard
                if hasData {
                    chartsSection
                    planAccuracyCard
                } else {
                    emptyState
                }
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .warmCanvas()
        .task { app.refreshDerived() }
    }

    // MARK: Top row — streak ring + today cards

    private var topRow: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.lg) {
            VStack(spacing: Theme.Spacing.xs) {
                StreakRing(streak: app.streak)
                Text("Longest: \(app.streak.longest)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      spacing: Theme.Spacing.sm) {
                StatCard(title: "Focused today", value: "\(stats.todayFocusedPomodoros)",
                         systemImage: "checkmark.circle", tint: Theme.Palette.focus)
                StatCard(title: "Focus hours", value: String(format: "%.1f", stats.todayFocusHours),
                         systemImage: "clock", tint: Theme.Palette.accent)
                StatCard(title: "Completion", value: "\(Int((stats.todayCompletionRate * 100).rounded()))%",
                         systemImage: "target", tint: Theme.Palette.accent)
                StatCard(title: "Distractions", value: "\(stats.todayDistractions)",
                         systemImage: "bell.slash", tint: Theme.Palette.warning)
            }
        }
    }

    // MARK: Insight of the day (serif)

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label("Insight of the day", systemImage: "sparkles")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if let insight = app.insightOfTheDay {
                Text(insight.headline)
                    .font(Theme.Typography.insight)
                Text(insight.detail)
                    .font(Theme.Typography.insightCaption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Finish a few pomodoros and your patterns will show up here.")
                    .font(Theme.Typography.insightCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.accent.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.md))
    }

    // MARK: Charts

    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            chartCard("Focus hours — last 14 days") {
                Chart(stats.dailyFocusHours) { day in
                    BarMark(x: .value("Day", day.date, unit: .day),
                            y: .value("Hours", day.hours))
                    .foregroundStyle(Theme.Palette.accent.gradient)
                }
                .frame(height: 160)
                .accessibilityLabel("Focus hours over the last 14 days")
                .accessibilityValue("\(String(format: "%.1f", stats.totalFocusHours)) total focus hours")
            }

            HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                chartCard("Best time of day") {
                    Chart(stats.timeOfDay) { bucket in
                        BarMark(x: .value("Hour", bucket.hour),
                                y: .value("Done", bucket.completedCount))
                        .foregroundStyle(Theme.Palette.focus.gradient)
                    }
                    .chartXScale(domain: 0...23)
                    .frame(height: 140)
                    .accessibilityLabel("Completed pomodoros by hour of day")
                    .accessibilityValue(stats.bestFocusHourRange.map { "You focus best \($0)" } ?? "Not enough data")
                }
                chartCard("Strongest weekday") {
                    Chart(stats.weekday) { bucket in
                        BarMark(x: .value("Day", Self.shortWeekday(bucket.weekday)),
                                y: .value("Done", bucket.completedCount))
                        .foregroundStyle(Theme.Palette.streak.gradient)
                    }
                    .frame(height: 140)
                    .accessibilityLabel("Completed pomodoros by weekday")
                    .accessibilityValue(stats.strongestWeekday.map { "Strongest on \(InsightEngine.weekdayName($0))s" } ?? "Not enough data")
                }
            }
        }
    }

    private func chartCard<Content: View>(_ title: String,
                                          @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title).font(Theme.Typography.headlineRounded)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .card()
    }

    // MARK: Plan accuracy

    private var planAccuracyCard: some View {
        let pa = stats.planAccuracy
        let onTarget = pa.ratio >= 0.9
        return HStack(spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading) {
                Text("Plan accuracy").font(Theme.Typography.headlineRounded)
                Text("Planned \(pa.planned) · Completed \(pa.completed)")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: onTarget ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(onTarget ? Theme.Palette.accent : Theme.Palette.warning)
                Text("\(Int((pa.ratio * 100).rounded()))%")
                    .font(Theme.Typography.statNumber)
                    .foregroundStyle(onTarget ? Theme.Palette.accent : Theme.Palette.warning)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Plan accuracy \(Int((pa.ratio * 100).rounded())) percent, \(onTarget ? "on target" : "below target")")
        }
        .padding(Theme.Spacing.md)
        .card()
    }

    private var emptyState: some View {
        ContentUnavailableView("No data yet",
                               systemImage: "chart.bar",
                               description: Text("Finish your first pomodoro to see your trends."))
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Spacing.xxl)
    }

    private static func shortWeekday(_ weekday: Int) -> String {
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][safe: weekday - 1] ?? "?"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
