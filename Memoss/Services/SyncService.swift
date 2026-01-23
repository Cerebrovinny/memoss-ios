//
//  SyncService.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 23/01/2026.
//

import Combine
import Foundation
import SwiftData

// MARK: - Remote Models

nonisolated struct RemoteReminder: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let notes: String?
    let scheduledDate: Date
    let isCompleted: Bool
    let recurrenceRule: RemoteRecurrenceRule?
    let tagIDs: [String]
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, notes
        case scheduledDate = "scheduled_date"
        case isCompleted = "is_completed"
        case recurrenceRule = "recurrence_rule"
        case tagIDs = "tag_ids"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct RemoteRecurrenceRule: Codable, Sendable {
    let type: String
    let weekday: Int?
    let day: Int?
    let endDate: Date?

    enum CodingKeys: String, CodingKey {
        case type, weekday, day
        case endDate = "end_date"
    }
}

nonisolated struct RemoteTag: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let colorHex: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case colorHex = "color_hex"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Create/Update Inputs

nonisolated struct CreateReminderInput: Encodable, Sendable {
    let title: String
    let notes: String?
    let scheduledDate: Date
    let isCompleted: Bool
    let recurrenceRule: RemoteRecurrenceRule?
    let tagIDs: [String]

    enum CodingKeys: String, CodingKey {
        case title, notes
        case scheduledDate = "scheduled_date"
        case isCompleted = "is_completed"
        case recurrenceRule = "recurrence_rule"
        case tagIDs = "tag_ids"
    }
}

nonisolated struct UpdateReminderInput: Encodable, Sendable {
    let title: String?
    let notes: String?
    let scheduledDate: Date?
    let isCompleted: Bool?
    let recurrenceRule: RemoteRecurrenceRule?
    let tagIDs: [String]?

    enum CodingKeys: String, CodingKey {
        case title, notes
        case scheduledDate = "scheduled_date"
        case isCompleted = "is_completed"
        case recurrenceRule = "recurrence_rule"
        case tagIDs = "tag_ids"
    }
}

nonisolated struct CreateTagInput: Encodable, Sendable {
    let name: String
    let colorHex: String

    enum CodingKeys: String, CodingKey {
        case name
        case colorHex = "color_hex"
    }
}

nonisolated struct UpdateTagInput: Encodable, Sendable {
    let name: String?
    let colorHex: String?

    enum CodingKeys: String, CodingKey {
        case name
        case colorHex = "color_hex"
    }
}

// MARK: - Sync Service

final class SyncService: ObservableObject, @unchecked Sendable {
    static let shared = SyncService()

