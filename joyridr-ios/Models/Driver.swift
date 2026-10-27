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
