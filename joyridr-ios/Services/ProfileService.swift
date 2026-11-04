import Foundation

/// The logged-in user's own account: name, username and profile picture.
struct ProfileService {
    var api: APIClient = .shared

    /// Fails with "username_taken" or "invalid_username".
    func update(_ request: UpdateMeRequest) async throws -> Me {
        try await api.put("/api/me", body: request)
    }

    /// Replaces the profile picture (the old one is deleted on the server).
    func uploadAvatar(jpeg: Data) async throws -> User {
        try await api.upload("/api/me/avatar", data: jpeg, fileName: "avatar.jpg", mimeType: "image/jpeg")
    }
}
