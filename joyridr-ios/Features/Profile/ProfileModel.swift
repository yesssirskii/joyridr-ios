import Foundation
import Observation
import PhotosUI
import SwiftUI

/// Changes the logged-in user's profile picture and username. Both return true when saved,
/// so the view can reload the session and show the new values everywhere.
@Observable
final class ProfileModel {
    private(set) var isUploadingAvatar = false
    private(set) var isSavingUsername = false
    private(set) var isDeletingAccount = false
    var errorMessage: String?

    private let profile: ProfileService

    init(profile: ProfileService = ProfileService()) {
        self.profile = profile
    }

    func uploadAvatar(_ item: PhotosPickerItem) async -> Bool {
        errorMessage = nil
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        // 1024 px is plenty for a picture shown at most a few hundred points wide.
        guard let data = try? await item.loadTransferable(type: Data.self),
              let (jpeg, _) = JPEGImage.prepare(data, maxSide: 1024) else {
            errorMessage = t("profile.error_photo")
            return false
        }
        do {
            _ = try await profile.uploadAvatar(jpeg: jpeg)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func changeUsername(to text: String, for user: User) async -> Bool {
        let username = Username.normalize(text)
        guard username != user.username else { return false }
        guard Username.isValid(username) else {
            errorMessage = t("auth.username_error", ["rules": Username.rules])
            return false
        }
        errorMessage = nil
        isSavingUsername = true
        defer { isSavingUsername = false }
        do {
            _ = try await profile.update(UpdateMeRequest(user, username: username))
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Returns true once the account is gone; the caller then shows a confirmation and signs out.
    func deleteAccount(password: String) async -> Bool {
        guard !password.isEmpty else {
            errorMessage = t("profile.error_delete_password")
            return false
        }
        errorMessage = nil
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await profile.deleteAccount(password: password)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
