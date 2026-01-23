//
//  MemossColors.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 22/01/2026.
//

import SwiftUI

enum MemossColors {
    // Primary (Moss Green)
    static let brandPrimary = Color(hex: "#22C55E")
    static let brandPrimaryDark = Color(hex: "#16A34A")
    static let brandPrimaryLight = Color(hex: "#F0F9F4")

    // Neutral
    static let backgroundStart = Color(hex: "#F9F7F3")
    static let backgroundEnd = Color(hex: "#F0F9F4")
    static let textPrimary = Color(hex: "#252320")
    static let textSecondary = Color(hex: "#A8A298")
    static let cardBackground = Color(hex: "#FFFFFF")
    static let cardBorder = Color(hex: "#F9F7F3")

    // Accent
    static let accent = Color(hex: "#EAB308")

    // Semantic
    static let success = Color(hex: "#22C55E")
    static let warning = Color(hex: "#EAB308")
    static let error = Color(hex: "#F43F5E")

    // Tag Colors
    static let tagColors: [Color] = [
        brandPrimary,               // Moss Green #22C55E
        Color(hex: "#3B82F6"),      // Blue
        Color(hex: "#EC4899"),      // Pink
        Color(hex: "#F97316"),      // Orange
        Color(hex: "#8B5CF6"),      // Purple
        Color(hex: "#14B8A6"),      // Teal
        accent,                     // Yellow #EAB308
        Color(hex: "#6B7280"),      // Gray
    ]
}
