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

    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Reminder.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    DashboardView()
                } else {
                    OnboardingView()
                }
            }
            .onAppear {
                appDelegate.modelContainer = modelContainer
            }
        }
        .modelContainer(modelContainer)
    }
}
