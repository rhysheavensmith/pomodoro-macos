import SwiftUI
import SwiftData

/// Settings: timer durations, the daily plan reminder, completion sound, streak
/// rules, and the distraction blocklist (apps blocked-from-attention in a pomodoro).
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @AppStorage(AudioFeedback.enabledKey) private var completionSoundEnabled = true
    @AppStorage(PrefKeys.autoStartBreaks) private var autoStartBreaks = true
    @State private var installedApps: [InstalledApp] = []
    @State private var launchAtLogin = LoginItem.isEnabled

    private let weekdayLabels = [(1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"),
                                 (5, "Thu"), (6, "Fri"), (7, "Sat")]

    var body: some View {
        @Bindable var settings = app.settings
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(eyebrow: "PREFERENCES", title: "Settings")
                .padding([.horizontal, .top], Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
            Form {
            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { launchAtLogin = $0; LoginItem.setEnabled($0) }
                ))
            }
            Section {
                Stepper("Focus: \(settings.workMins) min", value: $settings.workMins, in: 1...60)
                Stepper("Short break: \(settings.shortBreakMins) min", value: $settings.shortBreakMins, in: 1...30)
                Stepper(dailyGoalLabel, value: dailyGoalBinding, in: 0...20)
                Toggle("Auto-start breaks", isOn: $autoStartBreaks)
            } header: {
                Text("Timer")
            } footer: {
                Text("Coffee, lunch and walk breaks are part of your day rhythm — edit them in Plan → Edit rhythm.")
            }

            Section("Alerts") {
                DatePicker("Plan-your-day reminder", selection: reminderBinding,
                           displayedComponents: .hourAndMinute)
                Toggle("Completion sound", isOn: $completionSoundEnabled)
                Toggle("Evening \u{201C}streak at risk\u{201D} nudge", isOn: $settings.streakRiskNudgeEnabled)
                    .onChange(of: settings.streakRiskNudgeEnabled) { app.applySettings() }
            }

            Section("Streak") {
                Stepper("A day counts at \(settings.streakBar) pomodoro\(settings.streakBar == 1 ? "" : "s")",
                        value: $settings.streakBar, in: 1...10)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Active days").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: Theme.Spacing.xxs) {
                        ForEach(weekdayLabels, id: \.0) { num, label in
                            let on = app.settings.activeWeekdays.contains(num)
                            Button(label) { toggleWeekday(num) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(on ? Theme.Palette.accent : .secondary)
                                .accessibilityLabel("\(fullWeekday(num))")
                                .accessibilityValue(on ? "active" : "inactive")
                        }
                    }
                }
            }

            Section("Distraction blocklist") {
                if settings.blocklistBundleIDs.isEmpty {
                    Text("No apps blocked yet. Add the apps that pull your focus during a pomodoro — switching to them will nudge you back and log a distraction.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(settings.blocklistBundleIDs, id: \.self) { bundleID in
                    HStack {
                        Image(systemName: "nosign").foregroundStyle(Theme.Palette.warning)
                        Text(InstalledApps.name(forBundleID: bundleID))
                        Spacer()
                        Button(role: .destructive) {
                            app.removeFromBlocklist(bundleID)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Remove \(InstalledApps.name(forBundleID: bundleID)) from blocklist")
                    }
                }
                Menu {
                    ForEach(availableApps) { installed in
                        Button(installed.name) { app.addToBlocklist(installed.bundleID) }
                    }
                } label: {
                    Label("Add app to block", systemImage: "plus")
                }
            }
        }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .warmCanvas()
        .onAppear { if installedApps.isEmpty { installedApps = InstalledApps.all() } }
    }

    // MARK: Derived bindings

    private var availableApps: [InstalledApp] {
        let blocked = Set(app.settings.blocklistBundleIDs.map { $0.lowercased() })
        return installedApps.filter { !blocked.contains($0.bundleID.lowercased()) }
    }

    private func fullWeekday(_ num: Int) -> String {
        ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][safe: num - 1] ?? "Day"
    }

    private var dailyGoalLabel: String {
        if let goal = app.settings.dailyGoal { return "Daily goal: \(goal) pomodoros" }
        return "Daily goal: none"
    }

    private var dailyGoalBinding: Binding<Int> {
        Binding(
            get: { app.settings.dailyGoal ?? 0 },
            set: { app.settings.dailyGoal = $0 == 0 ? nil : $0; app.applySettings() }
        )
    }

    private var reminderBinding: Binding<Date> {
        Binding(
            get: {
                let c = ReminderTime.components(fromMinutes: app.settings.planReminderMinutes)
                return Calendar.current.date(bySettingHour: c.hour, minute: c.minute, second: 0, of: Date()) ?? Date()
            },
            set: { newDate in
                let comp = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                app.settings.planReminderMinutes = ReminderTime.minutes(hour: comp.hour ?? 9, minute: comp.minute ?? 0)
                app.applySettings()
            }
        )
    }

    private func toggleWeekday(_ num: Int) {
        var days = app.settings.activeWeekdays
        if days.contains(num) { days.removeAll { $0 == num } } else { days.append(num) }
        app.settings.activeWeekdays = days.sorted()
        app.applySettings()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
