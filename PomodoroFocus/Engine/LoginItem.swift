import ServiceManagement

/// Thin wrapper over `SMAppService` so the app can launch at login and live
/// permanently in the menu bar. Best-effort: registration can fail for unsigned
/// / dev builds, which is swallowed.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Best-effort — ignore (e.g. unsigned/dev build, or already in desired state).
        }
    }
}
