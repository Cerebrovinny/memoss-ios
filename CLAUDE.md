# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is an iOS app using Xcode. Open `Memoss.xcodeproj` in Xcode to build and run.

```bash
# Open in Xcode
open Memoss.xcodeproj

# Build from command line
xcodebuild -project Memoss.xcodeproj -scheme Memoss -sdk iphonesimulator build

# Run tests (when available)
xcodebuild -project Memoss.xcodeproj -scheme Memoss -sdk iphonesimulator test
```

## Architecture

**Memoss** is a reminder app for iOS 26+ using SwiftUI and SwiftData.

### App Entry & Navigation

The app uses `@AppStorage("hasCompletedOnboarding")` to control the root view:
- **First launch**: Shows `OnboardingView` (feature walkthrough + notification permission request)
- **Subsequent launches**: Shows `DashboardView` (main reminder list)

On first launch, default tags are seeded via `seedDefaultTags()` in `MemossApp.swift:41-58`.

### Data Layer

**SwiftData** is used for persistence. The `ModelContainer` is configured at the app level for `Reminder.self` and `Tag.self`.

**Models** (`Models/`):
- `Reminder` - Core data model with `id`, `title`, `scheduledDate`, `isCompleted`, `tags` relationship, and recurrence support via `recurrenceRuleData` (stored as `Codable` Data)
- `Tag` - Categorization model with `id`, `name`, `colorHex`, inverse relationship to reminders
- `RecurrenceRule` - Enum (`none`, `daily`, `weekly(weekday:)`, `monthly(day:)`) with occurrence calculation logic

Views access data via `@Query` macro and `@Environment(\.modelContext)`.

### Services

**NotificationService** (`Services/NotificationService.swift`):
- Singleton service for scheduling/canceling local notifications
- Handles both one-time and recurring reminders (schedules up to 50 future occurrences)
- Supports snooze and notification categories with actions (Mark Complete, Snooze)
- Integrates with `AppDelegate+Notifications.swift` for handling notification responses

### Feature Structure

Features are organized in `Features/` with a flat structure:
```
Features/
  ├── Onboarding/OnboardingView.swift       # Self-contained onboarding flow
  ├── Dashboard/
  │   ├── DashboardView.swift               # Main screen with reminder list
  │   └── Components/                       # Feature-specific UI components
  │       ├── ReminderCard.swift            # Individual reminder display
  │       ├── GreetingHeader.swift          # Time-based greeting
  │       ├── EmptyStateView.swift          # Empty list placeholder
  │       └── FloatingActionButton.swift    # Add reminder FAB
  ├── CreateReminder/CreateReminderView.swift  # Modal for new reminders
  └── EditReminder/EditReminderView.swift      # Edit/delete existing reminders
```

Each feature view is largely self-contained. Smaller components live in `Components/` subdirectories.

### Shared Components

Reusable components in `Components/`:
- `TagPickerView` - Tag selection with inline creation form
- `TagChip` - Individual tag display capsule
- `RecurrencePickerView` - Recurrence frequency selector with end date option
- `FlowLayout` - Horizontal wrapping layout for tags

### Design System

Colors are centralized in `Extensions/MemossColors.swift` as static properties. Use `Color(hex:)` extension from `Color+Hex.swift` for hex values.

Key colors:
- `MemossColors.brandPrimary` / `brandPrimaryDark` / `brandPrimaryLight` - Moss green (#22C55E)
- `MemossColors.backgroundStart` / `backgroundEnd` - Gradient backgrounds
- `MemossColors.textPrimary` / `textSecondary` - Typography
- `MemossColors.cardBackground` / `cardBorder` - Card surfaces
- `MemossColors.accent` - Yellow accent (#EAB308)
- `MemossColors.success` / `warning` / `error` - Semantic colors
- `MemossColors.tagColors` - Array of 8 predefined tag colors

**Note**: `OnboardingView` has its own inline `OnboardingColors` enum. When colors are needed by 3+ features, extract to `MemossColors`.

### UI Patterns

- **Rounded design language**: 24pt corner radius on cards, capsule buttons
- **Gradient backgrounds**: Top-to-bottom `backgroundStart` to `backgroundEnd`
- **Shadow style**: `brandPrimary.opacity(0.08), radius: 12, y: 4`
- **Typography**: System rounded design (`.design(.rounded)`)
- **Haptic feedback**: `UIImpactFeedbackGenerator(style: .light)` on interactions
- **Accessibility**: `@Environment(\.accessibilityReduceMotion)` respected for animations

### Plans Directory

Feature plans live in `plans/` with naming convention `feat-{feature-name}.md`. Current plans:
- `feat-onboarding-screen.md` - Onboarding flow
- `feat-main-dashboard.md` - Dashboard and reminder list
- `feat-create-reminder.md` - Reminder creation
- `feat-edit-delete-reminder.md` - Edit/delete functionality
- `feat-local-notifications.md` - Notification scheduling
- `feat-tags-system.md` - Tag categorization
- `feat-recurring-reminders.md` - Recurrence support

## Code Conventions

- SwiftUI views use `private` for internal subviews and computed properties
- `#Preview` macros for Xcode canvas previews
- MARK comments for section organization (`// MARK: - Section Name`)
- Accessibility labels and hints on interactive elements
- Minimum 44pt touch targets for buttons
- Use `@MainActor` for services that interact with UI or SwiftData context
