import AppKit

extension Notification.Name {
    /// Posted when the user clicks the app icon while it's running with no window.
    static let pfReopenMainWindow = Notification.Name("PFReopenMainWindow")
}

/// Reopens the main window when the user clicks the app icon (Dock / Finder /
/// Launchpad) while the app is still alive as a menu-bar agent with its window
/// closed — otherwise nothing happens and the app feels "stuck closed".
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NotificationCenter.default.post(name: .pfReopenMainWindow, object: nil)
        }
        return true
    }
}
