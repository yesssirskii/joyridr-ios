import Foundation

nonisolated struct Review: Codable, Hashable, Identifiable {
    let id: UUID
    let rating: Int
    let comment: String?
    let authorName: String
    let authorAvatarUrl: String?
    let createdAt: Date
}

/// `GET /api/drivers/{id}`: what a rider can see about a driver.
nonisolated struct PublicDriverProfile: Codable, Hashable {
    let driver: DriverSummary
    let bio: String?
    let completedRides: Int
    let memberSince: Date
    let cars: [CarSummary]
    let recentReviews: [Review]
}

/// `GET /api/drivers/{id}/schedule`. Days are "monday"…"sunday", times "HH:mm:ss" in `timeZoneId`.
nonisolated struct WeeklySchedule: Codable, Hashable {
    nonisolated struct Window: Codable, Hashable {
        let dayOfWeek: String
        let startTime: String
        let endTime: String
    }

    let timeZoneId: String
    let windows: [Window]
}

/// Body of `PUT /api/drivers/me/schedule`: the whole week, replacing what was there.
nonisolated struct UpdateWeeklyScheduleRequest: Encodable {
    let windows: [WeeklySchedule.Window]
}

/// A one-off block (holiday, car in service…) when riders can't book the driver.
nonisolated struct TimeOff: Codable, Hashable, Identifiable {
    let id: UUID
    let startsAt: Date
    let endsAt: Date
    let reason: String?
}

nonisolated struct CreateTimeOffRequest: Encodable {
    let startsAt: Date
    let endsAt: Date
    let reason: String?
}

/// Body of `PUT /api/drivers/me`. The endpoint replaces every field, so send the current values for the ones you don't change.
nonisolated struct UpdateDriverProfileRequest: Encodable {
    let bio: String?
    let city: String?
    let baseLatitude: Double?
    let baseLongitude: Double?
    let baseAddress: String?
    let serviceRadiusKm: Int
    let timeZoneId: String
    let isAcceptingRides: Bool

    /// Copies the profile with only "accepting rides" changed.
    init(_ profile: DriverProfile, isAcceptingRides: Bool) {
        bio = profile.bio
        city = profile.city
        baseLatitude = profile.baseLatitude
        baseLongitude = profile.baseLongitude
        baseAddress = profile.baseAddress
        serviceRadiusKm = profile.serviceRadiusKm
        timeZoneId = profile.timeZoneId
        self.isAcceptingRides = isAcceptingRides
    }
}
