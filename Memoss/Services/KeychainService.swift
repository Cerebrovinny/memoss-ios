//
//  KeychainService.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 23/01/2026.
//

import Foundation
import Security

nonisolated final class KeychainService: Sendable {
    nonisolated static let shared = KeychainService()

    private let serviceName = "com.stack4nerds.memoss"
    private let refreshTokenKey = "refresh_token"

    private nonisolated init() {}

    // MARK: - Async Operations

    func getRefreshTokenAsync() async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.getRefreshTokenSync()
                continuation.resume(returning: result)
            }
        }
    }

    func setRefreshTokenAsync(_ token: String) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                self.setRefreshTokenSync(token)
                continuation.resume()
            }
        }
    }

    func deleteRefreshTokenAsync() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                self.deleteRefreshTokenSync()
                continuation.resume()
            }
        }
    }

    // MARK: - Sync Operations

    func getRefreshTokenSync() -> String? {
        return getString(forKey: refreshTokenKey)
    }

    func setRefreshTokenSync(_ token: String) {
        setString(token, forKey: refreshTokenKey)
    }

    func deleteRefreshTokenSync() {
        deleteValue(forKey: refreshTokenKey)
    }

    // MARK: - Private

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
