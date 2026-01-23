//
//  KeychainService.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 23/01/2026.
//

import Foundation
import Security

/// Keychain service with async operations to avoid blocking main thread.
/// Keychain access can be slow on real devices due to Secure Enclave.
nonisolated final class KeychainService: Sendable {
    nonisolated static let shared = KeychainService()

    private let serviceName = "com.stack4nerds.memoss"
    private let refreshTokenKey = "refresh_token"

    private nonisolated init() {}

    // MARK: - Refresh Token (Async - use these from main thread)

    /// Async version - safe to call from MainActor
    func getRefreshTokenAsync() async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.getRefreshTokenSync()
                continuation.resume(returning: result)
            }
        }
    }

    /// Async version - safe to call from MainActor
    func setRefreshTokenAsync(_ token: String) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                self.setRefreshTokenSync(token)
                continuation.resume()
            }
        }
    }

    /// Async version - safe to call from MainActor
    func deleteRefreshTokenAsync() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                self.deleteRefreshTokenSync()
                continuation.resume()
            }
        }
    }

    // MARK: - Refresh Token (Sync - only call from background threads)

    /// Synchronous version - only call from background threads
    func getRefreshTokenSync() -> String? {
        return getString(forKey: refreshTokenKey)
    }

    /// Synchronous version - only call from background threads
    func setRefreshTokenSync(_ token: String) {
        setString(token, forKey: refreshTokenKey)
    }

    /// Synchronous version - only call from background threads
    func deleteRefreshTokenSync() {
        deleteValue(forKey: refreshTokenKey)
    }

    // MARK: - Generic Keychain Operations

    private func getString(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func setString(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        deleteValue(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteValue(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
