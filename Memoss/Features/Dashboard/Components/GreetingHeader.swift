//
//  GreetingHeader.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 22/01/2026.
//

import SwiftUI

struct GreetingHeader: View {
    let greeting: String
    let userName: String

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting),")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(MemossColors.textSecondary)

                Text("\(userName) \u{1F33F}")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(MemossColors.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(greeting), \(userName)")

            Spacer()

            Image(systemName: "leaf.fill")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [MemossColors.brandPrimary, MemossColors.brandPrimaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: MemossColors.brandPrimary.opacity(0.35), radius: 16, y: 8)
                .accessibilityHidden(true)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

#Preview {
    GreetingHeader(greeting: "Good morning", userName: "James")
        .padding()
        .background(MemossColors.backgroundStart)
}
