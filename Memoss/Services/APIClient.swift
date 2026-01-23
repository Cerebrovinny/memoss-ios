//
//  APIClient.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 23/01/2026.
//

import Combine
import Foundation

// MARK: - API Configuration

nonisolated enum APIEnvironment: Sendable {
    case development
    case production

    var baseURL: URL {
        switch self {
        case .development:
            return URL(string: "http://localhost:8080")!
        case .production:
            return URL(string: "https://memoss-backend.fly.dev")!
        }
    }
}

// MARK: - API Error

nonisolated enum APIError: LocalizedError, Sendable {
    case unauthorized
    case forbidden
    case notFound
    case validationError(code: String, message: String, field: String?)
    case serverError(code: String, message: String)
    case networkError(Error)
    case decodingError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please sign in to continue"
        case .forbidden:
            return "You don't have permission to access this resource"
        case .notFound:
            return "Resource not found"
        case .validationError(_, let message, _):
            return message
        case .serverError(_, let message):
            return message
        case .networkError(let error):
            return error.localizedDescription
        case .decodingError:
            return "Failed to process server response"
        case .unknown:
            return "An unexpected error occurred"
        }
    }
}

// MARK: - API Response Types

nonisolated struct APIErrorResponse: Decodable, Sendable {
    let error: APIErrorDetail
}

nonisolated struct APIErrorDetail: Decodable, Sendable {
    let code: String
    let message: String
    let field: String?
}

nonisolated struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

// MARK: - Endpoint

nonisolated struct Endpoint: Sendable {
    let path: String
    let method: HTTPMethod
    let body: Data?
    let requiresAuth: Bool

    enum HTTPMethod: String, Sendable {
        case GET, POST, PUT, DELETE
    }

    init(path: String, method: HTTPMethod = .GET, body: (any Encodable & Sendable)? = nil, requiresAuth: Bool = true) {
        self.path = path
        self.method = method
        self.requiresAuth = requiresAuth

        if let body = body {
            self.body = try? JSONEncoder().encode(AnyEncodable(body))
        } else {
            self.body = nil
        }
    }
}

