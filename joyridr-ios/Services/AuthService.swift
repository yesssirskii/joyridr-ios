import Foundation

/// Every auth endpoint in one place. Screens and stores call these instead of building URLs themselves.
struct AuthService {
    var api: APIClient = .shared

    func login(email: String, password: String) async throws -> AuthResponse {
        try await api.post("/api/auth/login", body: LoginRequest(email: email, password: password), authorized: false)
    }

    func register(_ request: RegisterRequest) async throws -> AuthResponse {
        try await api.post("/api/auth/register", body: request, authorized: false)
    }

    /// Emails a 6-digit code. Succeeds whether or not the email has an account.
    func forgotPassword(email: String) async throws {
        try await api.post("/api/auth/forgot-password", body: ForgotPasswordRequest(email: email), authorized: false)
    }

    /// Fails with "invalid_code", "code_expired" or "too_many_attempts". Logs the user in on success.
    func resetPassword(_ request: ResetPasswordRequest) async throws -> AuthResponse {
        try await api.post("/api/auth/reset-password", body: request, authorized: false)
    }

    func logout(refreshToken: String) async {
        try? await api.post("/api/auth/logout", body: RefreshRequest(refreshToken: refreshToken), authorized: false)
    }

    func me() async throws -> Me {
        try await api.get("/api/me")
    }
}
