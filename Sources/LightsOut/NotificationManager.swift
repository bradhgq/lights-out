import AppKit
import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let checklistActionID = "SHOW_CHECKLIST"
    static let checklistCategoryID = "CHECKLIST_CATEGORY"

    var onNotificationClicked: (() -> Void)?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        let center = UNUserNotificationCenter.current()

        // Register action for checklist notifications
        let showAction = UNNotificationAction(
            identifier: Self.checklistActionID,
            title: "Show Checklist",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.checklistCategoryID,
            actions: [showAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])

        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("[LightsOut] Notification permission error: \(error)")
            } else if !granted {
                print("[LightsOut] Notification permission denied")
            }
        }
    }

    func postAmberNotification(checklist: [String]) {
        let body = checklist.map { "☐ \($0)" }.joined(separator: "\n")
        postNotification(
            id: "amber",
            title: "Wind-Down Starting Soon",
            subtitle: "Time to start your bedtime routine",
            body: body,
            categoryID: Self.checklistCategoryID
        )
    }

    func postWindDownNotification() {
        postNotification(
            id: "winddown",
            title: "Wind-Down Active",
            subtitle: "",
            body: "Blocked apps have been closed. Time to wrap up."
        )
    }

    func postLightsOutNotification() {
        postNotification(
            id: "lightsout",
            title: "Lights Out",
            subtitle: "",
            body: "Go to bed. All blocked apps are disabled until morning."
        )
    }

    private func postNotification(id: String, title: String, subtitle: String, body: String, categoryID: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        if !subtitle.isEmpty { content.subtitle = subtitle }
        content.body = body
        content.sound = .default
        if let categoryID { content.categoryIdentifier = categoryID }

        let request = UNNotificationRequest(identifier: "lightsout-\(id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[LightsOut] Failed to post notification: \(error)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when notification is clicked or action is tapped
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        onNotificationClicked?()
        completionHandler()
    }

    /// Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
