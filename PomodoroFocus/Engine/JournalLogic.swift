import Foundation

/// The three reflection prompts as edited in the UI (raw, untrimmed).
struct JournalDraft: Equatable {
    var wentWell: String = ""
    var gotInWay: String = ""
    var tomorrowFocus: String = ""
}

/// How fully a day's reflection is filled in.
enum JournalCompleteness: Equatable { case empty, partial, complete }

/// A day's stored journal mirrored as a value type (no SwiftData), so the
/// history logic stays unit-testable without a ModelContainer.
struct JournalEntryInput: Equatable {
    let date: Date
    let wentWell: String?
    let gotInWay: String?
    let tomorrowFocus: String?
}

/// A history row ready for display.
struct JournalEntrySummary: Equatable, Identifiable {
    let date: Date
    let wentWell: String?
    let gotInWay: String?
    let tomorrowFocus: String?
    let preview: String
    let completeness: JournalCompleteness
    var id: Date { date }
}

/// Pure journaling decisions: normalization, completeness, history assembly.
enum JournalLogic {
    /// Trim whitespace/newlines; blank → nil.
    static func normalize(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    static func completeness(_ draft: JournalDraft) -> JournalCompleteness {
        let filled = [draft.wentWell, draft.gotInWay, draft.tomorrowFocus]
            .compactMap(normalize).count
        switch filled {
        case 0: return .empty
        case 3: return .complete
        default: return .partial
        }
    }

    static func isEmpty(_ draft: JournalDraft) -> Bool {
        completeness(draft) == .empty
    }

    static func summaries(from entries: [JournalEntryInput]) -> [JournalEntrySummary] {
        entries.compactMap(summary(from:)).sorted { $0.date > $1.date }
    }

    /// nil when the entry has no content in any field.
    private static func summary(from entry: JournalEntryInput) -> JournalEntrySummary? {
        let well = normalize(entry.wentWell)
        let blocked = normalize(entry.gotInWay)
        let next = normalize(entry.tomorrowFocus)
        let filled = [well, blocked, next].compactMap { $0 }
        guard let first = filled.first else { return nil }
        return JournalEntrySummary(
            date: entry.date,
            wentWell: well, gotInWay: blocked, tomorrowFocus: next,
            preview: previewText(from: first),
            completeness: filled.count == 3 ? .complete : .partial
        )
    }

    static func previewText(from text: String, limit: Int = 80) -> String {
        let collapsed = text.replacingOccurrences(of: "\n", with: " ")
        guard collapsed.count > limit else { return collapsed }
        return String(collapsed.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
