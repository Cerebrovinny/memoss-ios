//
//  APIClient.swift
//  Memoss
//
//  Created by Vinicius Cardoso on 23/01/2026.
//

import Combine
import Foundation

// MARK: - API Configuration

enum APIEnvironment {
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

enum APIError: LocalizedError {
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

struct APIErrorResponse: Decodable {
    let error: APIErrorDetail
}

struct APIErrorDetail: Decodable {
    let code: String
    let message: String
    let field: String?
}

struct TokenResponse: Decodable {
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

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let body: Data?
    let requiresAuth: Bool

    enum HTTPMethod: String {
        case GET, POST, PUT, DELETE
    }

    init(path: String, method: HTTPMethod = .GET, body: Encodable? = nil, requiresAuth: Bool = true) {
        self.path = path
        self.method = method
        self.requiresAuth = requiresAuth

        if let body = body {
            self.body = try? JSONEncoder().encode(body)
        } else {
            self.body = nil
        }
    }
}

// MARK: - API Client

@MainActor
final class APIClient: ObservableObject {
    static let shared = APIClient()

    private let environment: APIEnvironment
    private let keychainService: KeychainService
    private var accessToken: String?
    private var isRefreshing = false

    @Published var isAuthenticated = false

    init(environment: APIEnvironment = .production, keychainService: KeychainService = .shared) {
        self.environment = environment
        self.keychainService = keychainService

        if keychainService.getRefreshToken() != nil {
            self.isAuthenticated = true
        }
    }

    // MARK: - Token Management

    func setTokens(access: String, refresh: String) {
        self.accessToken = access
        keychainService.setRefreshToken(refresh)
        isAuthenticated = true
    }

    func clearTokens() {
        self.accessToken = nil
        keychainService.deleteRefreshToken()
        isAuthenticated = false
    }

    // MARK: - Request

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        var urlRequest = makeRequest(endpoint)

        if endpoint.requiresAuth {
            if let token = accessToken {
                urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        let (data, response) = try await performRequest(urlRequest)
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

    func requestVoid(_ endpoint: Endpoint) async throws {
        var urlRequest = makeRequest(endpoint)

        if endpoint.requiresAuth {
            if let token = accessToken {
                urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        let (data, response) = try await performRequest(urlRequest)
        let httpResponse = response as? HTTPURLResponse

        if httpResponse?.statusCode == 401, endpoint.requiresAuth, !isRefreshing {
            try await handleUnauthorizedVoid(endpoint: endpoint)
            return
        }

        try handleErrorResponse(data: data, statusCode: httpResponse?.statusCode ?? 0)
    }

    // MARK: - Private Helpers

    private func makeRequest(_ endpoint: Endpoint) -> URLRequest {
        let url = environment.baseURL.appendingPathComponent(endpoint.path)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = endpoint.body {
            request.httpBody = body
        }

        return request
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func handleErrorResponse(data: Data, statusCode: Int) throws {
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

    private func handleUnauthorized<T: Decodable>(endpoint: Endpoint) async throws -> T {
        isRefreshing = true
        defer { isRefreshing = false }

        guard let refreshToken = keychainService.getRefreshToken() else {
            clearTokens()
            throw APIError.unauthorized
        }

        do {
            let tokens = try await refreshTokens(refreshToken)
            setTokens(access: tokens.accessToken, refresh: tokens.refreshToken)
            return try await request(endpoint)
        } catch {
            clearTokens()
            throw APIError.unauthorized
        }
    }

    private func handleUnauthorizedVoid(endpoint: Endpoint) async throws {
        isRefreshing = true
        defer { isRefreshing = false }

        guard let refreshToken = keychainService.getRefreshToken() else {
            clearTokens()
            throw APIError.unauthorized
        }

        do {
            let tokens = try await refreshTokens(refreshToken)
            setTokens(access: tokens.accessToken, refresh: tokens.refreshToken)
            try await requestVoid(endpoint)
        } catch {
            clearTokens()
            throw APIError.unauthorized
        }
    }

    private func refreshTokens(_ refreshToken: String) async throws -> TokenResponse {
        struct RefreshRequest: Encodable {
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

        return try await request(endpoint)
    }
}
