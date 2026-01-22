//
//  EmptyStateView.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 22/01/2026.
//

import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "leaf.fill")
                .font(.system(size: 72, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [MemossColors.brandPrimary.opacity(0.6), MemossColors.brandPrimaryDark.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("All clear! \u{1F33F}")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(MemossColors.textPrimary)

                Text("No reminders for today.\nTime to relax and enjoy the moment!")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(MemossColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .accessibilityElement(children: .combine)

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
