import SwiftUI

/// Main window shell: the Plan and Dashboard tabs.
struct RootWindowView: View {
    enum Tab: Hashable { case plan, journal, dashboard, settings }
    @State private var selection: Tab = .plan

    var body: some View {
        VStack(spacing: 0) {
            ActiveTimerBar()
            TabView(selection: $selection) {
                PlanView()
                    .tabItem { Label("Plan", systemImage: "checklist") }
                    .tag(Tab.plan)

                JournalView()
                    .tabItem { Label("Journal", systemImage: "book.closed") }
                    .tag(Tab.journal)

                DashboardView()
                    .tabItem { Label("Dashboard", systemImage: "chart.bar.xaxis") }
                    .tag(Tab.dashboard)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(Tab.settings)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .overlay { CelebrationOverlay() }
    }
}
