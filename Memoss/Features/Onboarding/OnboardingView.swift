// swiftlint:disable file_length
//
//  OnboardingView.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 21/01/2026.
//

import SwiftData
import SwiftUI
import UIKit
import UserNotifications

// MARK: - Onboarding Category

enum OnboardingCategory: String, CaseIterable, Identifiable {
    case health
    case work
    case errands
    case life

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .health: "Health"
        case .work: "Work"
        case .errands: "Errands"
        case .life: "Life"
        }
    }

    var icon: String {
        switch self {
        case .health: "heart.fill"
        case .work: "briefcase.fill"
        case .errands: "cart.fill"
        case .life: "drop.fill"
        }
    }

    var color: Color {
        switch self {
        case .health: Color(hex: "#EF4444")  // Red
        case .work: Color(hex: "#3B82F6")    // Blue
        case .errands: Color(hex: "#F59E0B") // Amber
        case .life: Color(hex: "#06B6D4")    // Cyan
        }
    }

    var defaultReminderTitle: String {
        switch self {
        case .health: "Take morning vitamins"
        case .work: "Review daily tasks"
        case .errands: "Check shopping list"
        case .life: "Drink water"
        }
    }

    var defaultTime: (hour: Int, minute: Int) {
        switch self {
        case .health: (8, 0)
        case .work: (9, 0)
        case .errands: (10, 0)
        case .life: (8, 0)
        }
    }

    var defaultRecurrenceRule: RecurrenceRule {
        switch self {
        case .health: .daily
        case .work: .weekly(weekday: 2) // Monday
        case .errands: .none
        case .life: .daily
        }
    }
}

// MARK: - Onboarding State

@Observable
final class OnboardingState {
    var selectedCategories: Set<OnboardingCategory> = []
    var createdReminder: Reminder?
    var didSkipReminderCreation = false

    var primaryCategory: OnboardingCategory {
        // Return first selected in enum order (deterministic), default to health
        let sortedSelected = OnboardingCategory.allCases.filter { selectedCategories.contains($0) }
        return sortedSelected.first ?? .health
    }
}

// MARK: - Slide Data

private struct OnboardingSlide: Identifiable {
    let id: Int
    let title: String
    let description: String
    let systemImage: String?
    let iconGradient: [Color]
    let accentColor: Color
}

private let welcomeSlide = OnboardingSlide(
    id: 0,
    title: "Remember everything that matters",
    // swiftlint:disable:next line_length
    description: "Like moss on a forest floor, I'll gently grow alongside you—catching the things you might forget.",
    systemImage: nil,
    iconGradient: [MemossColors.brandPrimary, MemossColors.brandPrimaryDark],
    accentColor: MemossColors.brandPrimary
)

// MARK: - Main View

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var onboardingState = OnboardingState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext

    // New flow: Welcome -> Personalization -> Reminder Creation -> Notification -> Success
    private let totalPages = 5
    private var showNavigationControls: Bool {
        // Show Skip/Continue only on slides 0-1, hide on 2-4 (they have their own buttons)
        currentPage <= 1
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundGradient

            TabView(selection: $currentPage) {
                SlideView(slide: welcomeSlide)
                    .tag(0)

                PersonalizationSlideView(
                    onboardingState: onboardingState,
                    onContinue: { advanceToPage(2) }
                )
                .tag(1)

                ReminderCreationSlideView(
                    onboardingState: onboardingState,
                    modelContext: modelContext,
                    onContinue: { advanceToPage(3) },
                    onSkip: {
                        onboardingState.didSkipReminderCreation = true
                        advanceToPage(3)
                    }
                )
                .tag(2)

                NotificationPermissionView(onComplete: { advanceToPage(4) })
                    .tag(3)

                SuccessSlideView(
                    onboardingState: onboardingState,
                    onComplete: completeOnboarding
                )
                .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.8), value: currentPage)

            if showNavigationControls {
                navigationControls
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Private Views

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [MemossColors.backgroundStart, MemossColors.backgroundEnd],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var navigationControls: some View {
        HStack {
            Button("Skip") {
                advanceToPage(3) // Skip to notification permission
            }
            .font(.body.weight(.medium))
            .foregroundStyle(MemossColors.textSecondary)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())

            Spacer()

            Button {
                advanceToPage(currentPage + 1)
            } label: {
                HStack(spacing: 8) {
                    Text("Continue")
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.semibold))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }

    // MARK: - Private Methods

    private func advanceToPage(_ page: Int) {
        if reduceMotion {
            currentPage = page
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentPage = page
            }
        }
    }

    private func completeOnboarding() {
        if reduceMotion {
            hasCompletedOnboarding = true
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                hasCompletedOnboarding = true
            }
        }
    }
}

