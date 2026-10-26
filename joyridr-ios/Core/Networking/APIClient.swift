import Foundation

/// Talks to the JOYRIDR backend: builds requests, adds the access token, decodes JSON,
/// turns error responses into `APIError`, and refreshes the access token when it expires.
final class APIClient {
    static let shared = APIClient()

    /// Called when the refresh token is no longer valid, so the app can show the login screen.
    var onSessionExpired: (() -> Void)?

    private let baseURL: URL
    private let tokens: TokenStore
    private let session: URLSession
    /// Only one refresh at a time: if several requests get a 401 together, they all wait for the same refresh.
    private var refreshTask: Task<Void, Error>?

    init(baseURL: URL = AppConfig.apiBaseURL, tokens: TokenStore = .shared, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.tokens = tokens
        self.session = session
    }

    // MARK: Public API

    func get<Response: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> Response {
        try await send("GET", path, query: query, body: nil)
    }

    func post<Response: Decodable>(_ path: String, body: (any Encodable)? = nil, authorized: Bool = true) async throws -> Response {
        try await send("POST", path, body: body, authorized: authorized)
    }

    /// Quick request to `/health`. On a real iPhone the first request to your Mac triggers the
    /// "Allow Local Network access?" prompt, so we do it on launch instead of during login.
    func ping() async {
        var request = URLRequest(url: baseURL.appending(path: "/health"))
        request.timeoutInterval = 5
        _ = try? await session.data(for: request)
    }

    /// For endpoints that return 204 No Content.
    func post(_ path: String, body: (any Encodable)? = nil, authorized: Bool = true) async throws {
        let _: EmptyResponse = try await send("POST", path, body: body, authorized: authorized)
    }

    // MARK: Internals

    private func send<Response: Decodable>(
        _ method: String,
        _ path: String,
        query: [String: String] = [:],
        body: (any Encodable)?,
        authorized: Bool = true,
        isRetry: Bool = false
    ) async throws -> Response {
        if authorized, let stored = tokens.current, stored.accessTokenExpiresAt < .now.addingTimeInterval(30) {
            try await refreshTokens()   // refresh a bit early instead of waiting for a 401
        }

        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder.api.encode(body)
        }
        if authorized, let accessToken = tokens.current?.accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code != .cancelled {
            throw APIError.cannotConnect
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        if http.statusCode == 401 && authorized && !isRetry {
            try await refreshTokens()
            return try await send(method, path, query: query, body: body, authorized: authorized, isRetry: true)
        }

        guard (200..<300).contains(http.statusCode) else {
            let problem = try? JSONDecoder.api.decode(ProblemDetails.self, from: data)
            throw APIError.server(
                status: http.statusCode,
                message: problem?.title ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode),
                code: problem?.code,
                fieldErrors: problem?.errors ?? [:])
        }

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }
        do {
            return try JSONDecoder.api.decode(Response.self, from: data)
        } catch {
            print("⚠️ Couldn't decode \(Response.self) from \(path): \(error)")
            throw APIError.invalidResponse
        }
    }

    private func refreshTokens() async throws {
        if let refreshTask {
            return try await refreshTask.value
        }
        let task = Task {
            defer { refreshTask = nil }
            guard let refreshToken = tokens.current?.refreshToken else { throw APIError.sessionExpired }
            do {
                let response: AuthResponse = try await send(
                    "POST", "/api/auth/refresh", body: RefreshRequest(refreshToken: refreshToken), authorized: false)
                tokens.save(response)
            } catch let error as APIError where error.isAuthFailure {
                tokens.clear()
                onSessionExpired?()
                throw APIError.sessionExpired
            }
        }
        refreshTask = task
        try await task.value
    }
}

nonisolated struct EmptyResponse: Decodable {}

private extension APIError {
    /// The refresh token was rejected (as opposed to e.g. no network, where we shouldn't log out).
    var isAuthFailure: Bool {
        if case let .server(status, _, _, _) = self { return status == 401 || status == 400 }
        return false
    }
}
