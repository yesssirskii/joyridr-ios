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
    let firstName: String
    let lastName: String
    let phoneNumber: String?
    let avatarUrl: String?
    let role: UserRole
    let createdAt: Date

    var fullName: String { "\(firstName) \(lastName)" }
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
