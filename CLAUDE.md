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

There are currently no test targets. Build configuration uses `$(GOOGLE_CLIENT_ID)` and `$(GOOGLE_REVERSED_CLIENT_ID)` from Xcode build settings (referenced in `Info.plist`).

## Architecture

**Memoss** is a reminder app for iOS 26+ using SwiftUI and SwiftData, with optional cross-device sync via a Go backend.

### App Entry & Navigation

The app uses `@AppStorage("hasCompletedOnboarding")` to control the root view:
- **First launch**: Shows `OnboardingView` (feature walkthrough + notification permission request)
- **Subsequent launches**: Shows `DashboardView` (main reminder list)

On first launch, default tags are seeded via `seedDefaultTags()` in `MemossApp.swift`. `AppDelegate` eagerly initializes singleton services (`APIClient`, `AuthService`, `SyncService`) at launch and registers notification categories.

### Data Layer

**SwiftData** is used for persistence. The `ModelContainer` is configured as a static shared instance on `MemossApp` for `Reminder.self` and `Tag.self`. Views access data via `@Query` macro and `@Environment(\.modelContext)`.

**Models** (`Models/`):
- `Reminder` - Core model with `id`, `title`, `scheduledDate`, `isCompleted`, `tags` relationship, recurrence via `recurrenceRuleData` (stored as `Codable` Data), and sync fields (`remoteID`, `createdAt`, `updatedAt`). Has `@Transient var snoozedUntil` for non-persisted snooze state.
- `Tag` - Categorization with `id`, `name`, `colorHex`, inverse relationship to reminders, and sync field (`remoteID`).
- `RecurrenceRule` - Enum (`none`, `daily`, `hourly`, `weekly(weekday:)`, `monthly(day:)`) with occurrence calculation logic. Stored as JSON-encoded `Data` on `Reminder.recurrenceRuleData`.

### Services Layer

All services are singletons accessed via `.shared` and use `@MainActor` for UI/SwiftData interaction.

**AuthService** (`Services/AuthService.swift`):
- Sign In with Apple (primary) and Google account linking via `GoogleSignIn` SDK
- Publishes `isAuthenticated`, `userEmail`, `authProvider`, `linkedProviders`
- Uses `APIClient` to exchange identity tokens with the backend (`/v1/auth/apple`, `/v1/auth/link/google`)
- Stores session metadata in `UserDefaults` (`userEmail`, `authProvider`, `linkedProviders`)

**APIClient** (`Services/APIClient.swift`):
- Generic HTTP client with `Endpoint` struct (path, method, body, requiresAuth)
- Two environments: development (`localhost:8080`), production (`memoss-backend.fly.dev`)
- Automatic JWT token refresh on 401 responses via `/v1/auth/refresh`
- Access token held in memory (protected by `NSLock`), refresh token in Keychain
- `request<T: Decodable>()` for JSON responses, `requestVoid()` for empty responses

**SyncService** (`Services/SyncService.swift`):
- Last-write-wins sync strategy comparing `updatedAt` timestamps
- `syncAll()` syncs tags first (dependency), then reminders
- Local-only records (no `remoteID`) are pushed to backend; remote records are merged by `updatedAt`
- Individual push methods: `pushReminder()`, `pushTag()`, `deleteReminder()`, `deleteTag()`
- Sync is only active when authenticated (`isSyncEnabled` checks `apiClient.isAuthenticated`)

**KeychainService** (`Services/KeychainService.swift`):
- Async and sync wrappers around Security framework for refresh token storage
- Service name: `com.stack4nerds.memoss`, uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`

**NotificationService** (`Services/NotificationService.swift`):
- Singleton for scheduling/canceling local notifications
- Handles both one-time and recurring reminders (schedules up to 50 future occurrences)
- Supports snooze (15min, 60min, custom) and notification categories with actions
- Integrates with `AppDelegate+Notifications.swift` for handling notification responses

### Backend API Contract

All API endpoints use snake_case JSON. Key routes:
- `POST /v1/auth/apple` - Exchange Apple identity token for access/refresh tokens
- `POST /v1/auth/refresh` - Refresh expired access token
- `POST /v1/auth/logout` - Invalidate refresh token
- `POST /v1/auth/link/{provider}` - Link additional auth provider
- `DELETE /v1/auth/link/{provider}` - Unlink auth provider
- `DELETE /v1/auth/account` - Delete account
- `GET/POST /v1/reminders`, `PUT/DELETE /v1/reminders/{id}` - CRUD reminders
- `GET/POST /v1/tags`, `PUT/DELETE /v1/tags/{id}` - CRUD tags

### Feature Structure

Features are organized in `Features/` with a flat structure. Each feature view is largely self-contained. Smaller components live in `Components/` subdirectories.

- `Onboarding/OnboardingView.swift` - Self-contained onboarding flow with Lottie animation
- `Dashboard/DashboardView.swift` - Main screen with reminder list, plus `Components/` (ReminderCard, GreetingHeader, EmptyStateView, FloatingActionButton)
- `CreateReminder/CreateReminderView.swift` - Modal for new reminders
- `EditReminder/EditReminderView.swift` - Edit/delete existing reminders
- `Settings/SettingsView.swift` - Auth, sync, account linking/unlinking, about section

### Shared Components

Reusable components in `Components/`:
- `TagPickerView` - Tag selection with inline creation form
- `TagChip` - Individual tag display capsule
- `RecurrencePickerView` - Recurrence frequency selector with end date option
- `FlowLayout` - Horizontal wrapping layout for tags

### Dependencies (SPM)

- **GoogleSignIn-iOS** (8.0.0) - Google Sign-In for account linking
- **Lottie** (4.6.0) - Animation playback for onboarding mascot (`Resources/mascot-welcome.json`)

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

Feature plans live in `plans/` with naming convention `feat-{feature-name}.md`.

## Code Conventions

- SwiftUI views use `private` for internal subviews and computed properties
- `#Preview` macros for Xcode canvas previews
- MARK comments for section organization (`// MARK: - Section Name`)
- Accessibility labels and hints on interactive elements
- Minimum 44pt touch targets for buttons
- Use `@MainActor` for services that interact with UI or SwiftData context
- All `Codable` types that cross isolation boundaries are marked `nonisolated` and `Sendable`
- API request/response types use `CodingKeys` mapping to snake_case
- Conventional Commits: `feat:`, `fix:`, `docs:` with optional scopes like `feat(recurrence):`
