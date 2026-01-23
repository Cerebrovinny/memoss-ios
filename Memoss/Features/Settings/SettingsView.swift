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
    @State private var isLoading = false
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
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(MemossColors.success)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Signed In")
                        .font(.headline.weight(.semibold))

                    if let email = authService.userEmail {
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

            Divider()

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

            Divider()

            Button {
                showSignOutAlert = true
            } label: {
                Text("Sign Out")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MemossColors.warning)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }

            Button {
                showDeleteAccountAlert = true
            } label: {
                Text("Delete Account")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MemossColors.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .padding()
        .background(MemossColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: MemossColors.brandPrimary.opacity(0.08), radius: 12, y: 4)
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
        }
    }

    private func aboutRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
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
}

#Preview {
    SettingsView()
        .modelContainer(for: Reminder.self, inMemory: true)
}
