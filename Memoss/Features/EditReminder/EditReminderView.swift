//
//  EditReminderView.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 22/01/2026.
//

import SwiftData
import SwiftUI

struct EditReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let reminder: Reminder

    @State private var title: String
    @State private var scheduledDate: Date
    @State private var hasAttemptedSave = false
    @State private var showingDeleteConfirmation = false
    @State private var selectedTags: [Tag]
    @State private var recurrenceRule: RecurrenceRule
    @State private var recurrenceEndDate: Date?
    @FocusState private var isTitleFocused: Bool

    init(reminder: Reminder) {
        self.reminder = reminder
        _title = State(initialValue: reminder.title)
        _scheduledDate = State(initialValue: reminder.scheduledDate)
        _selectedTags = State(initialValue: reminder.tags)
        _recurrenceRule = State(initialValue: reminder.recurrenceRule)
        _recurrenceEndDate = State(initialValue: reminder.recurrenceEndDate)
    }

    private var isTitleValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var showTitleError: Bool {
        hasAttemptedSave && !isTitleValid
    }

    private var hasUnsavedChanges: Bool {
        title != reminder.title ||
        scheduledDate != reminder.scheduledDate ||
        Set(selectedTags.map(\.id)) != Set(reminder.tags.map(\.id)) ||
        recurrenceRule != reminder.recurrenceRule ||
        recurrenceEndDate != reminder.recurrenceEndDate
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    titleInputSection

                    datePickerCard

                    timePickerCard

                    TagPickerView(selectedTags: $selectedTags)

                    RecurrencePickerView(
                        recurrenceRule: $recurrenceRule,
                        endDate: $recurrenceEndDate,
                        scheduledDate: scheduledDate
                    )

                    Spacer(minLength: 20)

                    deleteButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .background(
                LinearGradient(
                    colors: [MemossColors.backgroundStart, MemossColors.backgroundEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(MemossColors.textSecondary)
                    }
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Dismiss without saving")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(isTitleValid ? MemossColors.brandPrimary : MemossColors.textSecondary)
                    .disabled(!isTitleValid)
                    .accessibilityLabel(isTitleValid ? "Save changes" : "Save button disabled, enter a title first")
                }
            }
            .confirmationDialog(
                "Delete Reminder?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteReminder()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This cannot be undone.")
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
    }

    // MARK: - Subviews

    private var titleInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What do you need to remember?")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(MemossColors.textSecondary)

            TextField("Reminder title", text: $title)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(MemossColors.textPrimary)
                .focused($isTitleFocused)
                .submitLabel(.done)
                .padding(20)
                .background(MemossColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(showTitleError ? MemossColors.error : Color.clear, lineWidth: 2)
                )
                .shadow(color: MemossColors.brandPrimary.opacity(0.08), radius: 12, y: 4)
                .accessibilityLabel("Reminder title")
                .accessibilityValue(title.isEmpty ? "Empty" : title)
                .accessibilityHint("Enter what you need to remember")

            if showTitleError {
                Text("Please enter a reminder title")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(MemossColors.error)
            }
        }
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: showTitleError)
    }

    private var datePickerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(MemossColors.brandPrimary.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "calendar")
                    .font(.system(size: 20))
                    .foregroundStyle(MemossColors.brandPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Date")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(MemossColors.textSecondary)

                DatePicker("", selection: $scheduledDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(MemossColors.brandPrimary)
                    .accessibilityLabel("Select date")
            }

            Spacer()
        }
        .padding(20)
        .background(MemossColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: MemossColors.brandPrimary.opacity(0.08), radius: 12, y: 4)
    }

    private var timePickerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(MemossColors.accent.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "clock")
                    .font(.system(size: 20))
                    .foregroundStyle(MemossColors.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Time")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(MemossColors.textSecondary)

                DatePicker("", selection: $scheduledDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(MemossColors.brandPrimary)
                    .accessibilityLabel("Select time")
            }

            Spacer()
        }
        .padding(20)
        .background(MemossColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: MemossColors.brandPrimary.opacity(0.08), radius: 12, y: 4)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Reminder")
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(MemossColors.error)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .accessibilityLabel("Delete this reminder")
        .accessibilityHint("Double tap to show delete confirmation")
    }

    // MARK: - Actions

    private func saveChanges() {
        hasAttemptedSave = true
        guard isTitleValid else { return }

        reminder.title = title.trimmingCharacters(in: .whitespaces)
        reminder.scheduledDate = scheduledDate
        reminder.tags = selectedTags
        reminder.recurrenceRule = recurrenceRule
        reminder.recurrenceEndDate = recurrenceEndDate
        reminder.updatedAt = Date()

        // Reschedule notifications for incomplete reminders
        if !reminder.isCompleted {
            NotificationService.shared.cancelAllNotifications(for: reminder)
            Task {
                await NotificationService.shared.scheduleNotifications(for: reminder)
            }
        }

        Task.detached(priority: .utility) { [reminder, modelContext] in
            try? await SyncService.shared.pushReminder(reminder, modelContext: modelContext)
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss()
    }

    private func deleteReminder() {
        NotificationService.shared.cancelAllNotifications(for: reminder)
        NotificationService.shared.cancelDeliveredNotification(for: reminder)

        if let remoteID = reminder.remoteID {
            Task.detached(priority: .utility) {
                try? await SyncService.shared.deleteReminder(remoteID)
            }
        }

        modelContext.delete(reminder)

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

#Preview {
    EditReminderView(
        reminder: Reminder(title: "Water the plants", scheduledDate: Date())
    )
    .modelContainer(for: [Reminder.self, Tag.self], inMemory: true)
}
