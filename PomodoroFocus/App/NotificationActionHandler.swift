import UserNotifications

/// Routes taps on notification action buttons (e.g. "Start break", "Start focus")
/// back into the coordinator, and lets notifications appear while the app is
/// foregrounded.
@MainActor
final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate {
    weak var app: AppModel?

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.actionIdentifier
        Task { @MainActor in
            switch action {
            case NotificationScheduler.Action.startBreak:
                app?.startShortBreak()
            case NotificationScheduler.Action.startFocus:
                if let task = app?.nextUnfinishedTask() { app?.startPomodoro(for: task) }
            default:
                break
            }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
