import Foundation
import SwiftData

/// One calendar day's plan. `date` is normalized to the start of the day.
/// Created during the morning planning ritual (the Hooked "Investment" phase).
@Model
final class Day {
    /// Start-of-day for the day this plan represents. Unique per day.
    var date: Date
    /// When the user completed the planning ritual (used for the morning trigger).
    var plannedAt: Date?
    /// Optional one-line intention for the day.
    var dayIntention: String?

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.day)
    var tasks: [TaskItem] = []

    init(date: Date, plannedAt: Date? = nil, dayIntention: String? = nil) {
        self.date = date
        self.plannedAt = plannedAt
        self.dayIntention = dayIntention
    }
}
