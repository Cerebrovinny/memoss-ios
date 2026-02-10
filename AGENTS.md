# Repository Guidelines

## Project Structure & Module Organization
- `Memoss/` contains the SwiftUI app code.
  - `Features/` holds feature screens (e.g., `DashboardView`, `OnboardingView`).
  - `Components/` holds reusable UI pieces like tag chips and pickers.
  - `Services/` includes notification, auth, API, and sync helpers.
  - `Models/` contains SwiftData models (`Reminder`, `Tag`, `RecurrenceRule`).
  - `Extensions/` centralizes colors and utilities (e.g., `MemossColors`).
  - `Assets.xcassets/` stores app images and color assets.
- `Memoss.xcodeproj/` is the Xcode project.
- `plans/` contains feature design notes (`feat-*.md`).
- `screenshots/` stores UI reference images.

## Build, Test, and Development Commands
- `open Memoss.xcodeproj` opens the project in Xcode for run/debug.
- `xcodebuild -project Memoss.xcodeproj -scheme Memoss -sdk iphonesimulator build` builds the app for the simulator.
- `xcodebuild -project Memoss.xcodeproj -scheme Memoss -sdk iphonesimulator test` runs tests (when test targets exist).

## Coding Style & Naming Conventions
- Use 4-space indentation and SwiftUI idioms.
- Keep internal subviews/computed properties `private`.
- Use `#Preview` for view previews and `// MARK: -` for sectioning.
- Name feature files as `Features/<Feature>/<Feature>View.swift` and keep feature-specific components in `Features/<Feature>/Components/`.
- Use `MemossColors` for shared colors; only keep local color enums in feature files if truly feature-specific.

## Testing Guidelines
- There are currently no test targets. If you add tests, use XCTest and name files `SomethingTests.swift`.
- Focus on core behaviors (recurrence logic, notification scheduling, tag assignment).
- Run tests via `xcodebuild ... test` or the Xcode Test action.

## Commit & Pull Request Guidelines
- Follow Conventional Commits seen in history: `feat:`, `fix:`, `docs:` with optional scopes like `feat(recurrence):` and optional PR refs `(#11)`.
- Keep subjects short and imperative.
- PRs should include a concise description, link to related `plans/feat-*.md` when relevant, and add screenshots for UI changes.

## Repository References
- Read `CLAUDE.md` for architecture, UI patterns, and design system notes before making structural changes.
