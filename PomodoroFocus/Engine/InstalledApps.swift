import Foundation
import AppKit

struct InstalledApp: Identifiable, Hashable {
    let bundleID: String
    let name: String
    var id: String { bundleID }
}

/// Discovers user-facing apps for the blocklist picker. This is I/O glue
/// (filesystem + bundle reads), so it's verified by running rather than unit-tested.
enum InstalledApps {
    static func all() -> [InstalledApp] {
        let directories = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]
        let fm = FileManager.default
        var seen = Set<String>()
        var apps: [InstalledApp] = []

        for dir in directories {
            guard let entries = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }
            for url in entries where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url),
                      let bundleID = bundle.bundleIdentifier,
                      !seen.contains(bundleID) else { continue }
                seen.insert(bundleID)
                apps.append(InstalledApp(bundleID: bundleID, name: displayName(url)))
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Best-effort display name for a bundle ID already in the blocklist.
    static func name(forBundleID bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return bundleID
        }
        return displayName(url)
    }

    private static func displayName(_ url: URL) -> String {
        FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}
