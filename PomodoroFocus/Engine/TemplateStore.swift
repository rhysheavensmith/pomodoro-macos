import Foundation

/// Persists the reusable day template as JSON in UserDefaults (no SwiftData
/// migration needed for a value-type list of segments).
enum TemplateStore {
    static let key = "dayTemplate.v1"

    /// The default "A Day in Pomodoros" rhythm.
    static var defaultSegments: [TemplateSegment] {
        [
            .focus(4),
            .rest("Coffee break", 20, "cup.and.saucer.fill"),
            .focus(4),
            .rest("Lunch", 30, "fork.knife"),
            .focus(4),
            .rest("Walk", 20, "figure.walk"),
            .focus(2),
        ]
    }

    static func load() -> [TemplateSegment] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let segments = try? JSONDecoder().decode([TemplateSegment].self, from: data),
              !segments.isEmpty else {
            return defaultSegments
        }
        return segments
    }

    static func save(_ segments: [TemplateSegment]) {
        if let data = try? JSONEncoder().encode(segments) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
