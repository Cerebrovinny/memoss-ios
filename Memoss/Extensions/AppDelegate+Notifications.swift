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

            case NotificationAction.snooze15.rawValue:
                await handleSnooze(response: response, minutes: 15)

            case NotificationAction.snooze60.rawValue:
                await handleSnooze(response: response, minutes: 60)

            case NotificationAction.snoozeCustom.rawValue:
                // Handle text input for custom duration
                if let textResponse = response as? UNTextInputNotificationResponse {
                    let minutes = parseSnoozeInput(textResponse.userText) ?? 15  // Fallback to 15 min
                    await handleSnooze(response: response, minutes: minutes)
                }

            case NotificationAction.snooze.rawValue:
                // Legacy support for old snooze action
                await handleSnooze(response: response, minutes: 15)

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
        // Extract base UUID (remove index suffix if present for recurring notifications)
        let baseId = extractBaseId(from: reminderId)

        guard let uuid = UUID(uuidString: baseId) else { return }

        let context = MemossApp.sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<Reminder>(predicate: #Predicate { $0.id == uuid })
        guard let reminder = try? context.fetch(descriptor).first else {
            return
        }

        if reminder.isRecurring {
            // Advance to next occurrence instead of marking complete
            reminder.advanceToNextOccurrence()

            // Reschedule if not completed (series not ended)
            if !reminder.isCompleted {
                NotificationService.shared.cancelAllNotifications(for: reminder)
                await NotificationService.shared.scheduleNotifications(for: reminder)
            }
        } else {
            reminder.isCompleted = true
        }

        // Remove from notification center
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [reminderId])
    }

    /// Extract base UUID from notification identifier (handles indexed recurring format)
    private func extractBaseId(from identifier: String) -> String {
        // Recurring notifications have format: uuid-index (e.g., "550e8400-e29b-41d4-a716-446655440000-5")
        // UUID format: 8-4-4-4-12 characters with hyphens
        let components = identifier.split(separator: "-")

        // Standard UUID has 5 components, recurring adds an index as 6th
        if components.count == 6, let _ = Int(components[5]) {
            return components.prefix(5).joined(separator: "-")
        }

        return identifier
    }

    @MainActor
    private func handleSnooze(response: UNNotificationResponse, minutes: Int) async {
        await NotificationService.shared.snoozeNotification(
            from: response,
            duration: TimeInterval(minutes * 60)
        )
    }

    /// Simple integer parsing for snooze duration.
    /// Placeholder "Minutes (e.g., 22)" guides users to type numbers.
    /// Returns nil for invalid input (caller handles fallback).
    private func parseSnoozeInput(_ input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minutes = Int(trimmed), minutes > 0, minutes <= 180 else {
            return nil
        }
        return minutes
    }
}
