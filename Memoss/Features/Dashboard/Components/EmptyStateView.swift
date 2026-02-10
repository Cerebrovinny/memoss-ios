//
//  EmptyStateView.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 22/01/2026.
//

import SwiftUI

struct EmptyStateView: View {
    @State private var isFloating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("mascot-sleep")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .offset(y: isFloating ? -8 : 0)
                .animation(
                    reduceMotion ? .none : .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                    value: isFloating
                )
                .onAppear { isFloating = !reduceMotion }
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("All clear! \u{1F33F}")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(MemossColors.textPrimary)

                Text("No reminders yet.\nTap + to create your first one!")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(MemossColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .accessibilityElement(children: .combine)

            // Double Spacer creates 2:1 ratio, pushing content into upper third
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

#Preview {
    EmptyStateView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [MemossColors.backgroundStart, MemossColors.backgroundEnd],
                startPoint: .top,
                endPoint: .bottom
            )
        )
}
