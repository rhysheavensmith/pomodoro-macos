import SwiftUI

/// Edit the reusable day rhythm: add/remove/reorder focus sets and named breaks.
struct TemplateEditorView: View {
    @Binding var template: [TemplateSegment]
    @Environment(\.dismiss) private var dismiss

    private let breakSymbols = [
        ("Coffee", "cup.and.saucer.fill"),
        ("Lunch", "fork.knife"),
        ("Walk", "figure.walk"),
        ("Rest", "moon.fill"),
        ("Stretch", "figure.cooldown"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($template) { $segment in
                        if segment.kind == .focus {
                            Stepper(value: $segment.pomodoros, in: 1...8) {
                                Label("Focus · \(segment.pomodoros) pomodoros", systemImage: "circle.grid.2x2.fill")
                                    .foregroundStyle(Theme.Palette.focus)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                HStack {
                                    Image(systemName: segment.symbol).foregroundStyle(Theme.Palette.breakColor)
                                    TextField("Break name", text: $segment.name)
                                }
                                Stepper(value: $segment.minutes, in: 5...90, step: 5) {
                                    Text("\(segment.minutes) min").foregroundStyle(.secondary)
                                }
                                Picker("Icon", selection: $segment.symbol) {
                                    ForEach(breakSymbols, id: \.1) { name, symbol in
                                        Label(name, systemImage: symbol).tag(symbol)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }
                    .onDelete { template.remove(atOffsets: $0) }
                    .onMove { template.move(fromOffsets: $0, toOffset: $1) }
                } footer: {
                    Text("Tasks flow into the focus tomatoes in order; breaks fall where you place them.")
                }

                Section {
                    Button { template.append(.focus(4)) } label: {
                        Label("Add focus set", systemImage: "plus.circle")
                    }
                    Button { template.append(.rest("Break", 15, "cup.and.saucer.fill")) } label: {
                        Label("Add break", systemImage: "plus.circle")
                    }
                    Button(role: .destructive) { template = TemplateStore.defaultSegments } label: {
                        Label("Reset to default", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("Edit your rhythm")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 520)
    }
}
