import Foundation

/// The logged-in user's own account: name, username and profile picture.
struct ProfileService {
    var api: APIClient = .shared

    /// Fails with "username_taken" or "invalid_username".
    func update(_ request: UpdateMeRequest) async throws -> Me {
        try await api.put("/api/me", body: request)
    }

    /// Deletes the account for good. Fails with "wrong_password" or "ride_in_progress".
    func deleteAccount(password: String) async throws {
        try await api.post("/api/me/delete", body: DeleteAccountRequest(password: password))
    }

    /// Replaces the profile picture (the old one is deleted on the server).
    func uploadAvatar(jpeg: Data) async throws -> User {
        try await api.upload("/api/me/avatar", data: jpeg, fileName: "avatar.jpg", mimeType: "image/jpeg")
    }
}
