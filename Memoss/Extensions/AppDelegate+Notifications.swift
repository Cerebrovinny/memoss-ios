//
//  AppDelegate+Notifications.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 22/01/2026.
//

import SwiftData
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    /// Shared ModelContainer - set by MemossApp on launch
    var modelContainer: ModelContainer?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationService.shared.registerCategories()
        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification when app is in foreground - show banner
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Handle notification tap or action button
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let reminderId = response.notification.request.identifier

        Task { @MainActor in
            switch response.actionIdentifier {
            case NotificationAction.markComplete.rawValue:
                await handleMarkComplete(reminderId: reminderId)
            case NotificationAction.snooze.rawValue:
                await handleSnooze(response: response)
            case UNNotificationDefaultActionIdentifier:
                // User tapped notification body - app opens to dashboard
                break
            default:
                break
            }
            completionHandler()
        }
    }

    // MARK: - Action Handlers

    @MainActor
    private func handleMarkComplete(reminderId: String) async {
        guard let uuid = UUID(uuidString: reminderId),
              let context = modelContainer?.mainContext else {
            return
        }

        let descriptor = FetchDescriptor<Reminder>(predicate: #Predicate { $0.id == uuid })
        guard let reminder = try? context.fetch(descriptor).first else {
            return
        }

        reminder.isCompleted = true
        // SwiftData auto-saves, no explicit save needed

        // Remove from notification center
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [reminderId])
    }

    @MainActor
    private func handleSnooze(response: UNNotificationResponse) async {
        await NotificationService.shared.snoozeNotification(
            from: response,
            duration: 15 * 60  // 15 minutes
        )
    }
}
