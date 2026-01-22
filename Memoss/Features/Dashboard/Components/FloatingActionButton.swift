//
//  FloatingActionButton.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 22/01/2026.
//

import SwiftUI

struct FloatingActionButton: View {
    let action: () -> Void

    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [MemossColors.brandPrimary, MemossColors.brandPrimaryDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: MemossColors.brandPrimary.opacity(0.4),
                            radius: isPressed ? 8 : 16,
                            y: isPressed ? 4 : 8
                        )
                )
        }
        .buttonStyle(FABButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel("Add reminder")
        .accessibilityHint("Creates a new reminder")
    }
}

private struct FABButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(
                reduceMotion ? .none : .spring(response: 0.2, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}

#Preview {
    ZStack {
        MemossColors.backgroundEnd
            .ignoresSafeArea()

        VStack {
            Spacer()
            HStack {
                Spacer()
                FloatingActionButton {}
                    .padding(24)
            }
        }
    }
}
