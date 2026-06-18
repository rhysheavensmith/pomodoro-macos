import SwiftUI
import SwiftData

/// The evening reflection: a structured journal entry per day, plus browsable
/// history. The bookend to the morning intention set in Plan.
struct JournalView: View {
    @Environment(AppModel.self) private var app
    @Query private var allDays: [Day]

    @State private var draft = JournalDraft()
    @State private var todayIntention: String?
    @State private var loaded = false
    @State private var editingDate: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                ScreenHeader(eyebrow: "REFLECT", title: "Journal")
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

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if let intention = todayIntention, !intention.isEmpty {
                Label("This morning: \(intention)", systemImage: "target")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            JournalPromptField(label: "What went well", text: $draft.wentWell)
            JournalPromptField(label: "What got in the way", text: $draft.gotInWay)
            JournalPromptField(label: "Tomorrow's focus", text: $draft.tomorrowFocus)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .onChange(of: draft) { saveToday() }
    }

    private var history: [JournalEntrySummary] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return JournalLogic.summaries(from: Projections.journalEntries(from: allDays))
            .filter { $0.date != todayStart }
    }

    @ViewBuilder private var historySection: some View {
        if !history.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("PAST ENTRIES")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(Theme.Palette.focus.opacity(0.75))
                ForEach(history) { entry in
                    Button { editingDate = entry.date } label: { historyRow(entry) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private func historyRow(_ entry: JournalEntrySummary) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: entry.completeness == .complete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(entry.completeness == .complete ? Theme.Palette.accent : .secondary)
                .accessibilityLabel(entry.completeness == .complete ? "Complete entry" : "Partial entry")
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(entry.date.formatted(.dateTime.weekday(.abbreviated).month().day()))
                    .font(.subheadline.weight(.semibold))
                Text(entry.preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

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

/// A labelled, carded multiline prompt field shared by the today and history editors.
fileprivate struct JournalPromptField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 64)
                .padding(Theme.Spacing.xs)
                .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).strokeBorder(.quaternary))
        }
    }
}

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
            JournalPromptField(label: "What went well", text: $draft.wentWell)
            JournalPromptField(label: "What got in the way", text: $draft.gotInWay)
            JournalPromptField(label: "Tomorrow's focus", text: $draft.tomorrowFocus)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(SoftPillButtonStyle(tint: Theme.Palette.accent))
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(minWidth: 440, minHeight: 460, alignment: .leading)
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
