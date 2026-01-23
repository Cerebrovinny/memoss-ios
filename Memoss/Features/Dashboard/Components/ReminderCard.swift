//
//  ReminderCard.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 22/01/2026.
//

import SwiftUI

struct ReminderCard: View {
    let reminder: Reminder
    let onToggle: () -> Void
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onToggle()
            } label: {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(reminder.isCompleted ? MemossColors.brandPrimary : MemossColors.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(reminder.isCompleted ? "Mark incomplete" : "Mark complete")
            .frame(minWidth: 44, minHeight: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .strikethrough(reminder.isCompleted, color: MemossColors.textSecondary)
                    .foregroundStyle(reminder.isCompleted ? MemossColors.textSecondary : MemossColors.textPrimary)
                    .lineLimit(2)

                Label {
                    Text(reminder.scheduledDate, format: .dateTime.hour().minute())
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.system(size: 14))
                .foregroundStyle(MemossColors.textSecondary)

                // Tags display
                if !reminder.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(reminder.tags.prefix(3), id: \.id) { tag in
                            TagChip(tag: tag, isCompact: true)
                                .opacity(reminder.isCompleted ? 0.6 : 1.0)
                        }

                        if reminder.tags.count > 3 {
                            Text("+\(reminder.tags.count - 3)")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(MemossColors.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(MemossColors.backgroundStart)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onTap?()
            }

            Spacer()
        }
        .padding(20)
        .background(MemossColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: MemossColors.brandPrimary.opacity(0.08), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(reminder.title), scheduled for \(reminder.scheduledDate.formatted(date: .omitted, time: .shortened))"
        )
        .accessibilityHint(reminder.isCompleted ? "Double tap to mark as incomplete" : "Double tap to mark as complete")
        .accessibilityAddTraits(reminder.isCompleted ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("Incomplete") {
    ReminderCard(
        reminder: Reminder(title: "Water the plants", scheduledDate: Date()),
        onToggle: {}
    )
    .padding()
    .background(MemossColors.backgroundStart)
}

#Preview("Completed") {
    ReminderCard(
        reminder: Reminder(title: "Call mom", scheduledDate: Date(), isCompleted: true),
        onToggle: {}
    )
    .padding()
    .background(MemossColors.backgroundStart)
}
