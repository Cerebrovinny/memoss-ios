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
    var scheduledDate: Date
    var isCompleted: Bool

    @Relationship(deleteRule: .nullify)
    var tags: [Tag] = []

    init(title: String, scheduledDate: Date = .now, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.scheduledDate = scheduledDate
        self.isCompleted = isCompleted
    }
}
