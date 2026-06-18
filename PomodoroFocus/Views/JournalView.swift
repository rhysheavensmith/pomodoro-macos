import SwiftUI
import SwiftData

/// The evening reflection: a structured journal entry per day, plus browsable
/// history. The bookend to the morning intention set in Plan.
struct JournalView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var allDays: [Day]

    @State private var draft = JournalDraft()
    @State private var todayIntention: String?
    @State private var loaded = false
    @State private var editingDate: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                todayCard
                historySection
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .warmCanvas()
        .onAppear(perform: loadToday)
        .sheet(item: $editingDate) { date in
            JournalEntryEditor(date: date)
                .environment(app)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ScreenHeader(eyebrow: "REFLECT", title: "Journal")
            Text("A few honest lines to close out the day.")
                .font(Theme.Typography.insightCaption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Today

    /// Count of prompts with real content — uses the tested normalization rule.
    private var capturedCount: Int {
        [draft.wentWell, draft.gotInWay, draft.tomorrowFocus]
            .filter { JournalLogic.normalize($0) != nil }
            .count
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(Theme.Typography.headlineRounded)
                Spacer()
                capturedBadge
            }

            if let intention = todayIntention, !intention.isEmpty {
                morningBookend(intention)
            }

            JournalPromptStack(draft: $draft)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .onChange(of: draft) { saveToday() }
    }

    /// Three dots + label showing how many prompts are filled (color + text).
    private var capturedBadge: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < capturedCount ? Theme.Palette.accent : Color.secondary.opacity(0.22))
                    .frame(width: 7, height: 7)
                    .animation(reduceMotion ? nil : Theme.Motion.quick, value: capturedCount)
            }
            Text(capturedCount == 3 ? "All set" : "\(capturedCount) of 3")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(capturedCount) of 3 prompts captured")
    }

    /// The morning→evening bookend: today's intention, shown read-only.
    private func morningBookend(_ intention: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "sunrise.fill")
                .foregroundStyle(Theme.Palette.warning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("THIS MORNING")
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                Text(intention)
                    .font(Theme.Typography.insightCaption)
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Palette.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("This morning's intention: \(intention)")
    }

    // MARK: History

    private var history: [JournalEntrySummary] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return JournalLogic.summaries(from: Projections.journalEntries(from: allDays))
            .filter { $0.date != todayStart }
    }

    @ViewBuilder private var historySection: some View {
        if history.isEmpty {
            historyEmptyState
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("PAST ENTRIES")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(Theme.Palette.focus.opacity(0.75))
                ForEach(history) { entry in
                    Button { editingDate = entry.date } label: { historyRow(entry) }
                        .buttonStyle(JournalRowButtonStyle(reduceMotion: reduceMotion))
                }
            }
        }
    }

    private var historyEmptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "book.closed")
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(.secondary.opacity(0.5))
                .accessibilityHidden(true)
            Text("Your reflections gather here")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Each evening you journal becomes a page you can look back on.")
                .font(Theme.Typography.insightCaption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }

    private func historyRow(_ entry: JournalEntrySummary) -> some View {
        let isComplete = entry.completeness == .complete
        return HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle.dotted")
                .font(.title3)
                .foregroundStyle(isComplete ? Theme.Palette.accent : .secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(entry.date.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.subheadline.weight(.semibold))
                Text(entry.preview)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: Theme.Spacing.sm)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.date.formatted(.dateTime.weekday(.wide).month().day())), \(isComplete ? "complete" : "partial"). \(entry.preview)")
        .accessibilityHint("Opens this entry to edit")
    }

    // MARK: Data

    private func loadToday() {
        guard !loaded, let day = app.ensureToday() else { return }
        draft = app.journalDraft(for: day)
        todayIntention = day.dayIntention
        loaded = true
    }

    private func saveToday() {
        guard loaded, let day = app.ensureToday() else { return }
        app.saveJournal(for: day, draft: draft)
    }
}

// MARK: - Shared prompt UI

/// The three reflection prompts, rendered consistently wherever a draft is edited
/// (today's card and the history editor). One source of truth for icon + copy.
fileprivate struct JournalPromptStack: View {
    @Binding var draft: JournalDraft

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            JournalPromptField(
                label: "What went well",
                systemImage: "sparkles",
                tint: Theme.Palette.accent,
                placeholder: "A win, a finished pomodoro, a good moment…",
                text: $draft.wentWell
            )
            JournalPromptField(
                label: "What got in the way",
                systemImage: "exclamationmark.triangle.fill",
                tint: Theme.Palette.warning,
                placeholder: "A distraction, a blocker, an interruption…",
                text: $draft.gotInWay
            )
            JournalPromptField(
                label: "Tomorrow's focus",
                systemImage: "target",
                tint: Theme.Palette.focus,
                placeholder: "The one thing that matters most tomorrow…",
                text: $draft.tomorrowFocus
            )
        }
    }
}

/// A labelled, icon-led multiline prompt field with a placeholder.
fileprivate struct JournalPromptField: View {
    let label: String
    let systemImage: String
    let tint: Color
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
            }

            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60)
                .padding(.horizontal, Theme.Spacing.xs)
                .padding(.vertical, Theme.Spacing.xs - 2)
                .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .strokeBorder(tint.opacity(text.isEmpty ? 0.12 : 0.28))
                )
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, Theme.Spacing.xs + 5)
                            .padding(.vertical, Theme.Spacing.xs + 2)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}

/// Subtle press feedback for tappable history cards (reduced-motion aware).
fileprivate struct JournalRowButtonStyle: ButtonStyle {
    let reduceMotion: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : Theme.Motion.quick, value: configuration.isPressed)
    }
}

// MARK: - History editor sheet

/// Edits a single past day's reflection in a sheet; autosaves on change.
fileprivate struct JournalEntryEditor: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let date: Date

    @State private var draft = JournalDraft()
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ScreenHeader(eyebrow: "ENTRY",
                         title: date.formatted(.dateTime.weekday(.wide).month().day()))
            JournalPromptStack(draft: $draft)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(SoftPillButtonStyle(tint: Theme.Palette.accent))
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(minWidth: 440, minHeight: 480, alignment: .leading)
        .warmCanvas()
        .onChange(of: draft) { save() }
        .onAppear {
            guard !loaded, let day = app.day(on: date) else { return }
            draft = app.journalDraft(for: day)
            loaded = true
        }
    }

    private func save() {
        guard loaded, let day = app.day(on: date) else { return }
        app.saveJournal(for: day, draft: draft)
    }
}

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSinceReferenceDate }
}
