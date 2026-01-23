//
//  RecurrenceRule.swift
//  Memoss
//
//  Created by Claude on 23/01/2026.
//

import Foundation

enum RecurrenceRule: Codable, Equatable, Hashable {
    case none
    case daily
    case weekly(weekday: Int)  // 1=Sunday, 2=Monday, etc.
    case monthly(day: Int)     // 1-31

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .none:
            return "Never"
        case .daily:
            return "Daily"
        case .weekly(let weekday):
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            let weekdayName = formatter.weekdaySymbols[weekday - 1]
            return "Every \(weekdayName)"
        case .monthly(let day):
            let suffix = daySuffix(for: day)
            return "Monthly on the \(day)\(suffix)"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .none: return "Once"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }

    var icon: String {
        switch self {
        case .none: return "arrow.forward"
        case .daily: return "sunrise.fill"
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        }
    }

    // MARK: - Occurrence Calculation

    /// Calculate the next occurrence after the given date
    func nextOccurrence(after date: Date) -> Date? {
        let calendar = Calendar.current

        switch self {
        case .none:
            return nil

        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)

        case .weekly(let weekday):
            // Find next occurrence of this weekday
            var nextDate = calendar.date(byAdding: .day, value: 1, to: date)!
            while calendar.component(.weekday, from: nextDate) != weekday {
                nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate)!
            }
            // Preserve the time from original date
            let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
            if let result = calendar.date(
                bySettingHour: timeComponents.hour ?? 9,
                minute: timeComponents.minute ?? 0,
                second: 0,
                of: nextDate
            ) {
                return result
            }
            // DST fallback: build date from components directly
            var fallbackComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
            fallbackComponents.hour = timeComponents.hour ?? 9
            fallbackComponents.minute = timeComponents.minute ?? 0
            return calendar.date(from: fallbackComponents) ?? nextDate

        case .monthly(let day):
            var components = calendar.dateComponents([.year, .month, .hour, .minute], from: date)

            // Helper to get days in a specific year/month
            func daysInMonth(year: Int, month: Int) -> Int {
                let targetComponents = DateComponents(year: year, month: month, day: 1)
                guard let targetDate = calendar.date(from: targetComponents) else { return 28 }
                return calendar.range(of: .day, in: .month, for: targetDate)?.count ?? 28
            }

            // Try same month first - use TARGET month's day count
            let sameMonthDays = daysInMonth(year: components.year ?? 2026, month: components.month ?? 1)
            components.day = min(day, sameMonthDays)

            if let sameMonth = calendar.date(from: components), sameMonth > date {
                return sameMonth
            }

            // Move to next month
            components.month = (components.month ?? 1) + 1
            if components.month! > 12 {
                components.month = 1
                components.year = (components.year ?? 2026) + 1
            }
            // Use NEXT month's day count, not current month
            let nextMonthDays = daysInMonth(year: components.year!, month: components.month!)
            components.day = min(day, nextMonthDays)
            return calendar.date(from: components)
        }
    }

    /// Generate next N occurrences from a start date
    func occurrences(startingFrom date: Date, count: Int) -> [Date] {
        guard self != .none else {
            return date > Date() ? [date] : []
        }

        var dates: [Date] = []
        var current = date

        // Include the start date if it's in the future
        if current > Date() {
            dates.append(current)
        }

        while dates.count < count {
            guard let next = nextOccurrence(after: current) else { break }
            current = next
            dates.append(current)
        }

        return dates
    }

    // MARK: - Helpers

    private func daySuffix(for day: Int) -> String {
        switch day {
        case 1, 21, 31: return "st"
        case 2, 22: return "nd"
        case 3, 23: return "rd"
        default: return "th"
        }
    }
}

// MARK: - Preset Helpers

extension RecurrenceRule {
    /// Common recurrence presets for the picker
    static var presets: [RecurrenceRule] {
        [.none, .daily]
    }

    /// Create a weekly rule for the current weekday
    static func weeklyOnCurrentDay(from date: Date = .now) -> RecurrenceRule {
        let weekday = Calendar.current.component(.weekday, from: date)
        return .weekly(weekday: weekday)
    }

    /// Create a monthly rule for the current day of month
    static func monthlyOnCurrentDay(from date: Date = .now) -> RecurrenceRule {
        let day = Calendar.current.component(.day, from: date)
        return .monthly(day: day)
    }
}
