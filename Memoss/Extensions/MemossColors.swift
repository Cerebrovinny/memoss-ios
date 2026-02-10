//
//  MemossColors.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 22/01/2026.
//

import SwiftUI

enum MemossColors {
    // Primary (Moss Green)
    static let brandPrimary = Color("BrandPrimary")
    static let brandPrimaryDark = Color("BrandPrimaryDark")
    static let brandPrimaryLight = Color("BrandPrimaryLight")

    // Neutral
    static let backgroundStart = Color("BackgroundStart")
    static let backgroundEnd = Color("BackgroundEnd")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let cardBackground = Color("CardBackground")
    static let cardBorder = Color("CardBorder")

    // Accent
    static let accent = Color("Accent")

    // Semantic
    static let success = Color("Success")
    static let warning = Color("Warning")
    static let error = Color("Error")

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
