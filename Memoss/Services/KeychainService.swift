//
//  KeychainService.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 23/01/2026.
//

import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()

    private let serviceName = "com.stack4nerds.memoss"
    private let refreshTokenKey = "refresh_token"

    private init() {}

    // MARK: - Refresh Token

    func getRefreshToken() -> String? {
        return getString(forKey: refreshTokenKey)
    }

    func setRefreshToken(_ token: String) {
        setString(token, forKey: refreshTokenKey)
    }

    func deleteRefreshToken() {
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
