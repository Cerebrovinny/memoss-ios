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
    @State private var showingSettings = false

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

    // MARK: - Date-Grouped Reminders

    private var overdueReminders: [Reminder] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return incompleteReminders.filter { $0.nextAlertDate < startOfToday }
    }

    private var todayReminders: [Reminder] {
        incompleteReminders.filter { Calendar.current.isDateInToday($0.nextAlertDate) }
    }

    private var tomorrowReminders: [Reminder] {
        incompleteReminders.filter { Calendar.current.isDateInTomorrow($0.nextAlertDate) }
    }

    private var thisWeekReminders: [Reminder] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let twoDaysFromNow = calendar.date(byAdding: .day, value: 2, to: startOfToday),
              let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday) else {
            return []
        }
        return incompleteReminders.filter {
            $0.nextAlertDate >= twoDaysFromNow && $0.nextAlertDate < endOfWeek
        }
    }

    private var laterReminders: [Reminder] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday) else {
            return []
        }
        return incompleteReminders.filter { $0.nextAlertDate >= endOfWeek }
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
                    HStack {
                        GreetingHeader(
                            greeting: greeting,
                            userName: displayName
                        )
                        Spacer()
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundStyle(MemossColors.textSecondary)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Settings")
                    }

                    if reminders.isEmpty {
                        EmptyStateView()
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 400)
                    } else {
                        // Overdue - Warning styling
                        if !overdueReminders.isEmpty {
                            DateGroupSection(
                                title: "Overdue",
                                icon: "exclamationmark.circle.fill",
                                iconColor: MemossColors.error,
                                accentColor: MemossColors.error,
                                count: overdueReminders.count,
                                reminders: overdueReminders,
                                onToggle: toggleCompletion,
                                onSelect: { selectedReminder = $0 }
                            )
                        }

                        // Today - Primary styling
                        if !todayReminders.isEmpty {
                            DateGroupSection(
                                title: "Today",
                                icon: "sun.max.fill",
                                iconColor: MemossColors.accent,
                                accentColor: MemossColors.brandPrimary,
                                count: todayReminders.count,
                                reminders: todayReminders,
                                onToggle: toggleCompletion,
                                onSelect: { selectedReminder = $0 }
                            )
                        }

                        // Tomorrow
                        if !tomorrowReminders.isEmpty {
                            DateGroupSection(
                                title: "Tomorrow",
                                icon: "sunrise.fill",
                                iconColor: MemossColors.brandPrimary,
                                accentColor: MemossColors.brandPrimary,
                                count: tomorrowReminders.count,
                                reminders: tomorrowReminders,
                                onToggle: toggleCompletion,
                                onSelect: { selectedReminder = $0 }
                            )
                        }

                        // This Week
                        if !thisWeekReminders.isEmpty {
                            DateGroupSection(
                                title: "This Week",
                                icon: "calendar",
                                iconColor: MemossColors.textSecondary,
                                accentColor: MemossColors.textSecondary,
                                count: thisWeekReminders.count,
                                reminders: thisWeekReminders,
                                onToggle: toggleCompletion,
                                onSelect: { selectedReminder = $0 }
                            )
                        }

                        // Later
                        if !laterReminders.isEmpty {
                            DateGroupSection(
                                title: "Later",
                                icon: "clock",
                                iconColor: MemossColors.textSecondary,
                                accentColor: MemossColors.textSecondary,
                                count: laterReminders.count,
                                reminders: laterReminders,
                                onToggle: toggleCompletion,
                                onSelect: { selectedReminder = $0 }
                            )
                        }

                        // Completed - Collapsible
                        if !completedReminders.isEmpty {
                            CompletedSection(
                                count: completedReminders.count,
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .task {
            Task.detached(priority: .utility) { [modelContext] in
                await APIClient.shared.restoreAuthState()
                await SyncService.shared.syncAll(modelContext: modelContext)
            }
        }
    }

    private func toggleCompletion(_ reminder: Reminder) {
        if reminder.isRecurring && !reminder.isCompleted {
            // Recurring reminder: advance to next occurrence
            handleRecurringCompletion(reminder)
        } else {
            // Non-recurring or uncompleting: standard toggle
            handleStandardToggle(reminder)
        }
    }

    private func handleRecurringCompletion(_ reminder: Reminder) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            reminder.advanceToNextOccurrence()
        }

        NotificationService.shared.cancelAllNotifications(for: reminder)
        if !reminder.isCompleted {
            Task {
                await NotificationService.shared.scheduleNotifications(for: reminder)
            }
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func handleStandardToggle(_ reminder: Reminder) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            reminder.isCompleted.toggle()
        }

        if reminder.isCompleted {
            NotificationService.shared.cancelAllNotifications(for: reminder)
            NotificationService.shared.cancelDeliveredNotification(for: reminder)
        } else {
            Task {
                await NotificationService.shared.scheduleNotifications(for: reminder)
            }
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Date Group Section

private struct DateGroupSection: View {
    let title: String
    let icon: String
    let iconColor: Color
    let accentColor: Color
    let count: Int
    let reminders: [Reminder]
    let onToggle: (Reminder) -> Void
    let onSelect: (Reminder) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(MemossColors.textPrimary)

                // Count badge
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(accentColor.opacity(0.15))
                    )

                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title), \(count) reminders")
            .accessibilityAddTraits(.isHeader)

            ForEach(reminders, id: \.id) { reminder in
                ReminderCard(
                    reminder: reminder,
                    onToggle: { onToggle(reminder) },
                    onTap: { onSelect(reminder) }
                )
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Completed Section (Collapsible)

private struct CompletedSection: View {
    let count: Int
    let reminders: [Reminder]
    let onToggle: (Reminder) -> Void
    let onSelect: (Reminder) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MemossColors.textSecondary)

                    Text("Completed")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(MemossColors.textSecondary)

                    Text("\(count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(MemossColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(MemossColors.textSecondary.opacity(0.15))
                        )

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MemossColors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Completed, \(count) reminders, \(isExpanded ? "expanded" : "collapsed")")
            .accessibilityHint("Double tap to \(isExpanded ? "collapse" : "expand")")
            .accessibilityAddTraits(.isHeader)

            if isExpanded {
                ForEach(reminders, id: \.id) { reminder in
                    ReminderCard(
                        reminder: reminder,
                        onToggle: { onToggle(reminder) },
                        onTap: { onSelect(reminder) }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                }
            }
        }
        .padding(.top, 16)
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