// MARK: - Slide View

private struct SlideView: View {
    let slide: OnboardingSlide
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: CGFloat = 0
    @State private var textOpacity: CGFloat = 0
    @State private var floatOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0

    private var isWelcomeSlide: Bool { slide.systemImage == nil }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                // Ambient glow behind icon
                Circle()
                    .fill(slide.accentColor.opacity(isWelcomeSlide ? 0.15 : 0.08))
                    .frame(width: 300, height: 300)
                    .blur(radius: 40)
                    .scaleEffect(pulseScale)

                if isWelcomeSlide {
                    WelcomeSparklesView()
                }

                iconView
                    .offset(y: floatOffset)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)

            VStack(spacing: 14) {
                Text(slide.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(MemossColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(slide.description)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(MemossColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(textOpacity)

            Spacer()
            Spacer()
        }
        .onAppear {
            guard !reduceMotion else {
                iconScale = 1
                iconOpacity = 1
                textOpacity = 1
                return
            }

            withAnimation(.spring(
                response: isWelcomeSlide ? 0.8 : 0.6,
                dampingFraction: isWelcomeSlide ? 0.5 : 0.7
            ).delay(0.15)) {
                iconScale = 1
                iconOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(isWelcomeSlide ? 0.4 : 0.25)) {
                textOpacity = 1
            }

            // Gentle floating animation
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                floatOffset = isWelcomeSlide ? -10 : -6
            }

            // Subtle pulse on ambient glow
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let systemImage = slide.systemImage {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: slide.iconGradient.map { $0.opacity(0.3) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 200, height: 200)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: slide.iconGradient.map { $0.opacity(0.12) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 175, height: 175)

                Image(systemName: systemImage)
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: slide.iconGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: slide.accentColor.opacity(0.3), radius: 12, y: 6)
            }
        } else {
            // Welcome screen - show mascot image
            Image("mascot-welcome")
                .resizable()
                .scaledToFit()
                .frame(width: 280, height: 280)
        }
    }
}

// MARK: - Welcome Sparkles

private struct WelcomeSparklesView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var burstOut = false
    @State private var fadeOut = false

    private static let particles: [(angle: Double, distance: CGFloat, size: CGFloat)] = [
        (0, 140, 8), (30, 160, 5), (60, 130, 10),
        (90, 155, 6), (120, 145, 8), (150, 165, 5),
        (180, 135, 7), (210, 150, 9), (240, 140, 6),
        (270, 160, 8), (300, 145, 5), (330, 155, 7)
    ]

    var body: some View {
        ZStack {
            ForEach(Array(Self.particles.enumerated()), id: \.offset) { index, particle in
                let rad = particle.angle * .pi / 180
                let targetX = CGFloat(cos(rad)) * particle.distance
                let targetY = CGFloat(sin(rad)) * particle.distance

                Circle()
                    .fill(particleColor(index: index))
                    .frame(width: particle.size, height: particle.size)
                    .offset(
                        x: burstOut ? targetX : 0,
                        y: burstOut ? targetY : 0
                    )
                    .scaleEffect(burstOut ? 1.0 : 0.1)
                    .opacity(fadeOut ? 0 : (burstOut ? 0.7 : 0))
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
                burstOut = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(1.2)) {
                fadeOut = true
            }
        }
    }

    private func particleColor(index: Int) -> Color {
        switch index % 3 {
        case 0: MemossColors.brandPrimary
        case 1: MemossColors.accent
        default: MemossColors.brandPrimaryDark
        }
    }
}

