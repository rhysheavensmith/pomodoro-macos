import SwiftUI
import SwiftData

@main
struct PomodoroFocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var app = AppModel()

    /// One shared SwiftData store for the whole app.
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Day.self,
            TaskItem.self,
            PomodoroSession.self,
            DistractionEvent.self,
            AppSettings.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        // The always-accessible control center. Wiring the coordinator here means
        // it's configured as soon as the menu-bar item appears (app launch).
        MenuBarExtra {
            MenuBarView()
                .environment(app)
                .modelContainer(sharedModelContainer)
                .task { app.configure(context: sharedModelContainer.mainContext) }
        } label: {
            MenuBarLabel(context: sharedModelContainer.mainContext)
                .environment(app)
        }
        .menuBarExtraStyle(.window)

        // Main window: Plan + Dashboard. The Focus Shield is an AppKit floating
        // panel managed by the coordinator, not a scene.
        Window("Pomodoro Focus", id: WindowID.main) {
            RootWindowView()
                .environment(app)
                .modelContainer(sharedModelContainer)
                .task { app.configure(context: sharedModelContainer.mainContext) }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 920, height: 640)
    }
}

/// Stable window identifiers used with `openWindow` / `dismissWindow`.
enum WindowID {
    static let main = "main"
}
