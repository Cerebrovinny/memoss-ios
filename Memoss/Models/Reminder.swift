//
//  Reminder.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 22/01/2026.
//

import SwiftData
import Foundation

@Model
final class Reminder {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String?
    var scheduledDate: Date
    var isCompleted: Bool

    // Recurrence - stored as Codable Data for SwiftData compatibility
    var recurrenceRuleData: Data?
    var recurrenceEndDate: Date?

    // Sync support
    var remoteID: String?
    var createdAt: Date?
    var updatedAt: Date?

    @Relationship(deleteRule: .nullify)
    var tags: [Tag] = []

    // Snooze support - not persisted to SwiftData, transient only
    @Transient var snoozedUntil: Date?

    // MARK: - Computed Properties

    /// Access recurrence rule with automatic encoding/decoding
    var recurrenceRule: RecurrenceRule {
        get {
            guard let data = recurrenceRuleData else { return .none }
            return (try? JSONDecoder().decode(RecurrenceRule.self, from: data)) ?? .none
        }
        set {
            recurrenceRuleData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Convenience property to check if this reminder recurs
    var isRecurring: Bool {
        recurrenceRule != .none
    }

    /// The next time this reminder will alert (accounts for recurrence and snooze)
    var nextAlertDate: Date {
        // If snoozed and snooze time is in the future, show that
        if let snoozeDate = snoozedUntil, snoozeDate > Date() {
            return snoozeDate
        }

        // For recurring reminders, find the next upcoming occurrence
        if isRecurring {
            let upcomingOccurrences = recurrenceRule.occurrences(startingFrom: scheduledDate, count: 1)
            return upcomingOccurrences.first ?? scheduledDate
        }

        return scheduledDate
    }

    /// Whether the next alert is at a different time than the base scheduled time
    var hasUpcomingAlertDifferentFromBase: Bool {
        let calendar = Calendar.current
        return !calendar.isDate(nextAlertDate, equalTo: scheduledDate, toGranularity: .minute)
    }

    // MARK: - Initialization

    init(title: String, scheduledDate: Date = .now, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.scheduledDate = scheduledDate
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Recurrence Helpers

    /// Advance to the next occurrence (for completing recurring reminders)
    func advanceToNextOccurrence() {
        guard let nextDate = recurrenceRule.nextOccurrence(after: scheduledDate) else { return }

        // Check if we've passed the end date
        if let endDate = recurrenceEndDate, nextDate > endDate {
            // Series complete - mark as done
            isCompleted = true
            return
        }

        scheduledDate = nextDate
    }
}