// MARK: - Notification Permission View

private struct NotificationPermissionView: View {
    let onComplete: () -> Void

    @State private var permissionState: PermissionState = .notDetermined
    @State private var isRequesting = false
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: CGFloat = 0
    @State private var contentOpacity: CGFloat = 0
    @State private var floatOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var ringRotation: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum PermissionState {
        case notDetermined, granted, denied, error
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                // Ambient glow
                Circle()
                    .fill(iconColors.first?.opacity(0.15) ?? .clear)
                    .frame(width: 280, height: 280)
                    .blur(radius: 40)
                    .scaleEffect(pulseScale)

                iconView
                    .offset(y: floatOffset)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)

            VStack(spacing: 14) {
                Text(titleForState)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(MemossColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(descriptionForState)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(MemossColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(contentOpacity)

            Spacer()

            actionButton
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
                .opacity(contentOpacity)
        }
        .task {
            await checkInitialStatus()
            animateIn()
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private var iconView: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: iconColors.map { $0.opacity(0.3) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(ringRotation))

            Circle()
                .fill(iconBackgroundGradient)
                .frame(width: 175, height: 175)

            Image(systemName: iconForState)
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(iconForegroundGradient)
                .symbolEffect(.bounce, value: permissionState)
                .shadow(color: iconColors.first?.opacity(0.3) ?? .clear, radius: 12, y: 6)
        }
    }

    private var iconBackgroundGradient: some ShapeStyle {
        LinearGradient(
            colors: iconColors.map { $0.opacity(0.15) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var iconForegroundGradient: some ShapeStyle {
        LinearGradient(
            colors: iconColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var iconColors: [Color] {
        switch permissionState {
        case .notDetermined:
            [MemossColors.brandPrimary, MemossColors.accent]
        case .granted:
            [MemossColors.brandPrimary, MemossColors.brandPrimaryDark]
        case .denied, .error:
            [MemossColors.textSecondary, MemossColors.textSecondary.opacity(0.7)]
        }
    }

    private var iconForState: String {
        switch permissionState {
        case .notDetermined: "bell.badge"
        case .granted: "checkmark.seal.fill"
        case .denied: "bell.slash"
        case .error: "exclamationmark.triangle"
        }
    }

    private var titleForState: String {
        switch permissionState {
        case .notDetermined: "A gentle tap on the shoulder"
        case .granted: "Perfect, we're connected"
        case .denied: "That's okay, really"
        case .error: "Hmm, something's off"
        }
    }

    private var descriptionForState: String {
        switch permissionState {
        case .notDetermined:
            "Enable notifications so you never miss what's important."
        case .granted:
            "I'll be here when you need me—quietly waiting until the right moment."
        case .denied:
            "I'll still be here, keeping track of things. You can find me in Settings whenever you're ready."
        case .error:
            "Something got tangled up. You can always set this up later in Settings."
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch permissionState {
        case .notDetermined:
            Button {
                Task { await requestPermission() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bell.badge")
                        .font(.body.weight(.semibold))
                    Text("Let me remind you")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isRequesting)

        case .granted, .denied, .error:
            Button {
                onComplete()
            } label: {
                HStack(spacing: 10) {
                    Text("Continue")
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: - Private Methods

    private func animateIn() {
        guard !reduceMotion else {
            iconScale = 1
            iconOpacity = 1
            contentOpacity = 1
            return
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            iconScale = 1
            iconOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.25)) {
            contentOpacity = 1
        }

        // Gentle floating animation
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            floatOffset = -6
        }

        // Subtle pulse on ambient glow
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            pulseScale = 1.05
        }

        // Slow ring rotation
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
    }

    private func checkInitialStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                permissionState = .granted
            case .denied:
                permissionState = .denied
            case .notDetermined:
                permissionState = .notDetermined
            @unknown default:
                permissionState = .notDetermined
            }
        }
    }

    @MainActor
    private func requestPermission() async {
        isRequesting = true
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if reduceMotion {
                permissionState = granted ? .granted : .denied
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    permissionState = granted ? .granted : .denied
                }
            }
            isRequesting = false
            UINotificationFeedbackGenerator().notificationOccurred(granted ? .success : .warning)
        } catch {
            if reduceMotion {
                permissionState = .error
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    permissionState = .error
                }
            }
            isRequesting = false
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

// MARK: - Personalization Slide View

private struct PersonalizationSlideView: View {
    let onboardingState: OnboardingState
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentOpacity: CGFloat = 0
    @State private var floatOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0

    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Mascot image with ambient glow
            ZStack {
                Circle()
                    .fill(MemossColors.brandPrimary.opacity(0.15))
                    .frame(width: 260, height: 260)
                    .blur(radius: 40)
                    .scaleEffect(pulseScale)

                // Use mascot-welcome as fallback until mascot-question is provided
                Image("mascot-welcome")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .offset(y: floatOffset)
            }
            .opacity(contentOpacity)

            VStack(spacing: 14) {
                Text("What do you want to remember?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(MemossColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("Pick what matters most to you")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(MemossColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(contentOpacity)

            // 2x2 grid of category buttons
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(OnboardingCategory.allCases) { category in
                    CategoryButton(
                        category: category,
                        isSelected: onboardingState.selectedCategories.contains(category),
                        onTap: {
                            haptic.impactOccurred()
                            if reduceMotion {
                                toggleCategory(category)
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    toggleCategory(category)
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 32)
            .opacity(contentOpacity)

            Spacer()
            Spacer()
        }
        .onAppear {
            haptic.prepare()

            guard !reduceMotion else {
                contentOpacity = 1
                return
            }

            withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                contentOpacity = 1
            }

            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                floatOffset = -8
            }

            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
        }
    }

    private func toggleCategory(_ category: OnboardingCategory) {
        if onboardingState.selectedCategories.contains(category) {
            onboardingState.selectedCategories.remove(category)
        } else {
            onboardingState.selectedCategories.insert(category)
        }
    }
}

// MARK: - Category Button

private struct CategoryButton: View {
    let category: OnboardingCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(isSelected ? category.color : MemossColors.textSecondary)

                Text(category.displayName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? MemossColors.textPrimary : MemossColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(MemossColors.cardBackground)
                    .shadow(
                        color: isSelected ? category.color.opacity(0.2) : .black.opacity(0.04),
                        radius: isSelected ? 12 : 8,
                        y: isSelected ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? category.color : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.displayName) category")
        .accessibilityHint(isSelected ? "Selected. Double tap to deselect." : "Double tap to select.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Reminder Creation Slide View

private struct ReminderCreationSlideView: View {
    let onboardingState: OnboardingState
    let modelContext: ModelContext
    let onContinue: () -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reminderTitle: String = ""
    @State private var scheduledTime: Date = Date()
    @State private var contentOpacity: CGFloat = 0
    @State private var isCreating = false

    private var category: OnboardingCategory {
        onboardingState.primaryCategory
    }

    private var recurrenceRule: RecurrenceRule {
        category.defaultRecurrenceRule
    }

    private var canCreate: Bool {
        !reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 14) {
                Text("Your first reminder")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(MemossColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("We've pre-filled this based on your selection")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(MemossColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(contentOpacity)

            // Reminder form card
            VStack(spacing: 20) {
                // Title field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reminder")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(MemossColors.textSecondary)

                    TextField("What do you want to remember?", text: $reminderTitle)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(MemossColors.textPrimary)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(MemossColors.backgroundStart)
                        )
                        .accessibilityLabel("Reminder title")
                }

                // Time picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(MemossColors.textSecondary)

                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(MemossColors.brandPrimary)

                        DatePicker(
                            "Time",
                            selection: $scheduledTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(MemossColors.brandPrimary)

                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(MemossColors.backgroundStart)
                    )
                    .accessibilityLabel("Reminder time")
                }

                // Recurrence indicator (read-only)
                HStack {
                    Image(systemName: recurrenceRule.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(category.color)

                    Text(recurrenceRule.shortDisplayName)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(MemossColors.textPrimary)

                    Spacer()

                    Text("Based on your selection")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(MemossColors.textSecondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(category.color.opacity(0.1))
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Repeats \(recurrenceRule.shortDisplayName)")
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(MemossColors.cardBackground)
                    .shadow(color: .black.opacity(0.06), radius: 16, y: 4)
            )
            .padding(.horizontal, 24)
            .opacity(contentOpacity)

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    Task { await createReminder() }
                } label: {
                    HStack(spacing: 10) {
                        if isCreating {
                            ProgressView()
                                .tint(Color.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body.weight(.semibold))
                            Text("Create Reminder")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canCreate || isCreating)
                .padding(.horizontal, 24)

                Button("Skip for now") {
                    onSkip()
                }
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(MemossColors.textSecondary)
                .padding(.vertical, 8)
            }
            .padding(.bottom, 48)
            .opacity(contentOpacity)
        }
        .onAppear {
            // Pre-fill from category defaults
            updateFromCategory()

            guard !reduceMotion else {
                contentOpacity = 1
                return
            }

            withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                contentOpacity = 1
            }
        }
        .onChange(of: onboardingState.selectedCategories) { _, _ in
            // Update when user changes category selection (e.g., goes back and selects different category)
            updateFromCategory()
        }
    }

    private func updateFromCategory() {
        reminderTitle = category.defaultReminderTitle
        let defaultTime = category.defaultTime
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = defaultTime.hour
        components.minute = defaultTime.minute
        if let date = Calendar.current.date(from: components) {
            scheduledTime = date
        }
    }

    @MainActor
    private func createReminder() async {
        isCreating = true

        // Build the scheduled date
        let finalDate = adjustedScheduledDate()

        // Create the reminder
        let reminder = Reminder(title: reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines), scheduledDate: finalDate)
        reminder.recurrenceRule = recurrenceRule

        modelContext.insert(reminder)

        // Schedule notification
        await NotificationService.shared.scheduleNotifications(for: reminder)

        // Store in onboarding state for success screen
        onboardingState.createdReminder = reminder

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        isCreating = false
        onContinue()
    }

    private func adjustedScheduledDate() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        let timeComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute

        guard let date = calendar.date(from: components) else {
            return scheduledTime
        }

        // If time is in the past, adjust to tomorrow
        if date <= Date() {
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }

        return date
    }
}

// MARK: - Success Slide View

private struct SuccessSlideView: View {
    let onboardingState: OnboardingState
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentOpacity: CGFloat = 0
    @State private var iconScale: CGFloat = 0.5
    @State private var floatOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var celebrationBurst = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Trophy mascot with celebration
            ZStack {
                // Ambient glow
                Circle()
                    .fill(MemossColors.accent.opacity(0.2))
                    .frame(width: 300, height: 300)
                    .blur(radius: 40)
                    .scaleEffect(pulseScale)

                // Celebration particles
                if !reduceMotion {
                    CelebrationParticlesView(burst: celebrationBurst)
                }

                Image("mascot-trophy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .offset(y: floatOffset)
            }
            .scaleEffect(iconScale)
            .opacity(contentOpacity)

            VStack(spacing: 14) {
                Text("You're all set!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(MemossColors.textPrimary)
                    .multilineTextAlignment(.center)

                if let reminder = onboardingState.createdReminder {
                    // Show reminder summary
                    ReminderSummaryCard(reminder: reminder)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                } else {
                    Text("Start adding reminders to never forget what matters.")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(MemossColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .opacity(contentOpacity)

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onComplete()
            } label: {
                HStack(spacing: 10) {
                    Text("Let's go!")
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
            .opacity(contentOpacity)
        }
        .onAppear {
            guard !reduceMotion else {
                iconScale = 1
                contentOpacity = 1
                return
            }

            withAnimation(.spring(response: 0.8, dampingFraction: 0.5).delay(0.15)) {
                iconScale = 1
            }

            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                contentOpacity = 1
            }

            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                floatOffset = -8
            }

            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
            }

            // Trigger celebration after mascot appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                celebrationBurst = true
            }
        }
    }
}

// MARK: - Reminder Summary Card

private struct ReminderSummaryCard: View {
    let reminder: Reminder

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bell.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(MemossColors.brandPrimary)

                Text(reminder.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(MemossColors.textPrimary)
                    .lineLimit(1)

                Spacer()
            }

            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MemossColors.textSecondary)

                Text(reminder.scheduledDate.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(MemossColors.textSecondary)

                Text("•")
                    .foregroundStyle(MemossColors.textSecondary)

                Image(systemName: reminder.recurrenceRule.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MemossColors.textSecondary)

                Text(reminder.recurrenceRule.shortDisplayName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(MemossColors.textSecondary)

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(MemossColors.brandPrimary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(MemossColors.brandPrimary.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your reminder: \(reminder.title) at \(reminder.scheduledDate.formatted(date: .omitted, time: .shortened)), \(reminder.recurrenceRule.shortDisplayName)")
    }
}

// MARK: - Celebration Particles

private struct CelebrationParticlesView: View {
    let burst: Bool

    private static let particles: [(angle: Double, distance: CGFloat, size: CGFloat, color: Color)] = [
        (15, 160, 10, MemossColors.brandPrimary),
        (45, 140, 8, MemossColors.accent),
        (75, 170, 6, MemossColors.brandPrimaryDark),
        (105, 150, 9, MemossColors.accent),
        (135, 165, 7, MemossColors.brandPrimary),
        (165, 145, 8, MemossColors.brandPrimaryDark),
        (195, 155, 10, MemossColors.accent),
        (225, 175, 6, MemossColors.brandPrimary),
        (255, 140, 8, MemossColors.brandPrimaryDark),
        (285, 160, 7, MemossColors.accent),
        (315, 150, 9, MemossColors.brandPrimary),
        (345, 170, 6, MemossColors.brandPrimaryDark)
    ]

    var body: some View {
        ZStack {
            ForEach(Array(Self.particles.enumerated()), id: \.offset) { _, particle in
                let rad = particle.angle * .pi / 180
                let targetX = CGFloat(cos(rad)) * particle.distance
                let targetY = CGFloat(sin(rad)) * particle.distance

                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(
                        x: burst ? targetX : 0,
                        y: burst ? targetY : 0
                    )
                    .scaleEffect(burst ? 1.0 : 0.1)
                    .opacity(burst ? 0.8 : 0)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.6).delay(Double.random(in: 0...0.2)),
                        value: burst
                    )
            }
        }
    }
}

// MARK: - Button Style

private struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: isEnabled
                                ? [MemossColors.brandPrimary, MemossColors.brandPrimaryDark]
                                : [MemossColors.textSecondary, MemossColors.textSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: isEnabled ? MemossColors.brandPrimary.opacity(0.4) : .clear,
                        radius: configuration.isPressed ? 4 : 12,
                        y: configuration.isPressed ? 2 : 6
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Onboarding Flow") {
    OnboardingView()
        .modelContainer(for: [Reminder.self, Tag.self], inMemory: true)
}

#Preview("Welcome Slide") {
    SlideView(slide: welcomeSlide)
        .background(
            LinearGradient(
                colors: [MemossColors.backgroundStart, MemossColors.backgroundEnd],
                startPoint: .top,
                endPoint: .bottom
            )
        )
}