    @MainActor @Published private(set) var isSyncing = false
    @MainActor @Published private(set) var lastSyncDate: Date?
    @MainActor @Published private(set) var syncError: Error?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        Task { @MainActor in
            self.lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
        }
    }

    @MainActor
    var isSyncEnabled: Bool {
        return apiClient.isAuthenticated
    }

    // MARK: - Full Sync

    func syncAll(modelContext: ModelContext) async {
        let enabled = await MainActor.run { isSyncEnabled }
        guard enabled else { return }

        await MainActor.run {
            isSyncing = true
            syncError = nil
        }

        do {
            try await syncTags(modelContext: modelContext)
            try await syncReminders(modelContext: modelContext)

            await MainActor.run {
                lastSyncDate = Date()
                UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
            }
        } catch {
            await MainActor.run {
                syncError = error
            }
        }

        await MainActor.run {
            isSyncing = false
        }
    }

    // MARK: - Tag Sync

    private func syncTags(modelContext: ModelContext) async throws {
        let remoteTags: [RemoteTag] = try await apiClient.request(Endpoint(path: "/v1/tags"))

        try await MainActor.run {
            let localTags = try modelContext.fetch(FetchDescriptor<Tag>())

            _ = Dictionary(uniqueKeysWithValues: remoteTags.map { ($0.id, $0) })
            let localTagMap = Dictionary(uniqueKeysWithValues: localTags.compactMap { tag -> (String, Tag)? in
                guard let id = tag.remoteID else { return nil }
                return (id, tag)
            })

            for remoteTag in remoteTags {
                if let localTag = localTagMap[remoteTag.id] {
                    if remoteTag.updatedAt > (localTag.updatedAt ?? Date.distantPast) {
                        localTag.name = remoteTag.name
                        localTag.colorHex = remoteTag.colorHex
                        localTag.updatedAt = remoteTag.updatedAt
                    }
                } else {
                    let newTag = Tag(name: remoteTag.name, colorHex: remoteTag.colorHex)
                    newTag.remoteID = remoteTag.id
                    newTag.createdAt = remoteTag.createdAt
                    newTag.updatedAt = remoteTag.updatedAt
                    modelContext.insert(newTag)
                }
            }

            try modelContext.save()
        }

        let localOnlyTags = try await MainActor.run {
            let localTags = try modelContext.fetch(FetchDescriptor<Tag>())
            return localTags.filter { $0.remoteID == nil }.map { (id: $0.id, name: $0.name, colorHex: $0.colorHex) }
        }

        for tagData in localOnlyTags {
            let input = CreateTagInput(name: tagData.name, colorHex: tagData.colorHex)
            let created: RemoteTag = try await apiClient.request(
                Endpoint(path: "/v1/tags", method: .POST, body: input)
            )

            let tagID = tagData.id
            await MainActor.run {
                let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.id == tagID })
                if let tag = try? modelContext.fetch(descriptor).first {
                    tag.remoteID = created.id
                    tag.updatedAt = created.updatedAt
                }
            }
        }

        try await MainActor.run {
            try modelContext.save()
        }
    }

    // MARK: - Reminder Sync

    private func syncReminders(modelContext: ModelContext) async throws {
        let remoteReminders: [RemoteReminder] = try await apiClient.request(Endpoint(path: "/v1/reminders"))

        try await MainActor.run {
            let localReminders = try modelContext.fetch(FetchDescriptor<Reminder>())
            let localTags = try modelContext.fetch(FetchDescriptor<Tag>())

            let localMap = Dictionary(uniqueKeysWithValues: localReminders.compactMap { reminder -> (String, Reminder)? in
                guard let id = reminder.remoteID else { return nil }
                return (id, reminder)
            })
            let tagByRemoteID = Dictionary(uniqueKeysWithValues: localTags.compactMap { tag -> (String, Tag)? in
                guard let id = tag.remoteID else { return nil }
                return (id, tag)
            })

            for remote in remoteReminders {
                if let local = localMap[remote.id] {
                    if remote.updatedAt > (local.updatedAt ?? Date.distantPast) {
                        local.title = remote.title
                        local.notes = remote.notes
                        local.scheduledDate = remote.scheduledDate
                        local.isCompleted = remote.isCompleted
                        local.recurrenceRuleData = encodeRecurrenceRule(remote.recurrenceRule)
                        local.updatedAt = remote.updatedAt
                        local.tags = remote.tagIDs.compactMap { tagByRemoteID[$0] }
                    }
                } else {
                    let newReminder = Reminder(
                        title: remote.title,
                        scheduledDate: remote.scheduledDate
                    )
                    newReminder.notes = remote.notes
                    newReminder.isCompleted = remote.isCompleted
                    newReminder.recurrenceRuleData = encodeRecurrenceRule(remote.recurrenceRule)
                    newReminder.remoteID = remote.id
                    newReminder.createdAt = remote.createdAt
                    newReminder.updatedAt = remote.updatedAt
                    newReminder.tags = remote.tagIDs.compactMap { tagByRemoteID[$0] }
                    modelContext.insert(newReminder)
                }
            }

            try modelContext.save()
        }

        let localOnlyReminders = try await MainActor.run {
            let localReminders = try modelContext.fetch(FetchDescriptor<Reminder>())
            return localReminders.filter { $0.remoteID == nil }.map { reminder in
                (
                    id: reminder.id,
                    title: reminder.title,
                    notes: reminder.notes,
                    scheduledDate: reminder.scheduledDate,
                    isCompleted: reminder.isCompleted,
                    recurrenceRuleData: reminder.recurrenceRuleData,
                    tagIDs: reminder.tags.compactMap { $0.remoteID }
                )
            }
        }

        for reminderData in localOnlyReminders {
            let input = CreateReminderInput(
                title: reminderData.title,
                notes: reminderData.notes,
                scheduledDate: reminderData.scheduledDate,
                isCompleted: reminderData.isCompleted,
                recurrenceRule: decodeToRemoteRecurrenceRule(reminderData.recurrenceRuleData),
                tagIDs: reminderData.tagIDs
            )
            let created: RemoteReminder = try await apiClient.request(
                Endpoint(path: "/v1/reminders", method: .POST, body: input)
            )

            let reminderID = reminderData.id
            await MainActor.run {
                let descriptor = FetchDescriptor<Reminder>(predicate: #Predicate { $0.id == reminderID })
                if let reminder = try? modelContext.fetch(descriptor).first {
                    reminder.remoteID = created.id
                    reminder.updatedAt = created.updatedAt
                }
            }
        }

        try await MainActor.run {
            try modelContext.save()
        }
    }

    // MARK: - Individual Operations

    func pushReminder(_ reminder: Reminder, modelContext: ModelContext) async throws {
        let enabled = await MainActor.run { isSyncEnabled }
        guard enabled else { return }

        let reminderData = await MainActor.run {
            (
                remoteID: reminder.remoteID,
                id: reminder.id,
                title: reminder.title,
                notes: reminder.notes,
                scheduledDate: reminder.scheduledDate,
                isCompleted: reminder.isCompleted,
                recurrenceRuleData: reminder.recurrenceRuleData,
                tagIDs: reminder.tags.compactMap { $0.remoteID }
            )
        }

        if let remoteID = reminderData.remoteID {
            let input = UpdateReminderInput(
                title: reminderData.title,
                notes: reminderData.notes,
                scheduledDate: reminderData.scheduledDate,
                isCompleted: reminderData.isCompleted,
                recurrenceRule: decodeToRemoteRecurrenceRule(reminderData.recurrenceRuleData),
                tagIDs: reminderData.tagIDs
            )
            let updated: RemoteReminder = try await apiClient.request(
                Endpoint(path: "/v1/reminders/\(remoteID)", method: .PUT, body: input)
            )
            await MainActor.run {
                reminder.updatedAt = updated.updatedAt
            }
        } else {
            let input = CreateReminderInput(
                title: reminderData.title,
                notes: reminderData.notes,
                scheduledDate: reminderData.scheduledDate,
                isCompleted: reminderData.isCompleted,
                recurrenceRule: decodeToRemoteRecurrenceRule(reminderData.recurrenceRuleData),
                tagIDs: reminderData.tagIDs
            )
            let created: RemoteReminder = try await apiClient.request(
                Endpoint(path: "/v1/reminders", method: .POST, body: input)
            )
            await MainActor.run {
                reminder.remoteID = created.id
                reminder.updatedAt = created.updatedAt
            }
        }

        try await MainActor.run {
            try modelContext.save()
        }
    }

    func deleteReminder(_ reminderID: String) async throws {
        let enabled = await MainActor.run { isSyncEnabled }
        guard enabled else { return }
        try await apiClient.requestVoid(Endpoint(path: "/v1/reminders/\(reminderID)", method: .DELETE))
    }

    func pushTag(_ tag: Tag, modelContext: ModelContext) async throws {
        let enabled = await MainActor.run { isSyncEnabled }
        guard enabled else { return }

        let tagData = await MainActor.run {
            (remoteID: tag.remoteID, name: tag.name, colorHex: tag.colorHex)
        }

        if let remoteID = tagData.remoteID {
            let input = UpdateTagInput(name: tagData.name, colorHex: tagData.colorHex)
            let updated: RemoteTag = try await apiClient.request(
                Endpoint(path: "/v1/tags/\(remoteID)", method: .PUT, body: input)
            )
            await MainActor.run {
                tag.updatedAt = updated.updatedAt
            }
        } else {
            let input = CreateTagInput(name: tagData.name, colorHex: tagData.colorHex)
            let created: RemoteTag = try await apiClient.request(
                Endpoint(path: "/v1/tags", method: .POST, body: input)
            )
            await MainActor.run {
                tag.remoteID = created.id
                tag.updatedAt = created.updatedAt
            }
        }

        try await MainActor.run {
            try modelContext.save()
        }
    }

    func deleteTag(_ tagID: String) async throws {
        let enabled = await MainActor.run { isSyncEnabled }
        guard enabled else { return }
        try await apiClient.requestVoid(Endpoint(path: "/v1/tags/\(tagID)", method: .DELETE))
    }

    // MARK: - RecurrenceRule Conversion

    private func encodeRecurrenceRule(_ remote: RemoteRecurrenceRule?) -> Data? {
        guard let remote = remote else { return nil }

        let rule: RecurrenceRule
        switch remote.type {
        case "daily":
            rule = .daily
        case "weekly":
            rule = .weekly(weekday: remote.weekday ?? 2)
        case "monthly":
            rule = .monthly(day: remote.day ?? 1)
        case "hourly":
            rule = .hourly
        default:
            rule = .none
        }

        var container = RecurrenceContainer(rule: rule)
        container.endDate = remote.endDate
        return try? JSONEncoder().encode(container)
    }

    private func decodeToRemoteRecurrenceRule(_ data: Data?) -> RemoteRecurrenceRule? {
        guard let data = data,
              let container = try? JSONDecoder().decode(RecurrenceContainer.self, from: data) else {
            return nil
        }

        switch container.rule {
        case .none:
            return nil
        case .daily:
            return RemoteRecurrenceRule(type: "daily", weekday: nil, day: nil, endDate: container.endDate)
        case .weekly(let weekday):
            return RemoteRecurrenceRule(type: "weekly", weekday: weekday, day: nil, endDate: container.endDate)
        case .monthly(let day):
            return RemoteRecurrenceRule(type: "monthly", weekday: nil, day: day, endDate: container.endDate)
        case .hourly:
            return RemoteRecurrenceRule(type: "hourly", weekday: nil, day: nil, endDate: container.endDate)
        }
    }
}

// MARK: - RecurrenceContainer

private nonisolated struct RecurrenceContainer: Codable, Sendable {
    let rule: RecurrenceRule
    var endDate: Date?
}
