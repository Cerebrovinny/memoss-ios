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

struct RemoteReminder: Codable, Identifiable {
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

struct RemoteRecurrenceRule: Codable {
    let type: String
    let weekday: Int?
    let day: Int?
    let endDate: Date?

    enum CodingKeys: String, CodingKey {
        case type, weekday, day
        case endDate = "end_date"
    }
}

struct RemoteTag: Codable, Identifiable {
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

struct CreateReminderInput: Encodable {
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

struct UpdateReminderInput: Encodable {
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

struct CreateTagInput: Encodable {
    let name: String
    let colorHex: String

    enum CodingKeys: String, CodingKey {
        case name
        case colorHex = "color_hex"
    }
}

struct UpdateTagInput: Encodable {
    let name: String?
    let colorHex: String?

    enum CodingKeys: String, CodingKey {
        case name
        case colorHex = "color_hex"
    }
}

// MARK: - Sync Service

@MainActor
final class SyncService: ObservableObject {
    static let shared = SyncService()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncError: Error?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
        self.lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
    }

    var isSyncEnabled: Bool {
        return apiClient.isAuthenticated
    }

    // MARK: - Full Sync

    func syncAll(modelContext: ModelContext) async {
        guard isSyncEnabled else { return }

        isSyncing = true
        syncError = nil

        do {
            try await syncTags(modelContext: modelContext)
            try await syncReminders(modelContext: modelContext)

            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
        } catch {
            syncError = error
        }

        isSyncing = false
    }

    // MARK: - Tag Sync

    private func syncTags(modelContext: ModelContext) async throws {
        let remoteTags: [RemoteTag] = try await apiClient.request(Endpoint(path: "/v1/tags"))

        let localTags = try modelContext.fetch(FetchDescriptor<Tag>())

        // Create map of remote tags by ID
        let remoteTagMap = Dictionary(uniqueKeysWithValues: remoteTags.map { ($0.id, $0) })
        let localTagMap = Dictionary(uniqueKeysWithValues: localTags.compactMap { tag -> (String, Tag)? in
            guard let id = tag.remoteID else { return nil }
            return (id, tag)
        })

        // Update or create local tags from remote
        for remoteTag in remoteTags {
            if let localTag = localTagMap[remoteTag.id] {
                // Update existing
                if remoteTag.updatedAt > (localTag.updatedAt ?? Date.distantPast) {
                    localTag.name = remoteTag.name
                    localTag.colorHex = remoteTag.colorHex
                    localTag.updatedAt = remoteTag.updatedAt
                }
            } else {
                // Create new local tag
                let newTag = Tag(name: remoteTag.name, colorHex: remoteTag.colorHex)
                newTag.remoteID = remoteTag.id
                newTag.createdAt = remoteTag.createdAt
                newTag.updatedAt = remoteTag.updatedAt
                modelContext.insert(newTag)
            }
        }

        // Push local-only tags to remote
        for localTag in localTags where localTag.remoteID == nil {
            let input = CreateTagInput(name: localTag.name, colorHex: localTag.colorHex)
            let created: RemoteTag = try await apiClient.request(
                Endpoint(path: "/v1/tags", method: .POST, body: input)
            )
            localTag.remoteID = created.id
            localTag.updatedAt = created.updatedAt
        }

        try modelContext.save()
    }

    // MARK: - Reminder Sync

