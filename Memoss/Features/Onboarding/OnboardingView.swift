// swiftlint:disable file_length
//
//  OnboardingView.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 21/01/2026.
//

import SwiftUI
import UIKit
import UserNotifications

// MARK: - Colors (inline for MVP, extract when shared by 3+ features)

private enum OnboardingColors {
    static let brandPrimary = Color(hex: "#22C55E")
    static let brandPrimaryDark = Color(hex: "#16A34A")
    static let backgroundStart = Color(hex: "#F9F7F3")
    static let backgroundEnd = Color(hex: "#F0F9F4")
    static let textPrimary = Color(hex: "#252320")
    static let textSecondary = Color(hex: "#A8A298")
    static let white = Color(hex: "#FFFFFF")
    static let accent = Color(hex: "#EAB308")
}

// MARK: - Slide Data

private struct OnboardingSlide: Identifiable {
    let id: Int
    let title: String
    let description: String
    let systemImage: String?
    let iconGradient: [Color]
    let accentColor: Color

    static let slides: [OnboardingSlide] = [
        OnboardingSlide(
            id: 0,
            title: "Hello, I'm memoss",
            // swiftlint:disable:next line_length
            description: "Like moss on a forest floor, I'll gently grow alongside you—catching the things you might forget.",
            systemImage: nil,
            iconGradient: [OnboardingColors.brandPrimary, OnboardingColors.brandPrimaryDark],
            accentColor: OnboardingColors.brandPrimary
        ),
        OnboardingSlide(
            id: 1,
            title: "Snooze in your rhythm",
            description: "Need exactly 47 minutes? Done. Reminders bend to your day, not the other way around.",
            systemImage: "clock.badge.checkmark",
            iconGradient: [OnboardingColors.accent, Color(hex: "#F59E0B")],
            accentColor: OnboardingColors.accent
        ),
        OnboardingSlide(
            id: 2,
            title: "Patterns that fit your life",
            description: "Every morning at 7. Every third Thursday. Whatever rhythm your days follow—I'll follow too.",
            systemImage: "calendar.badge.clock",
            iconGradient: [Color(hex: "#8B5CF6"), Color(hex: "#A855F7")],
            accentColor: Color(hex: "#8B5CF6")
        ),
        OnboardingSlide(
            id: 3,
            title: "One mind, many places",
            description: "Check it off anywhere. Your phone, your tablet, your Mac—all breathing together.",
            systemImage: "arrow.triangle.2.circlepath",
            iconGradient: [Color(hex: "#06B6D4"), Color(hex: "#0EA5E9")],
            accentColor: Color(hex: "#06B6D4")
        )
    ]
}

// MARK: - Main View

struct OnboardingView: View {
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let slides = OnboardingSlide.slides
    private var totalPages: Int { slides.count + 1 }
    private var isOnPermissionScreen: Bool { currentPage == slides.count }

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundGradient

            TabView(selection: $currentPage) {
                ForEach(slides) { slide in
                    SlideView(slide: slide)
                        .tag(slide.id)
                }

                NotificationPermissionView(onComplete: completeOnboarding)
                    .tag(slides.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.8), value: currentPage)

            if !isOnPermissionScreen {
                navigationControls
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Private Views

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [OnboardingColors.backgroundStart, OnboardingColors.backgroundEnd],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var navigationControls: some View {
        HStack {
            Button("Skip") {
                if reduceMotion {
                    currentPage = slides.count
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        currentPage = slides.count
                    }
                }
            }
            .font(.body.weight(.medium))
            .foregroundStyle(OnboardingColors.textSecondary)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())

            Spacer()

            Button {
                if reduceMotion {
                    if currentPage < totalPages - 1 {
                        currentPage += 1
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if currentPage < totalPages - 1 {
                            currentPage += 1
                        }
                    }
                }
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
    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: CGFloat = 0
    @State private var textOpacity: CGFloat = 0
    @State private var floatOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                // Ambient glow behind icon
                Circle()
                    .fill(slide.accentColor.opacity(0.08))
                    .frame(width: 220, height: 220)
                    .blur(radius: 30)
                    .scaleEffect(pulseScale)

                iconView
                    .offset(y: floatOffset)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)

            VStack(spacing: 14) {
                Text(slide.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(OnboardingColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(slide.description)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(OnboardingColors.textSecondary)
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

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                iconScale = 1
                iconOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.25)) {
                textOpacity = 1
            }

            // Gentle floating animation
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                floatOffset = -6
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
                    .frame(width: 170, height: 170)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: slide.iconGradient.map { $0.opacity(0.12) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 150, height: 150)

                Image(systemName: systemImage)
                    .font(.system(size: 56, weight: .medium))
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
            // Welcome screen - special treatment with layered leaves
            ZStack {
                // Decorative small leaves
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(OnboardingColors.brandPrimary.opacity(0.2))
                        .rotationEffect(.degrees(Double(index) * 120 - 30))
                        .offset(
                            x: cos(Double(index) * 2.1) * 80,
                            y: sin(Double(index) * 2.1) * 80
                        )
                }

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                OnboardingColors.brandPrimary.opacity(0.3),
                                OnboardingColors.brandPrimaryDark.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 180, height: 180)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                OnboardingColors.brandPrimary.opacity(0.12),
                                OnboardingColors.brandPrimaryDark.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)

                Image(systemName: "leaf.fill")
                    .font(.system(size: 72, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [OnboardingColors.brandPrimary, OnboardingColors.brandPrimaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: OnboardingColors.brandPrimary.opacity(0.35), radius: 16, y: 8)
            }
        }
    }
}

// MARK: - Notification Permission View

private struct NotificationPermissionView: View {
    let onComplete: () -> Void

    @State private var permissionState: PermissionState = .notDetermined
    @State private var isRequesting = false
    @State private var iconScale: CGFloat = 0.8
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
                    .fill(iconColors.first?.opacity(0.08) ?? .clear)
                    .frame(width: 220, height: 220)
                    .blur(radius: 30)
                    .scaleEffect(pulseScale)

                iconView
                    .offset(y: floatOffset)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)

            VStack(spacing: 14) {
                Text(titleForState)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(OnboardingColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text(descriptionForState)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(OnboardingColors.textSecondary)
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
                .frame(width: 170, height: 170)
                .rotationEffect(.degrees(ringRotation))

            Circle()
                .fill(iconBackgroundGradient)
                .frame(width: 150, height: 150)

            Image(systemName: iconForState)
                .font(.system(size: 56, weight: .medium))
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
            [OnboardingColors.brandPrimary, OnboardingColors.accent]
        case .granted:
            [OnboardingColors.brandPrimary, OnboardingColors.brandPrimaryDark]
        case .denied, .error:
            [OnboardingColors.textSecondary, Color(hex: "#78716C")]
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
            "I'll only whisper when it matters. No noise, just the nudges you actually need."
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
                    Text("Let's begin")
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

// MARK: - Button Style

private struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(OnboardingColors.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: isEnabled
                                ? [OnboardingColors.brandPrimary, OnboardingColors.brandPrimaryDark]
                                : [OnboardingColors.textSecondary, OnboardingColors.textSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: isEnabled ? OnboardingColors.brandPrimary.opacity(0.4) : .clear,
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
}

#Preview("First Slide") {
    SlideView(slide: OnboardingSlide.slides[0])
        .background(
            LinearGradient(
                colors: [OnboardingColors.backgroundStart, OnboardingColors.backgroundEnd],
                startPoint: .top,
                endPoint: .bottom
            )
        )
}
