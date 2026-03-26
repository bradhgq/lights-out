import AppKit
import Foundation

class NotificationManager {
    private var hasBundle: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    func requestPermission() {
        guard hasBundle else { return }
        // UNUserNotificationCenter requires a bundle, so we only use it when bundled.
        // For unbundled debug runs, we fall back to osascript notifications.
    }

    func postAmberNotification(checklist: [String]) {
        let body = checklist.map { "☐ \($0)" }.joined(separator: "\n")
        postNotification(
            title: "Wind-Down Starting Soon",
            subtitle: "Time to start your bedtime routine",
            body: body
        )
    }

    func postWindDownNotification() {
        postNotification(
            title: "Wind-Down Active",
            subtitle: "",
            body: "Blocked apps have been closed. Time to wrap up."
        )
    }

    func postLightsOutNotification() {
        postNotification(
            title: "Lights Out",
            subtitle: "",
            body: "Go to bed. All blocked apps are disabled until morning."
        )
    }

    private func postNotification(title: String, subtitle: String, body: String) {
        // Use osascript for notifications — works with or without a bundle
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        let escapedSubtitle = subtitle.replacingOccurrences(of: "\"", with: "\\\"")

        var script = "display notification \"\(escapedBody)\" with title \"\(escapedTitle)\""
        if !escapedSubtitle.isEmpty {
            script += " subtitle \"\(escapedSubtitle)\""
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }
}
