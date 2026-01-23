//
//  DashboardView.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 22/01/2026.
//

import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.scheduledDate) private var reminders: [Reminder]
    @AppStorage("userName") private var userName = ""
    @State private var showingCreateReminder = false
    @State private var selectedReminder: Reminder?

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    private var displayName: String {
        userName.isEmpty ? "there" : userName
    }

    private var incompleteReminders: [Reminder] {
        reminders.filter { !$0.isCompleted }
    }

    private var completedReminders: [Reminder] {
        reminders.filter { $0.isCompleted }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [MemossColors.backgroundStart, MemossColors.backgroundEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    GreetingHeader(
                        greeting: greeting,
                        userName: displayName
                    )

                    if reminders.isEmpty {
                        EmptyStateView()
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 400)
                    } else {
                        if !incompleteReminders.isEmpty {
                            TaskSection(
                                title: "To Do",
                                icon: "leaf.fill",
                                iconColor: MemossColors.brandPrimary,
                                reminders: incompleteReminders,
                                onToggle: toggleCompletion,
                                onSelect: { selectedReminder = $0 }
                            )
                        }

                        if !completedReminders.isEmpty {
                            TaskSection(
                                title: "Completed",
                                icon: "checkmark.circle.fill",
                                iconColor: MemossColors.textSecondary,
                                reminders: completedReminders,
                                onToggle: toggleCompletion,
                                onSelect: { selectedReminder = $0 }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }

            FloatingActionButton {
                showingCreateReminder = true
            }
            .padding(24)
        }
        .sheet(isPresented: $showingCreateReminder) {
            CreateReminderView()
        }
        .sheet(item: $selectedReminder) { reminder in
            EditReminderView(reminder: reminder)
        }
    }

    private func toggleCompletion(_ reminder: Reminder) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            reminder.isCompleted.toggle()
        }

        if reminder.isCompleted {
            NotificationService.shared.cancelNotification(for: reminder)
            NotificationService.shared.cancelDeliveredNotification(for: reminder)
        } else {
            Task {
                await NotificationService.shared.scheduleNotification(for: reminder)
            }
        }
    }
}

// MARK: - Task Section

private struct TaskSection: View {
    let title: String
    let icon: String
    let iconColor: Color
    let reminders: [Reminder]
    let onToggle: (Reminder) -> Void
    let onSelect: (Reminder) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(MemossColors.textPrimary)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
            }
            .accessibilityAddTraits(.isHeader)

            ForEach(reminders, id: \.id) { reminder in
                ReminderCard(
                    reminder: reminder,
                    onToggle: { onToggle(reminder) },
                    onTap: { onSelect(reminder) }
                )
            }
        }
    }
}

#Preview("Empty State") {
    DashboardView()
        .modelContainer(for: Reminder.self, inMemory: true)
}

#Preview("With Reminders") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Reminder.self, configurations: config)

    let calendar = Calendar.current
    let sampleReminders = [
        Reminder(
            title: "Water the plants",
            scheduledDate: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
        ),
        Reminder(
            title: "Call mom for her birthday",
            scheduledDate: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: .now) ?? .now
        ),
        Reminder(
            title: "Pick up groceries",
            scheduledDate: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: .now) ?? .now,
            isCompleted: true
        ),
        Reminder(
            title: "Take Buddy to the vet",
            scheduledDate: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: .now) ?? .now
        )
    ]

    for reminder in sampleReminders {
        container.mainContext.insert(reminder)
    }

    return DashboardView()
        .modelContainer(container)
}
