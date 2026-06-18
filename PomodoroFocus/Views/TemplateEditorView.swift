import SwiftUI

/// Edit the reusable day rhythm: add/remove/reorder focus sets and named breaks.
/// Styled to echo the Plan timeline — focus cards show a tomato preview, break
/// cards use the warm ribbon tone.
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
                        row($segment)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .onDelete { template.remove(atOffsets: $0) }
                    .onMove { template.move(fromOffsets: $0, toOffset: $1) }
                } footer: {
                    Text("Tasks flow into the focus tomatoes in order; breaks fall where you place them. Drag to reorder, swipe to delete.")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.top, Theme.Spacing.xs)
                }

                Section {
                    HStack(spacing: Theme.Spacing.sm) {
                        Button { withAnimation(Theme.Motion.quick) { template.append(.focus(4)) } } label: {
                            Label("Focus set", systemImage: "plus")
                        }
                        .buttonStyle(SoftPillButtonStyle(tint: Theme.Palette.focus))

                        Button { withAnimation(Theme.Motion.quick) { template.append(.rest("Break", 15, "cup.and.saucer.fill")) } } label: {
                            Label("Break", systemImage: "plus")
                        }
                        .buttonStyle(SoftPillButtonStyle(tint: Theme.Palette.breakColor))
                        Spacer()
                    }
                    Button(role: .destructive) {
                        withAnimation(Theme.Motion.quick) { template = TemplateStore.defaultSegments }
                    } label: {
                        Label("Reset to default rhythm", systemImage: "arrow.counterclockwise")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .padding(.top, Theme.Spacing.xs)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .warmCanvas()
            .navigationTitle("Edit your rhythm")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .frame(minWidth: 460, minHeight: 560)
    }

    @ViewBuilder private func row(_ segment: Binding<TemplateSegment>) -> some View {
        if segment.wrappedValue.kind == .focus {
            focusRow(segment)
        } else {
            breakRow(segment)
        }
    }

    private func focusRow(_ segment: Binding<TemplateSegment>) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            HStack(spacing: 4) {
                ForEach(0..<min(max(segment.wrappedValue.pomodoros, 1), 8), id: \.self) { _ in
                    Circle()
                        .fill(LinearGradient(colors: [Theme.Palette.focusSoft, Theme.Palette.focus],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 13, height: 13)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Focus set").font(.headline)
                Text("\(segment.wrappedValue.pomodoros) pomodoro\(segment.wrappedValue.pomodoros == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Stepper("", value: segment.pomodoros, in: 1...8).labelsHidden().fixedSize()
        }
        .padding(Theme.Spacing.md)
        .card()
        .padding(.vertical, Theme.Spacing.xxs)
    }

    private func breakRow(_ segment: Binding<TemplateSegment>) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: segment.wrappedValue.symbol).foregroundStyle(Theme.Palette.breakColor)
                TextField("Break name", text: segment.name).textFieldStyle(.plain).font(.headline)
            }
            HStack {
                Picker("", selection: segment.symbol) {
                    ForEach(breakSymbols, id: \.1) { name, symbol in
                        Label(name, systemImage: symbol).tag(symbol)
                    }
                }
                .labelsHidden()
                .fixedSize()
                Spacer()
                Stepper("\(segment.wrappedValue.minutes) min", value: segment.minutes, in: 5...90, step: 5)
                    .fixedSize()
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Palette.ribbonWarm, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Palette.breakColor.opacity(0.18)))
        .padding(.vertical, Theme.Spacing.xxs)
    }
}
