//
//  TagChip.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 23/01/2026.
//

import SwiftData
import SwiftUI

struct TagChip: View {
    let tag: Tag
    var isSelected: Bool = false
    var isCompact: Bool = false
    var onTap: (() -> Void)?
    var onRemove: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: isCompact ? 4 : 6) {
                Circle()
                    .fill(tag.color)
                    .frame(width: isCompact ? 6 : 8, height: isCompact ? 6 : 8)

                Text(tag.name)
                    .font(.system(size: isCompact ? 12 : 14, weight: .medium, design: .rounded))

                if let onRemove, isSelected {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(tag.color.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, isCompact ? 8 : 12)
            .padding(.vertical, isCompact ? 4 : 6)
            .background(
                Capsule()
                    .fill(isSelected ? tag.color.opacity(0.15) : MemossColors.cardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? tag.color : MemossColors.cardBorder, lineWidth: 1.5)
            )
            .foregroundStyle(isSelected ? tag.color : MemossColors.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tag.name) tag")
        .accessibilityHint(isSelected ? "Selected. Double tap to remove" : "Double tap to select")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview("Selected") {
    TagChip(
        tag: Tag(name: "Personal", colorHex: "#22C55E"),
        isSelected: true
    )
    .modelContainer(for: Tag.self, inMemory: true)
}

#Preview("Unselected") {
    TagChip(
        tag: Tag(name: "Work", colorHex: "#3B82F6"),
        isSelected: false
    )
    .modelContainer(for: Tag.self, inMemory: true)
}

#Preview("Compact") {
    TagChip(
        tag: Tag(name: "Health", colorHex: "#EC4899"),
        isSelected: true,
        isCompact: true
    )
    .modelContainer(for: Tag.self, inMemory: true)
}
