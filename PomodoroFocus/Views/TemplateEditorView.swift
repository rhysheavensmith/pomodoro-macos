import SwiftUI

/// Edit the reusable day rhythm. Styled to match the rest of the app: warm
/// canvas, the same eyebrow + rounded-title header, the shared card surface for
/// focus sets, and the warm ribbon tone for breaks — soft and borderless.
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
        VStack(spacing: 0) {
            header

            List {
                Section {
                    ForEach($template) { $segment in
                        row($segment)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: Theme.Spacing.lg,
                                                      bottom: Theme.Spacing.xs, trailing: Theme.Spacing.lg))
                    }
                    .onDelete { template.remove(atOffsets: $0) }
                    .onMove { template.move(fromOffsets: $0, toOffset: $1) }
                } footer: {
                    footer
                        .listRowInsets(EdgeInsets(top: Theme.Spacing.sm, leading: Theme.Spacing.lg,
                                                  bottom: Theme.Spacing.xl, trailing: Theme.Spacing.lg))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
        }
        .frame(width: 480, height: 600)
        .warmCanvas()
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("EDIT YOUR RHYTHM")
                    .font(.caption2.weight(.bold)).tracking(2)
                    .foregroundStyle(Theme.Palette.focus.opacity(0.75))
                Text("Shape your day")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(SoftPillButtonStyle(tint: Theme.Palette.accent))
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.sm)
    }

    // MARK: Footer (add / reset / hint)

    private var footer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
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
                Label("Reset to default rhythm", systemImage: "arrow.counterclockwise").font(.subheadline)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Text("Tasks flow into the focus tomatoes in order; breaks fall where you place them. Drag to reorder, swipe to delete.")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.top, Theme.Spacing.xxs)
        }
    }

    // MARK: Rows

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
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}
