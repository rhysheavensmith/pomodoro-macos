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

    // Filled in by Task 8.
    @ViewBuilder private var historySection: some View { EmptyView() }

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
