//
//  MemossApp.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 21/01/2026.
//

import SwiftData
import SwiftUI

@main
struct MemossApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    static let sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: Reminder.self, Tag.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    DashboardView()
                } else {
                    OnboardingView()
                }
            }
            .task {
                await Self.seedDefaultTags()
            }
        }
        .modelContainer(Self.sharedModelContainer)
    }

    @MainActor
    private static func seedDefaultTags() async {
        let context = sharedModelContainer.mainContext

        let descriptor = FetchDescriptor<Tag>()
        guard (try? context.fetchCount(descriptor)) == 0 else { return }

        let defaults: [(name: String, hex: String)] = [
            ("Personal", "#22C55E"),
            ("Work", "#3B82F6"),
            ("Health", "#EC4899"),
            ("Shopping", "#F97316")
        ]

        for tag in defaults {
            context.insert(Tag(name: tag.name, colorHex: tag.hex))
        }
    }
}
