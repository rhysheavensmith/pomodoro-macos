import SwiftUI
import SwiftData

/// The morning planning ritual, as a "Day in Pomodoros" timeline: the template
/// defines the rhythm (focus sets + named breaks); your tasks flow into the
/// focus tomatoes.
struct PlanView: View {
    @Environment(AppModel.self) private var app
    @Query(sort: \TaskItem.order) private var allTasks: [TaskItem]

    @State private var template = TemplateStore.load()
    @State private var newTitle = ""
    @State private var newAllocation = 2
    @State private var intention = ""
    @State private var intentionLoaded = false
    @State private var carryCandidates: [TaskItem] = []
    @State private var editingRhythm = false

    private var todays: [TaskItem] {
        allTasks.filter { task in
            guard let date = task.day?.date else { return false }
            return Calendar.current.isDate(date, inSameDayAs: Date())
        }
    }
    private var plannedTasks: [PlannedTask] {
        todays.map { PlannedTask(title: $0.title, planned: $0.plannedPomodoros, done: $0.completedPomodoros) }
    }
    private var layout: [DaySegment] { DayLayout.build(segments: template, tasks: plannedTasks) }
    private var totalPlanned: Int { todays.reduce(0) { $0 + $1.plannedPomodoros } }
    private var totalDone: Int { todays.reduce(0) { $0 + $1.completedPomodoros } }

    private func task(for title: String) -> TaskItem? { todays.first { $0.title == title } }

    private var actions: TimelineActions {
        TimelineActions(
            isRunning: app.timer.phase == .running,
            onStart: { if let t = task(for: $0) { app.startPomodoro(for: t) } },
            onToggleDone: { if let t = task(for: $0) { app.toggleDone(t) } },
            onAdjust: { title, delta in
                if let t = task(for: title) { app.setAllocation(t, to: t.plannedPomodoros + delta) }
            },
            onDelete: { if let t = task(for: $0) { app.delete(t) } }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                header
                intentionField
                if !carryCandidates.isEmpty { carryOverStrip }
                addTaskRow
                DayTimelineView(segments: layout, actions: actions)
                    .padding(.top, Theme.Spacing.xs)
                editRhythmButton
            }
            .padding(Theme.Spacing.xl)
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .warmCanvas()
        .sheet(isPresented: $editingRhythm) {
            TemplateEditorView(template: $template)
        }
        .onAppear {
            if !intentionLoaded {
                intention = app.ensureToday()?.dayIntention ?? ""
                intentionLoaded = true
            }
            carryCandidates = app.carryOverCandidates()
        }
        .onChange(of: allTasks.count) { carryCandidates = app.carryOverCandidates() }
        .onChange(of: template) { TemplateStore.save(template) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("A DAY IN POMODOROS")
                .font(.caption.weight(.bold))
                .tracking(2)
                .foregroundStyle(Theme.Palette.focus.opacity(0.75))
            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 30, weight: .bold, design: .rounded))
            HStack(spacing: Theme.Spacing.xs) {
                ProgressView(value: Double(totalDone), total: Double(max(totalPlanned, 1)))
                    .tint(Theme.Palette.accent)
                    .frame(maxWidth: 180)
                Text("\(totalDone) of \(totalPlanned)")
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var intentionField: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "target").foregroundStyle(Theme.Palette.accent)
            TextField("Today's intention…", text: $intention)
                .textFieldStyle(.plain)
                .onChange(of: intention) { app.setIntention(intention) }
        }
        .padding(Theme.Spacing.sm)
        .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).strokeBorder(.quaternary))
    }

    @ViewBuilder private var carryOverStrip: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label("Carry over from last time", systemImage: "arrow.uturn.forward")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(carryCandidates) { carried in
                        Button { app.carryOver(carried) } label: {
                            HStack(spacing: Theme.Spacing.xxs) {
                                Image(systemName: "plus.circle.fill")
                                Text(carried.title).lineLimit(1)
                                Text("\(max(1, carried.plannedPomodoros - carried.completedPomodoros))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityLabel("Carry over \(carried.title)")
                    }
                }
            }
        }
    }

    private var addTaskRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Add a task…", text: $newTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addTask)
            Stepper(value: $newAllocation, in: 1...12) {
                HStack(spacing: 2) {
                    Image(systemName: "circle.grid.2x2.fill").foregroundStyle(Theme.Palette.focus)
                    Text("\(newAllocation)")
                }
            }
            .fixedSize()
            .accessibilityLabel("Pomodoros to allocate: \(newAllocation)")
            Button(action: addTask) {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Palette.accent)
            .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var editRhythmButton: some View {
        Button { editingRhythm = true } label: {
            Label("Edit rhythm", systemImage: "slider.horizontal.3")
        }
        .buttonStyle(SoftPillButtonStyle(tint: Theme.Palette.focus))
        .padding(.top, Theme.Spacing.xs)
    }

    private func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        app.addTask(title: title, plannedPomodoros: newAllocation)
        newTitle = ""
        newAllocation = 2
    }
}
