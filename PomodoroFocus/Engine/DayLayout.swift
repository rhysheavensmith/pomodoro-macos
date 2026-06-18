import Foundation

// MARK: - Template

/// One segment of the reusable day template: either a focus set of N pomodoros
/// or a named rest break. Codable so the whole template persists as JSON.
struct TemplateSegment: Codable, Equatable, Identifiable {
    enum Kind: String, Codable { case focus, rest }
    var id: UUID
    var kind: Kind
    var pomodoros: Int   // focus
    var name: String     // rest
    var minutes: Int     // rest
    var symbol: String   // rest (SF Symbol)

    static func focus(_ n: Int, id: UUID = UUID()) -> TemplateSegment {
        .init(id: id, kind: .focus, pomodoros: n, name: "", minutes: 0, symbol: "")
    }
    static func rest(_ name: String, _ minutes: Int, _ symbol: String, id: UUID = UUID()) -> TemplateSegment {
        .init(id: id, kind: .rest, pomodoros: 0, name: name, minutes: minutes, symbol: symbol)
    }
}

// MARK: - Layout inputs / outputs

/// Value-type task input so the layout is testable without SwiftData.
struct PlannedTask: Equatable {
    let title: String
    let planned: Int
    let done: Int
}

/// One pomodoro tile in the laid-out day.
struct DayTomato: Equatable, Identifiable {
    let index: Int            // global position in the day
    let taskTitle: String?   // nil = empty/unfilled slot
    let isDone: Bool
    let isCurrent: Bool       // the single "next to do" tile
    var id: Int { index }
}

/// A contiguous run of tomatoes for one task within a focus set (or empty slots).
struct DayFocusRun: Equatable, Identifiable {
    let taskTitle: String?
    let tomatoes: [DayTomato]
    var id: Int { tomatoes.first?.index ?? -1 }
}

/// A rendered row of the day timeline.
enum DaySegment: Equatable {
    case focus([DayFocusRun])
    case rest(name: String, minutes: Int, symbol: String)
}

// MARK: - Layout

/// Pure: flows tasks onto the template's focus tomatoes in order, places breaks
/// where the template puts them, and overflows extra task pomodoros into a final
/// focus group. Stub until the tests drive it.
enum DayLayout {
    static func build(segments: [TemplateSegment], tasks: [PlannedTask]) -> [DaySegment] {
        // Flatten tasks into an ordered queue of tomato descriptors.
        struct Desc { let title: String?; let done: Bool; var current: Bool }
        var flat: [Desc] = []
        for task in tasks {
            for i in 0..<max(0, task.planned) {
                flat.append(Desc(title: task.title, done: i < task.done, current: false))
            }
        }
        if let firstIncomplete = flat.firstIndex(where: { !$0.done }) {
            flat[firstIncomplete].current = true
        }

        var result: [DaySegment] = []
        var globalIndex = 0
        var queueIndex = 0

        func makeFocus(capacity: Int) -> DaySegment {
            var slots: [DayTomato] = []
            for _ in 0..<max(0, capacity) {
                if queueIndex < flat.count {
                    let d = flat[queueIndex]
                    slots.append(DayTomato(index: globalIndex, taskTitle: d.title,
                                           isDone: d.done, isCurrent: d.current))
                    queueIndex += 1
                } else {
                    slots.append(DayTomato(index: globalIndex, taskTitle: nil,
                                           isDone: false, isCurrent: false))
                }
                globalIndex += 1
            }
            return .focus(groupRuns(slots))
        }

        for segment in segments {
            switch segment.kind {
            case .focus: result.append(makeFocus(capacity: segment.pomodoros))
            case .rest: result.append(.rest(name: segment.name, minutes: segment.minutes, symbol: segment.symbol))
            }
        }

        // Overflow: task pomodoros beyond the template's capacity get a final group.
        if queueIndex < flat.count {
            result.append(makeFocus(capacity: flat.count - queueIndex))
        }
        return result
    }

    private static func groupRuns(_ slots: [DayTomato]) -> [DayFocusRun] {
        var runs: [DayFocusRun] = []
        for slot in slots {
            if let last = runs.last, last.taskTitle == slot.taskTitle {
                runs[runs.count - 1] = DayFocusRun(taskTitle: last.taskTitle,
                                                   tomatoes: last.tomatoes + [slot])
            } else {
                runs.append(DayFocusRun(taskTitle: slot.taskTitle, tomatoes: [slot]))
            }
        }
        return runs
    }
}

/// Maps "how many focus pomodoros done today" to the named break the template
/// places after that focus set — so finishing a set starts the right rest timer.
enum TemplateSchedule {
    /// The template rest that immediately follows `focusCount` focus pomodoros,
    /// or nil if no break sits at that boundary. Stub until tests drive it.
    static func restAfter(focusCount: Int, segments: [TemplateSegment]) -> TemplateSegment? {
        var cumulativeFocus = 0
        for segment in segments {
            switch segment.kind {
            case .focus:
                cumulativeFocus += segment.pomodoros
            case .rest:
                if cumulativeFocus == focusCount { return segment }
            }
        }
        return nil
    }
}
