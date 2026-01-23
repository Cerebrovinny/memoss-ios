//
//  Tag.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 23/01/2026.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date

    @Relationship(inverse: \Reminder.tags)
    var reminders: [Reminder] = []

    var color: Color {
        Color(hex: colorHex)
    }

    init(name: String, colorHex: String) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
    }
}
