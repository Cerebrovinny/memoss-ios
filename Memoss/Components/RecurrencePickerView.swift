//
//  RecurrencePickerView.swift
//  Memoss
//
//  Created by Claude on 23/01/2026.
//

import SwiftUI

struct RecurrencePickerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var recurrenceRule: RecurrenceRule
    @Binding var endDate: Date?
    let scheduledDate: Date

    @State private var hasEndDate = false

    private var animationValue: Animation? {
        reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8)
    }

    private var weekday: Int {
        Calendar.current.component(.weekday, from: scheduledDate)
    }

    private var dayOfMonth: Int {
        Calendar.current.component(.day, from: scheduledDate)
    }

    private var weekdayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        guard let symbols = formatter.weekdaySymbols else {
            return "Sunday"
        }
        let index = weekday - 1
        guard index >= 0, index < symbols.count else {
            return symbols.first ?? "Sunday"
        }
        return symbols[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Text("Repeat")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(MemossColors.textSecondary)

            // Recurrence options
            VStack(spacing: 0) {
                recurrenceOption(.none, label: "Never", icon: "arrow.forward")
                Divider().padding(.leading, 52)
                recurrenceOption(.daily, label: "Daily", icon: "sunrise.fill")
                Divider().padding(.leading, 52)
                recurrenceOption(.weekly(weekday: weekday), label: "Weekly on \(weekdayName)", icon: "calendar.badge.clock")
                Divider().padding(.leading, 52)
                recurrenceOption(.monthly(day: dayOfMonth), label: "Monthly on the \(dayOfMonth)\(daySuffix(dayOfMonth))", icon: "calendar")
            }
            .background(MemossColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: MemossColors.brandPrimary.opacity(0.08), radius: 12, y: 4)

            // End date toggle (only show if recurring)
            if recurrenceRule != .none {
                endDateSection
            }
        }
        .onAppear {
            hasEndDate = endDate != nil
        }
    }

    // MARK: - Subviews

    private func recurrenceOption(_ rule: RecurrenceRule, label: String, icon: String) -> some View {
        let isSelected = recurrenceRule.shortDisplayName == rule.shortDisplayName

        return Button {
            withAnimation(animationValue) {
                recurrenceRule = rule
                if rule == .none {
                    hasEndDate = false
                    endDate = nil
                }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? MemossColors.brandPrimary.opacity(0.15) : MemossColors.backgroundStart)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? MemossColors.brandPrimary : MemossColors.textSecondary)
                }

                Text(label)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? MemossColors.textPrimary : MemossColors.textSecondary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MemossColors.brandPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var endDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $hasEndDate) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(MemossColors.accent.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: "flag.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(MemossColors.accent)
                    }

                    Text("End Date")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(MemossColors.textPrimary)
                }
            }
            .tint(MemossColors.brandPrimary)
            .padding(16)
            .background(MemossColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: MemossColors.brandPrimary.opacity(0.08), radius: 12, y: 4)
            .onChange(of: hasEndDate) { _, newValue in
                withAnimation(animationValue) {
                    if newValue {
                        // Default to 1 month from scheduled date
                        endDate = Calendar.current.date(byAdding: .month, value: 1, to: scheduledDate)
                    } else {
                        endDate = nil
                    }
                }
            }

            if hasEndDate {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(MemossColors.accent.opacity(0.1))
                            .frame(width: 44, height: 44)
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 20))
                            .foregroundStyle(MemossColors.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ends On")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(MemossColors.textSecondary)

                        DatePicker(
                            "",
                            selection: Binding(
                                get: { endDate ?? Calendar.current.date(byAdding: .month, value: 1, to: scheduledDate)! },
                                set: { endDate = $0 }
                            ),
                            in: scheduledDate...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(MemossColors.brandPrimary)
                    }

                    Spacer()
                }
                .padding(20)
                .background(MemossColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: MemossColors.brandPrimary.opacity(0.08), radius: 12, y: 4)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .animation(animationValue, value: hasEndDate)
    }

    // MARK: - Helpers

    private func daySuffix(_ day: Int) -> String {
        switch day {
        case 1, 21, 31: return "st"
        case 2, 22: return "nd"
        case 3, 23: return "rd"
        default: return "th"
        }
    }
}

#Preview("No Recurrence") {
    RecurrencePickerView(
        recurrenceRule: .constant(.none),
        endDate: .constant(nil),
        scheduledDate: .now
    )
    .padding()
    .background(MemossColors.backgroundStart)
}

#Preview("Daily Selected") {
    RecurrencePickerView(
        recurrenceRule: .constant(.daily),
        endDate: .constant(nil),
        scheduledDate: .now
    )
    .padding()
    .background(MemossColors.backgroundStart)
}

#Preview("Weekly with End Date") {
    RecurrencePickerView(
        recurrenceRule: .constant(.weekly(weekday: 2)),
        endDate: .constant(Calendar.current.date(byAdding: .month, value: 1, to: .now)),
        scheduledDate: .now
    )
    .padding()
    .background(MemossColors.backgroundStart)
}
