import Foundation
import AppKit
import Observation

/// Watches the frontmost app while a focus session is armed. When the user
/// switches to a blocklisted app it flags `isDistractedNow`; when they return it
/// reports how long they were away via `onDistraction`. Only the pure
/// `isBlocklisted` matcher is unit-tested; the `NSWorkspace` wiring is I/O glue
/// verified by running the app (no Accessibility permission required).
@MainActor
@Observable
final class DistractionMonitor {

    private(set) var isDistractedNow = false
    var onDistraction: ((_ appName: String, _ bundleID: String, _ secondsAway: TimeInterval) -> Void)?

    @ObservationIgnored private var blocklist: [String] = []
    @ObservationIgnored private var armed = false
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var distractionStart: Date?
    @ObservationIgnored private var distractionApp: (name: String, bundleID: String)?

    func arm(blocklist: [String]) {
        self.blocklist = blocklist
        armed = true
        isDistractedNow = false
        distractionStart = nil
        distractionApp = nil
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self else { return }
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                self.handleActivation(bundleID: app?.bundleIdentifier, name: app?.localizedName)
            }
        }
    }

    func disarm() {
        armed = false
        finalizeIfNeeded()
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observer = nil
        isDistractedNow = false
    }

    private func handleActivation(bundleID: String?, name: String?) {
        guard armed else { return }
        if Self.isBlocklisted(bundleID, in: blocklist) {
            if distractionStart == nil {
                distractionStart = Date()
                distractionApp = (name ?? bundleID ?? "App", bundleID ?? "")
                isDistractedNow = true
            }
        } else {
            finalizeIfNeeded()
        }
    }

    private func finalizeIfNeeded() {
        guard let start = distractionStart, let app = distractionApp else { return }
        onDistraction?(app.name, app.bundleID, Date().timeIntervalSince(start))
        distractionStart = nil
        distractionApp = nil
        isDistractedNow = false
    }

    /// Pure matcher (case-insensitive exact match; nil never matches).
    nonisolated static func isBlocklisted(_ bundleID: String?, in list: [String]) -> Bool {
        guard let bundleID else { return false }
        return list.contains { $0.caseInsensitiveCompare(bundleID) == .orderedSame }
    }
}
