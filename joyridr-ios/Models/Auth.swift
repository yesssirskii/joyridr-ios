import Foundation

nonisolated struct LoginRequest: Encodable {
    let email: String
    let password: String
}

nonisolated struct ForgotPasswordRequest: Encodable {
    let email: String
}

nonisolated struct ResetPasswordRequest: Encodable {
    let email: String
    let code: String
    let newPassword: String
}

nonisolated struct RegisterRequest: Encodable {
    let email: String
    let username: String
    let password: String
    let firstName: String
    let lastName: String
    let phoneNumber: String?
    let role: UserRole
}

nonisolated struct RefreshRequest: Encodable {
    let refreshToken: String
}

nonisolated struct AuthResponse: Decodable {
    let accessToken: String
    let accessTokenExpiresAt: Date
    let refreshToken: String
    let refreshTokenExpiresAt: Date
    let user: User
}