// Helper for encoding any Encodable
private nonisolated struct AnyEncodable: Encodable, @unchecked Sendable {
    private let encode: @Sendable (Encoder) throws -> Void

    nonisolated init(_ wrapped: any Encodable & Sendable) {
        self.encode = { encoder in
            try wrapped.encode(to: encoder)
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}

// MARK: - API Client

/// API Client with network operations running OFF the main thread
final class APIClient: ObservableObject, @unchecked Sendable {
    nonisolated static let shared = APIClient()

    private let environment: APIEnvironment
    private let keychainService: KeychainService
    private let lock = NSLock()

    private nonisolated(unsafe) var _accessToken: String?
    private nonisolated(unsafe) var _isRefreshing = false

    @MainActor @Published var isAuthenticated = false

    nonisolated init(environment: APIEnvironment = .production, keychainService: KeychainService = .shared) {
        self.environment = environment
        self.keychainService = keychainService
    }

    /// Call this on app launch to restore auth state (async to avoid blocking main thread)
    @MainActor
    func restoreAuthState() async {
        let hasToken = await keychainService.getRefreshTokenAsync() != nil
        self.isAuthenticated = hasToken
    }

    // MARK: - Token Management (Main Actor for UI state)

    @MainActor
    func setTokens(access: String, refresh: String) async {
        lock.withLock { self._accessToken = access }
        await keychainService.setRefreshTokenAsync(refresh)
        isAuthenticated = true
    }

    @MainActor
    func clearTokens() async {
        lock.withLock { self._accessToken = nil }
        await keychainService.deleteRefreshTokenAsync()
        isAuthenticated = false
    }

    private nonisolated var accessToken: String? {
        lock.lock()
        defer { lock.unlock() }
        return _accessToken
    }

    private nonisolated var isRefreshing: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isRefreshing
        }
        set {
            lock.lock()
            _isRefreshing = newValue
            lock.unlock()
        }
    }

    // MARK: - Request (runs on background thread)

    /// Perform a network request - runs on a background thread, never blocks main
    nonisolated func request<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T {
        let urlRequest = makeRequest(endpoint)
        var mutableRequest = urlRequest

        if endpoint.requiresAuth {
            if let token = accessToken {
                mutableRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        let (data, response) = try await performRequest(mutableRequest)
        let httpResponse = response as? HTTPURLResponse

        if httpResponse?.statusCode == 401, endpoint.requiresAuth, !isRefreshing {
            return try await handleUnauthorized(endpoint: endpoint)
        }

        try handleErrorResponse(data: data, statusCode: httpResponse?.statusCode ?? 0)

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    nonisolated func requestVoid(_ endpoint: Endpoint) async throws {
        let urlRequest = makeRequest(endpoint)
        var mutableRequest = urlRequest

        if endpoint.requiresAuth {
            if let token = accessToken {
                mutableRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        let (data, response) = try await performRequest(mutableRequest)
        let httpResponse = response as? HTTPURLResponse

        if httpResponse?.statusCode == 401, endpoint.requiresAuth, !isRefreshing {
            try await handleUnauthorizedVoid(endpoint: endpoint)
            return
        }

        try handleErrorResponse(data: data, statusCode: httpResponse?.statusCode ?? 0)
    }

    // MARK: - Private Helpers

    private nonisolated func makeRequest(_ endpoint: Endpoint) -> URLRequest {
        let url = environment.baseURL.appendingPathComponent(endpoint.path)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10 // 10 second timeout

        if let body = endpoint.body {
            request.httpBody = body
        }

        return request
    }

    private nonisolated func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private nonisolated func handleErrorResponse(data: Data, statusCode: Int) throws {
        guard statusCode >= 400 else { return }

        if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            switch statusCode {
            case 400:
                throw APIError.validationError(
                    code: apiError.error.code,
                    message: apiError.error.message,
                    field: apiError.error.field
                )
            case 401:
                throw APIError.unauthorized
            case 403:
                throw APIError.forbidden
            case 404:
                throw APIError.notFound
            default:
                throw APIError.serverError(code: apiError.error.code, message: apiError.error.message)
            }
        }

        switch statusCode {
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        default:
            throw APIError.unknown
        }
    }

    private nonisolated func handleUnauthorized<T: Decodable & Sendable>(endpoint: Endpoint) async throws -> T {
        isRefreshing = true
        defer { isRefreshing = false }

        // Use sync keychain access since we're already on a background thread
        guard let refreshToken = keychainService.getRefreshTokenSync() else {
            await clearTokensAsync()
            throw APIError.unauthorized
        }

        do {
            let tokens = try await refreshTokensInternal(refreshToken)
            await setTokensAsync(access: tokens.accessToken, refresh: tokens.refreshToken)
            return try await request(endpoint)
        } catch {
            await clearTokensAsync()
            throw APIError.unauthorized
        }
    }

    private nonisolated func handleUnauthorizedVoid(endpoint: Endpoint) async throws {
        isRefreshing = true
        defer { isRefreshing = false }

        // Use sync keychain access since we're already on a background thread
        guard let refreshToken = keychainService.getRefreshTokenSync() else {
            await clearTokensAsync()
            throw APIError.unauthorized
        }

        do {
            let tokens = try await refreshTokensInternal(refreshToken)
            await setTokensAsync(access: tokens.accessToken, refresh: tokens.refreshToken)
            try await requestVoid(endpoint)
        } catch {
            await clearTokensAsync()
            throw APIError.unauthorized
        }
    }

    // Async wrappers for MainActor token management
    @MainActor
    private func setTokensAsync(access: String, refresh: String) async {
        lock.withLock { self._accessToken = access }
        await keychainService.setRefreshTokenAsync(refresh)
        isAuthenticated = true
    }

    @MainActor
    private func clearTokensAsync() async {
        lock.withLock { self._accessToken = nil }
        await keychainService.deleteRefreshTokenAsync()
        isAuthenticated = false
    }

    private nonisolated func refreshTokensInternal(_ refreshToken: String) async throws -> TokenResponse {
        struct RefreshRequest: Encodable, Sendable {
            let refreshToken: String

            enum CodingKeys: String, CodingKey {
                case refreshToken = "refresh_token"
            }
        }

        let endpoint = Endpoint(
            path: "/v1/auth/refresh",
            method: .POST,
            body: RefreshRequest(refreshToken: refreshToken),
            requiresAuth: false
        )

        // Direct network call without going through request() to avoid recursion issues
        let urlRequest = makeRequest(endpoint)
        let (data, response) = try await performRequest(urlRequest)
        let httpResponse = response as? HTTPURLResponse

        try handleErrorResponse(data: data, statusCode: httpResponse?.statusCode ?? 0)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TokenResponse.self, from: data)
    }
}
