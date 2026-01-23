//
//  AuthService.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 23/01/2026.
//

import AuthenticationServices
import Combine
import Foundation
import UIKit

// MARK: - Auth Service

@MainActor
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var userEmail: String?
    @Published private(set) var authProvider: AuthProvider?

    private let apiClient: APIClient

    enum AuthProvider: String, Codable {
        case apple
        case google
    }

    override init() {
        self.apiClient = APIClient.shared
        super.init()
        self.isAuthenticated = apiClient.isAuthenticated
    }

    // MARK: - Sign In with Apple

    func signInWithApple() async throws {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email]

        let result = try await performAppleSignIn(request: request)

        guard let credential = result.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }

        let tokens = try await sendAppleToken(identityToken)
        await apiClient.setTokens(access: tokens.accessToken, refresh: tokens.refreshToken)

        self.userEmail = credential.email
        self.authProvider = .apple
        self.isAuthenticated = true

        UserDefaults.standard.set(credential.email, forKey: "userEmail")
        UserDefaults.standard.set(AuthProvider.apple.rawValue, forKey: "authProvider")
    }

    private func performAppleSignIn(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: continuation)
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            objc_setAssociatedObject(controller, "delegateKey", delegate, .OBJC_ASSOCIATION_RETAIN)
            controller.performRequests()
        }
    }

    private func sendAppleToken(_ token: String) async throws -> TokenResponse {
        struct SignInRequest: Encodable {
            let idToken: String

            enum CodingKeys: String, CodingKey {
                case idToken = "id_token"
            }
        }

        let endpoint = Endpoint(
            path: "/v1/auth/apple",
            method: .POST,
            body: SignInRequest(idToken: token),
            requiresAuth: false
        )

        return try await apiClient.request(endpoint)
    }

    // MARK: - Sign Out

    func signOut() async {
        let refreshToken = await KeychainService.shared.getRefreshTokenAsync() ?? ""

        do {
            try await apiClient.requestVoid(Endpoint(
                path: "/v1/auth/logout",
                method: .POST,
                body: LogoutRequest(refreshToken: refreshToken),
                requiresAuth: true
            ))
        } catch {
        }

        await apiClient.clearTokens()
        self.isAuthenticated = false
        self.userEmail = nil
        self.authProvider = nil

        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "authProvider")
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        try await apiClient.requestVoid(Endpoint(
            path: "/v1/auth/account",
            method: .DELETE,
            requiresAuth: true
        ))

        await apiClient.clearTokens()
        self.isAuthenticated = false
        self.userEmail = nil
        self.authProvider = nil

        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "authProvider")
    }

    // MARK: - Restore Session

    func restoreSession() {
        if apiClient.isAuthenticated {
            self.isAuthenticated = true
            self.userEmail = UserDefaults.standard.string(forKey: "userEmail")
            if let providerString = UserDefaults.standard.string(forKey: "authProvider") {
                self.authProvider = AuthProvider(rawValue: providerString)
            }
        }
    }
}

// MARK: - Auth Error

enum AuthError: LocalizedError {
    case invalidCredential
    case cancelled
    case failed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid credentials received"
        case .cancelled:
            return "Sign in was cancelled"
        case .failed(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Apple Sign In Delegate

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let continuation: CheckedContinuation<ASAuthorization, Error>

    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation.resume(throwing: AuthError.cancelled)
        } else {
            continuation.resume(throwing: AuthError.failed(error))
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                return UIWindow(windowScene: windowScene)
            }
            fatalError("No window scene available for Apple Sign In presentation")
        }
        return window
    }
}

// MARK: - Request Types

private struct LogoutRequest: Encodable, Sendable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}
