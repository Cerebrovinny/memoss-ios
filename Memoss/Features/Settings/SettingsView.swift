//
//  SettingsView.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 23/01/2026.
//

import AuthenticationServices
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Observe services via @ObservedObject to avoid direct singleton access in body
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var syncService = SyncService.shared

    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showUnlinkAlert = false
    @State private var isLoading = false
    @State private var isLinkingGoogle = false
    @State private var pendingUnlinkProvider: String?
    @State private var unlinkingProvider: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    syncSection
                    aboutSection
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [MemossColors.backgroundStart, MemossColors.backgroundEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(MemossColors.brandPrimary)
                }
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    Task { await signOut() }
                }
            } message: {
                Text("Your reminders will remain on this device but won't sync to other devices.")
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("This will permanently delete your account and all synced data. Your local reminders will remain on this device.")
            }
            .alert("Unlink Account", isPresented: $showUnlinkAlert, presenting: pendingUnlinkProvider) { provider in
                Button("Cancel", role: .cancel) {
                    pendingUnlinkProvider = nil
                }
                Button("Unlink", role: .destructive) {
                    Task { await confirmUnlink(provider) }
                }
            } message: { provider in
                Text("You won't be able to sign in with \(providerDisplayName(provider)) unless another account is linked.")
            }
        }
    }

    // MARK: - Sync Section

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Sync")

            if authService.isAuthenticated {
                signedInCard
            } else {
                signInCard
            }
        }
    }

    private var signedInCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(MemossColors.success)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Signed In")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MemossColors.textPrimary)

                    if let email = authService.userEmail, !email.isEmpty {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(MemossColors.textSecondary)
                    }

                    if let provider = authService.authProvider {
                        Text("via \(provider.rawValue.capitalized)")
                            .font(.caption)
                            .foregroundStyle(MemossColors.textSecondary)
                    }
                }

                Spacer()

                if syncService.isSyncing {
                    ProgressView()
                        .tint(MemossColors.brandPrimary)
                }
            }

            if let lastSync = syncService.lastSyncDate {
                HStack {
                    Text("Last synced")
                        .font(.subheadline)
                        .foregroundStyle(MemossColors.textSecondary)
                    Spacer()
                    Text(lastSync, format: .relative(presentation: .named))
                        .font(.subheadline)
                        .foregroundStyle(MemossColors.textSecondary)
                }
            }

            Button {
                Task { await sync() }
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sync Now")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(MemossColors.brandPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(MemossColors.brandPrimary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(syncService.isSyncing)

            linkedAccountsSection

            Divider()

            VStack(spacing: 12) {
                Button {
                    showSignOutAlert = true
                } label: {
                    Text("Sign Out")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MemossColors.warning)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(MemossColors.warning.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(MemossColors.warning.opacity(0.2), lineWidth: 1)
                        )
                }

                Button {
                    showDeleteAccountAlert = true
                } label: {
                    Text("Delete Account")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MemossColors.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(MemossColors.error.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(MemossColors.error.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
        .padding()
        .background(MemossColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: MemossColors.brandPrimary.opacity(0.08), radius: 12, y: 4)
    }

    @ViewBuilder
    private var linkedAccountsSection: some View {
        Divider()

        VStack(alignment: .leading, spacing: 12) {
            Text("Linked Accounts")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MemossColors.textPrimary)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(MemossColors.error)
            }

            if authService.linkedProviders.isEmpty {
                Text("Link an account to sign in with multiple providers.")
                    .font(.caption)
                    .foregroundStyle(MemossColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            } else {
                ForEach(authService.linkedProviders, id: \.self) { provider in
                    linkedProviderRow(for: provider)
                }

                if authService.linkedProviders.count == 1 {
                    Text("Link another account to enable unlinking.")
                        .font(.caption)
                        .foregroundStyle(MemossColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            if !authService.linkedProviders.contains("google") {
                Button {
                    Task { await linkGoogle() }
                } label: {
                    if isLinkingGoogle {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Linking...")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(MemossColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    } else {
                        Image("google-button")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 44)
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isLinkActionInProgress)
            }
        }
    }

    private func providerIcon(for provider: String) -> String {
        switch provider {
        case "apple": return "apple.logo"
        case "google": return "g.circle.fill"
        default: return "person.circle"
        }
    }

    private func providerDisplayName(_ provider: String) -> String {
        switch provider {
        case "apple": return "Apple"
        case "google": return "Google"
        default: return provider.capitalized
        }
    }

    @ViewBuilder
    private func linkedProviderRow(for provider: String) -> some View {
        let isPrimary = authService.authProvider?.rawValue == provider
        let canUnlink = authService.linkedProviders.count > 1
        let isUnlinking = unlinkingProvider == provider

        HStack(spacing: 10) {
            providerIconView(for: provider)
            Text(providerDisplayName(provider))
                .font(.subheadline)
            if isPrimary {
                Text("Primary")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MemossColors.brandPrimaryDark)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(MemossColors.brandPrimary.opacity(0.15))
                    .clipShape(Capsule())
            }
            Spacer()
            Button {
                pendingUnlinkProvider = provider
                showUnlinkAlert = true
            } label: {
                if isUnlinking {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(MemossColors.warning)
                } else {
                    Text("Unlink")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MemossColors.warning)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(MemossColors.warning.opacity(0.1))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(MemossColors.warning.opacity(0.2), lineWidth: 1)
            )
            .disabled(!canUnlink || isLinkActionInProgress)
            .opacity(canUnlink ? 1 : 0.4)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func providerIconView(for provider: String) -> some View {
        switch provider {
        case "google":
            GoogleIcon(size: 18)
        case "apple":
            Image(systemName: "apple.logo")
                .font(.subheadline)
                .foregroundStyle(MemossColors.textPrimary)
        default:
            Image(systemName: "person.circle")
                .font(.subheadline)
                .foregroundStyle(MemossColors.textPrimary)
        }
    }

    private var isLinkActionInProgress: Bool {
        isLinkingGoogle || unlinkingProvider != nil
    }

    private var signInCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud")
                .font(.system(size: 40))
                .foregroundStyle(MemossColors.textSecondary)
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text("Sync Your Reminders")
                    .font(.headline.weight(.semibold))

                Text("Sign in to sync reminders across all your devices")
                    .font(.subheadline)
                    .foregroundStyle(MemossColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(MemossColors.error)
                    .multilineTextAlignment(.center)
            }

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email]
            } onCompletion: { _ in
                // Handled by AuthService.shared
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                    ProgressView()
                }
            }
            .onTapGesture {
                Task { await signInWithApple() }
            }
        }
        .padding()
        .background(MemossColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: MemossColors.brandPrimary.opacity(0.08), radius: 12, y: 4)
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("About")

            VStack(spacing: 0) {
                aboutRow(title: "Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                Divider().padding(.leading)
                aboutRow(title: "Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
            }
            .background(MemossColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: MemossColors.brandPrimary.opacity(0.08), radius: 12, y: 4)

            // Mascot branding
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Image("mascot-trophy")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                    Text("Made with love")
                        .font(.caption)
                        .foregroundStyle(MemossColors.textSecondary)
                }
                Spacer()
            }
            .padding(.top, 16)
        }
    }

    private func aboutRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(MemossColors.textPrimary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(MemossColors.textSecondary)
        }
        .padding()
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MemossColors.textSecondary)
            .textCase(.uppercase)
    }

    // MARK: - Actions

    private func signInWithApple() async {
        isLoading = true
        errorMessage = nil

        do {
            try await authService.signInWithApple()
            // Run sync detached to not block UI
            Task.detached(priority: .utility) { [modelContext] in
                await SyncService.shared.syncAll(modelContext: modelContext)
            }
        } catch AuthError.cancelled {
            // User cancelled, no error
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func sync() async {
        // Run sync detached to not block UI
        Task.detached(priority: .utility) { [modelContext] in
            await SyncService.shared.syncAll(modelContext: modelContext)
        }
    }

    private func signOut() async {
        await authService.signOut()
    }

    private func deleteAccount() async {
        do {
            try await authService.deleteAccount()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func linkGoogle() async {
        isLinkingGoogle = true
        errorMessage = nil

        do {
            try await authService.linkGoogle()
        } catch AuthError.cancelled {
            // User cancelled, no error
        } catch {
            errorMessage = error.localizedDescription
        }

        isLinkingGoogle = false
    }

    private func confirmUnlink(_ provider: String) async {
        pendingUnlinkProvider = nil
        unlinkingProvider = provider
        errorMessage = nil

        do {
            try await authService.unlinkProvider(provider)
        } catch {
            errorMessage = error.localizedDescription
        }

        unlinkingProvider = nil
    }
}

// MARK: - Google Icon

private struct GoogleIcon: View {
    var size: CGFloat = 18

    var body: some View {
        Image("google-icon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Reminder.self, inMemory: true)
}
