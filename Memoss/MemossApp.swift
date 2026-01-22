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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                DashboardView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(for: Reminder.self)
    }
}