    private func syncReminders(modelContext: ModelContext) async throws {
        let remoteReminders: [RemoteReminder] = try await apiClient.request(Endpoint(path: "/v1/reminders"))

        let localReminders = try modelContext.fetch(FetchDescriptor<Reminder>())
        let localTags = try modelContext.fetch(FetchDescriptor<Tag>())

        // Create maps
        let remoteMap = Dictionary(uniqueKeysWithValues: remoteReminders.map { ($0.id, $0) })
        let localMap = Dictionary(uniqueKeysWithValues: localReminders.compactMap { reminder -> (String, Reminder)? in
            guard let id = reminder.remoteID else { return nil }
            return (id, reminder)
        })
        let tagByRemoteID = Dictionary(uniqueKeysWithValues: localTags.compactMap { tag -> (String, Tag)? in
            guard let id = tag.remoteID else { return nil }
            return (id, tag)
        })

        // Update or create local reminders from remote
        for remote in remoteReminders {
            if let local = localMap[remote.id] {
                // Update if remote is newer
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
                // Create new local reminder
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

        // Push local-only reminders to remote
        for local in localReminders where local.remoteID == nil {
            let tagIDs = local.tags.compactMap { $0.remoteID }
            let input = CreateReminderInput(
                title: local.title,
                notes: local.notes,
                scheduledDate: local.scheduledDate,
                isCompleted: local.isCompleted,
                recurrenceRule: decodeToRemoteRecurrenceRule(local.recurrenceRuleData),
                tagIDs: tagIDs
            )
            let created: RemoteReminder = try await apiClient.request(
                Endpoint(path: "/v1/reminders", method: .POST, body: input)
            )
            local.remoteID = created.id
            local.updatedAt = created.updatedAt
        }

        try modelContext.save()
    }

    // MARK: - Individual Operations

    func pushReminder(_ reminder: Reminder, modelContext: ModelContext) async throws {
        guard isSyncEnabled else { return }

        let tagIDs = reminder.tags.compactMap { $0.remoteID }

        if let remoteID = reminder.remoteID {
            let input = UpdateReminderInput(
                title: reminder.title,
                notes: reminder.notes,
                scheduledDate: reminder.scheduledDate,
                isCompleted: reminder.isCompleted,
                recurrenceRule: decodeToRemoteRecurrenceRule(reminder.recurrenceRuleData),
                tagIDs: tagIDs
            )
            let updated: RemoteReminder = try await apiClient.request(
                Endpoint(path: "/v1/reminders/\(remoteID)", method: .PUT, body: input)
            )
            reminder.updatedAt = updated.updatedAt
        } else {
            let input = CreateReminderInput(
                title: reminder.title,
                notes: reminder.notes,
                scheduledDate: reminder.scheduledDate,
                isCompleted: reminder.isCompleted,
                recurrenceRule: decodeToRemoteRecurrenceRule(reminder.recurrenceRuleData),
                tagIDs: tagIDs
            )
            let created: RemoteReminder = try await apiClient.request(
                Endpoint(path: "/v1/reminders", method: .POST, body: input)
            )
            reminder.remoteID = created.id
            reminder.updatedAt = created.updatedAt
        }

        try modelContext.save()
    }

    func deleteReminder(_ reminderID: String) async throws {
        guard isSyncEnabled else { return }
        try await apiClient.requestVoid(Endpoint(path: "/v1/reminders/\(reminderID)", method: .DELETE))
    }

    func pushTag(_ tag: Tag, modelContext: ModelContext) async throws {
        guard isSyncEnabled else { return }

        if let remoteID = tag.remoteID {
            let input = UpdateTagInput(name: tag.name, colorHex: tag.colorHex)
            let updated: RemoteTag = try await apiClient.request(
                Endpoint(path: "/v1/tags/\(remoteID)", method: .PUT, body: input)
            )
            tag.updatedAt = updated.updatedAt
        } else {
            let input = CreateTagInput(name: tag.name, colorHex: tag.colorHex)
            let created: RemoteTag = try await apiClient.request(
                Endpoint(path: "/v1/tags", method: .POST, body: input)
            )
            tag.remoteID = created.id
            tag.updatedAt = created.updatedAt
        }

        try modelContext.save()
    }

    func deleteTag(_ tagID: String) async throws {
        guard isSyncEnabled else { return }
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

private struct RecurrenceContainer: Codable {
    let rule: RecurrenceRule
    var endDate: Date?
}
