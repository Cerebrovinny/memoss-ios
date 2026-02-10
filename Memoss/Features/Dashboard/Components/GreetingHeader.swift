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
        VStack(alignment: .leading, spacing: 4) {
            Text("\(greeting),")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(MemossColors.textSecondary)

            Text(userName)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(MemossColors.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(greeting), \(userName)")
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

#Preview {
    GreetingHeader(greeting: "Good morning", userName: "James")
        .padding()
        .background(MemossColors.backgroundStart)
}
