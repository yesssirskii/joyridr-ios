import Foundation

/// Mirrors the backend's DTOs. Property names match the JSON keys, so no CodingKeys are needed.
nonisolated enum UserRole: String, Codable, Hashable {
    case joyRider, joyDriver, admin

    var title: String {
        switch self {
        case .joyRider: "JoyRider"
        case .joyDriver: "JoyDriver"
        case .admin: "Admin"
        }
    }
}

nonisolated struct User: Codable, Hashable, Identifiable {
    let id: UUID
    let email: String
    /// Always lower-case, shown as "@ivan.kovac".
    let username: String
    let firstName: String
    let lastName: String
    let phoneNumber: String?
    let avatarUrl: String?
    let role: UserRole
    let createdAt: Date

    var fullName: String { "\(firstName) \(lastName)" }
}

/// The backend's username rules, so the app can say what's wrong before sending.
nonisolated enum Username {
    static let rules = "3–20 characters: letters, numbers, dots and underscores."

    /// "@Ivan.Kovac " -> "ivan.kovac", the form the backend stores.
    static func normalize(_ text: String) -> String {
        var username = text.trimmingCharacters(in: .whitespaces).lowercased()
        if username.hasPrefix("@") { username.removeFirst() }
        return username
    }

    static func isValid(_ username: String) -> Bool {
        username.wholeMatch(of: /[a-z0-9._]{3,20}/) != nil
    }
}

/// Body of `PUT /api/me`. The endpoint replaces every field, so send the current values for the ones you don't change.
nonisolated struct UpdateMeRequest: Encodable {
    let username: String
    let firstName: String
    let lastName: String
    let phoneNumber: String?

    /// Copies the user, changing only what's passed.
    init(_ user: User, username: String? = nil) {
        self.username = username ?? user.username
        firstName = user.firstName
        lastName = user.lastName
        phoneNumber = user.phoneNumber
    }
}

nonisolated struct RiderProfile: Codable, Hashable {
    let dateOfBirth: String?
    let ratingAverage: Double
    let ratingCount: Int
    let completedRides: Int
}

nonisolated struct DriverProfile: Codable, Hashable {
    let bio: String?
    let city: String?
    let baseLatitude: Double?
    let baseLongitude: Double?
    let baseAddress: String?
    let serviceRadiusKm: Int
    let timeZoneId: String
    let isAcceptingRides: Bool
    let isVerified: Bool
    let ratingAverage: Double
    let ratingCount: Int
    let completedRides: Int
}

/// `GET /api/me`: the logged-in user plus the profile for their role.
nonisolated struct Me: Codable, Hashable {
    let user: User
    let riderProfile: RiderProfile?
    let driverProfile: DriverProfile?
}
