//
//  NotificationService.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 22/01/2026.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    // MARK: - Scheduling

    /// Schedule a notification for the given reminder
    /// - Parameter reminder: The reminder to schedule a notification for
    func scheduleNotification(for reminder: Reminder) async {
        // Skip if scheduled date is in the past
        guard reminder.scheduledDate > Date.now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Memoss"
        content.body = reminder.title
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.reminder.rawValue
        content.userInfo = ["reminderTitle": reminder.title]

        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.scheduledDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Notification scheduling failed - reminder still saved
            // Could log error for debugging
        }
    }

    /// Cancel a pending notification for the given reminder
    /// - Parameter reminder: The reminder whose notification should be cancelled
    func cancelNotification(for reminder: Reminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [reminder.id.uuidString]
        )
    }

    /// Cancel a delivered (shown) notification for the given reminder
    /// - Parameter reminder: The reminder whose notification should be removed from Notification Center
    func cancelDeliveredNotification(for reminder: Reminder) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [reminder.id.uuidString]
        )
    }

    // MARK: - Categories

    /// Register notification categories with action buttons
    func registerCategories() {
        let markCompleteAction = UNNotificationAction(
            identifier: NotificationAction.markComplete.rawValue,
            title: "Mark Complete",
            options: [.destructive]
        )

        let snoozeAction = UNNotificationAction(
            identifier: NotificationAction.snooze.rawValue,
            title: "Snooze (15 min)",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: NotificationCategory.reminder.rawValue,
            actions: [markCompleteAction, snoozeAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Snooze

    /// Snooze a notification by rescheduling it
    /// - Parameters:
    ///   - response: The notification response containing original content with userInfo
    ///   - duration: How long to snooze (in seconds)
    func snoozeNotification(from response: UNNotificationResponse, duration: TimeInterval) async {
        let originalContent = response.notification.request.content
        let reminderId = response.notification.request.identifier

        // Remove the delivered notification
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [reminderId])

        // Get original title from userInfo (stored when notification was first scheduled)
        let reminderTitle = originalContent.userInfo["reminderTitle"] as? String ?? originalContent.body

        // Schedule new notification with preserved title
        let content = UNMutableNotificationContent()
        content.title = "Memoss"
        content.body = reminderTitle
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.reminder.rawValue
        content.userInfo = ["reminderTitle": reminderTitle]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)

        // Use same identifier so cancel still works
        let request = UNNotificationRequest(
            identifier: reminderId,
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Constants

enum NotificationCategory: String {
    case reminder = "REMINDER_CATEGORY"
}

enum NotificationAction: String {
    case markComplete = "MARK_COMPLETE_ACTION"
    case snooze = "SNOOZE_ACTION"
}
