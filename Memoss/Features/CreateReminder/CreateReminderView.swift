//
//  CreateReminderView.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 22/01/2026.
//

import SwiftData
import SwiftUI

struct CreateReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var title = ""
    @State private var scheduledDate = Date()
    @State private var hasAttemptedSave = false
    @State private var selectedTags: [Tag] = []
    @FocusState private var isTitleFocused: Bool

    private var isTitleValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var showTitleError: Bool {
        hasAttemptedSave && !isTitleValid
    }

    init() {
        _scheduledDate = State(initialValue: Self.roundedTime())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    titleInputSection

                    datePickerCard

                    timePickerCard

                    TagPickerView(selectedTags: $selectedTags)
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
            .navigationTitle("New Reminder")
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
                        saveReminder()
                    }
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(isTitleValid ? MemossColors.brandPrimary : MemossColors.textSecondary)
                    .disabled(!isTitleValid)
                    .accessibilityLabel(isTitleValid ? "Save reminder" : "Save button disabled, enter a title first")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isTitleFocused = false
                    }
                }
            }
            .interactiveDismissDisabled(isTitleValid)
        }
        .onAppear {
            isTitleFocused = true
        }
    }

    // MARK: - Subviews

    private var titleInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What do you need to remember?")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(MemossColors.textSecondary)

            TextField("e.g., Water the plants, call mom", text: $title)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(MemossColors.textPrimary)
                .focused($isTitleFocused)
                .padding(20)
                .background(MemossColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(showTitleError ? MemossColors.error : Color.clear, lineWidth: 2)
                )
                .shadow(color: MemossColors.brandPrimary.opacity(0.08), radius: 12, y: 4)
                .accessibilityLabel("Reminder title")
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

    // MARK: - Actions

    private func saveReminder() {
        hasAttemptedSave = true
        guard isTitleValid else { return }

        let reminder = Reminder(
            title: title.trimmingCharacters(in: .whitespaces),
            scheduledDate: scheduledDate
        )
        reminder.tags = selectedTags

        modelContext.insert(reminder)

        Task { @MainActor in
            await NotificationService.shared.scheduleNotification(for: reminder)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dismiss()
        }
    }

    // MARK: - Helpers

    private static func roundedTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let minutes = calendar.component(.minute, from: now)
        let remainder = minutes % 15
        let roundUp = remainder == 0 ? 0 : (15 - remainder)
        return calendar.date(byAdding: .minute, value: roundUp, to: now) ?? now
    }
}

#Preview {
    CreateReminderView()
        .modelContainer(for: [Reminder.self, Tag.self], inMemory: true)
}
