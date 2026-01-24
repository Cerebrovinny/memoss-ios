//
//  AuthService.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 23/01/2026.
//

import AuthenticationServices
import Combine
import Foundation
import GoogleSignIn
import UIKit

// MARK: - Auth Service

@MainActor
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var userEmail: String?
    @Published private(set) var authProvider: AuthProvider?
    @Published private(set) var linkedProviders: [String] = []

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

        let response = try await sendAppleToken(identityToken)
        await apiClient.setTokens(access: response.accessToken, refresh: response.refreshToken)

        self.userEmail = credential.email
        self.authProvider = .apple
        self.linkedProviders = response.linkedProviders
        self.isAuthenticated = true

        UserDefaults.standard.set(credential.email, forKey: "userEmail")
        UserDefaults.standard.set(AuthProvider.apple.rawValue, forKey: "authProvider")
        saveLinkedProviders(response.linkedProviders)
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

    private func sendAppleToken(_ token: String) async throws -> AuthResponse {
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

    // MARK: - Link Google Account

    func linkGoogle() async throws {
        let idToken = try await performGoogleSignIn()
        try await linkProvider("google", idToken: idToken)
    }

    private func performGoogleSignIn() async throws -> String {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = scene.windows.first?.rootViewController else {
            throw AuthError.invalidCredential
        }

        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
                if let error = error {
                    if (error as NSError).code == GIDSignInError.canceled.rawValue {
                        continuation.resume(throwing: AuthError.cancelled)
                    } else {
                        continuation.resume(throwing: AuthError.failed(error))
                    }
                    return
                }

                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    continuation.resume(throwing: AuthError.invalidCredential)
                    return
                }

                continuation.resume(returning: idToken)
            }
        }
    }

    private func linkProvider(_ provider: String, idToken: String) async throws {
        struct LinkRequest: Encodable {
            let idToken: String

            enum CodingKeys: String, CodingKey {
                case idToken = "id_token"
            }
        }

        let endpoint = Endpoint(
            path: "/v1/auth/link/\(provider)",
            method: .POST,
            body: LinkRequest(idToken: idToken),
            requiresAuth: true
        )

        let response: LinkResponse = try await apiClient.request(endpoint)
        self.linkedProviders = response.linkedProviders
        saveLinkedProviders(response.linkedProviders)
    }

    // MARK: - Unlink Provider

    func unlinkProvider(_ provider: String) async throws {
        guard linkedProviders.count > 1 else {
            throw AuthError.cannotUnlinkOnlyProvider
        }

        let endpoint = Endpoint(
            path: "/v1/auth/link/\(provider)",
            method: .DELETE,
            requiresAuth: true
        )

        let response: LinkResponse = try await apiClient.request(endpoint)
        self.linkedProviders = response.linkedProviders
        saveLinkedProviders(response.linkedProviders)
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

        GIDSignIn.sharedInstance.signOut()

        await apiClient.clearTokens()
        self.isAuthenticated = false
        self.userEmail = nil
        self.authProvider = nil
        self.linkedProviders = []

        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "authProvider")
        UserDefaults.standard.removeObject(forKey: "linkedProviders")
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        try await apiClient.requestVoid(Endpoint(
            path: "/v1/auth/account",
            method: .DELETE,
            requiresAuth: true
        ))

        GIDSignIn.sharedInstance.signOut()

        await apiClient.clearTokens()
        self.isAuthenticated = false
        self.userEmail = nil
        self.authProvider = nil
        self.linkedProviders = []

        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "authProvider")
        UserDefaults.standard.removeObject(forKey: "linkedProviders")
    }

    // MARK: - Restore Session

    func restoreSession() {
        if apiClient.isAuthenticated {
            self.isAuthenticated = true
            self.userEmail = UserDefaults.standard.string(forKey: "userEmail")
            if let providerString = UserDefaults.standard.string(forKey: "authProvider") {
                self.authProvider = AuthProvider(rawValue: providerString)
            }
            if let providers = UserDefaults.standard.stringArray(forKey: "linkedProviders") {
                self.linkedProviders = providers
            }
        }
    }

    // MARK: - Private Helpers

    private func saveLinkedProviders(_ providers: [String]) {
        UserDefaults.standard.set(providers, forKey: "linkedProviders")
    }
}

// MARK: - Auth Error

enum AuthError: LocalizedError {
    case invalidCredential
    case cancelled
    case failed(Error)
    case cannotUnlinkOnlyProvider
    case providerConflict

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid credentials received"
        case .cancelled:
            return "Sign in was cancelled"
        case .failed(let error):
            return error.localizedDescription
        case .cannotUnlinkOnlyProvider:
            return "Cannot unlink your only authentication method"
        case .providerConflict:
            return "This account is already in use"
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

// MARK: - Response Types

private nonisolated(unsafe) struct AuthResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let linkedProviders: [String]

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case linkedProviders = "linked_providers"
    }
}

private nonisolated(unsafe) struct LinkResponse: Decodable, Sendable {
    let linkedProviders: [String]
    let message: String

    enum CodingKeys: String, CodingKey {
        case linkedProviders = "linked_providers"
        case message
    }
}

private nonisolated(unsafe) struct LogoutRequest: Encodable, Sendable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}
