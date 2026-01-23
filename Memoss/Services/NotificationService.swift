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

    private let maxRecurringNotifications = 50  // Leave buffer under 64 limit

    private init() {}

    // MARK: - Public API

    /// Schedule notification(s) for a reminder
    /// For one-time reminders: schedules a single notification
    /// For recurring reminders: schedules next N occurrences
    func scheduleNotifications(for reminder: Reminder) async {
        // Skip if completed
        guard !reminder.isCompleted else { return }

        if reminder.isRecurring {
            await scheduleRecurringNotifications(for: reminder)
        } else {
            await scheduleNotification(for: reminder)
        }
    }

    /// Schedule a single notification for a one-time reminder
    func scheduleNotification(for reminder: Reminder) async {
        // Skip if scheduled date is in the past
        guard reminder.scheduledDate > Date.now else { return }

        let content = makeNotificationContent(for: reminder)

        let components = Calendar.current.dateComponents(
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
        }
    }

    /// Cancel all pending notifications for a reminder (both recurring and single)
    func cancelAllNotifications(for reminder: Reminder) {
        // Cancel indexed notifications (recurring)
        let recurringIdentifiers = (0..<64).map { "\(reminder.id.uuidString)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: recurringIdentifiers)

        // Cancel single notification ID (non-recurring)
        cancelNotification(for: reminder)
    }

    /// Cancel a single pending notification for the given reminder
    func cancelNotification(for reminder: Reminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [reminder.id.uuidString]
        )
    }

    /// Cancel a delivered notification
    func cancelDeliveredNotification(for reminder: Reminder) {
        // Cancel both single and indexed delivered notifications
        var identifiers = [reminder.id.uuidString]
        identifiers.append(contentsOf: (0..<64).map { "\(reminder.id.uuidString)-\($0)" })
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    // MARK: - Recurring Notifications

    private func scheduleRecurringNotifications(for reminder: Reminder) async {
        // Generate occurrences
        var occurrences = reminder.recurrenceRule.occurrences(
            startingFrom: reminder.scheduledDate,
            count: maxRecurringNotifications
        )

        // Filter by end date if set
        if let endDate = reminder.recurrenceEndDate {
            occurrences = occurrences.filter { $0 <= endDate }
        }

        // Schedule each occurrence
        for (index, date) in occurrences.enumerated() {
            await scheduleNotificationInstance(for: reminder, at: date, index: index)
        }
    }

    private func scheduleNotificationInstance(for reminder: Reminder, at date: Date, index: Int) async {
        let content = makeNotificationContent(for: reminder, isRecurring: true)

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let identifier = "\(reminder.id.uuidString)-\(index)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Notification Content

    private func makeNotificationContent(for reminder: Reminder, isRecurring: Bool = false) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Memoss"
        content.body = reminder.title
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.reminder.rawValue
        content.userInfo = [
            "reminderTitle": reminder.title,
            "isRecurring": isRecurring
        ]
        return content
    }

    // MARK: - Categories

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

    func snoozeNotification(from response: UNNotificationResponse, duration: TimeInterval) async {
        let originalContent = response.notification.request.content
        let reminderId = response.notification.request.identifier

        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [reminderId])

        let reminderTitle = originalContent.userInfo["reminderTitle"] as? String ?? originalContent.body
        let isRecurring = originalContent.userInfo["isRecurring"] as? Bool ?? false

        let content = UNMutableNotificationContent()
        content.title = "Memoss"
        content.body = reminderTitle
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.reminder.rawValue
        content.userInfo = [
            "reminderTitle": reminderTitle,
            "isRecurring": isRecurring
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)

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
