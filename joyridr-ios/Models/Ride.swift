import Foundation

nonisolated enum RideStatus: String, Codable, Hashable {
    case awaitingPayment, requested, confirmed, inProgress, completed, declined, cancelled, expired
}

nonisolated enum MeetingPointType: String, Codable, Hashable {
    case driverComesToRider, riderComesToDriver, agreedLocation

    var title: String {
        switch self {
        case .driverComesToRider: "Pick up the rider"
        case .riderComesToDriver: "Rider comes to you"
        case .agreedLocation: "Agree on a spot"
        }
    }
}

nonisolated struct RideParticipant: Codable, Hashable, Identifiable {
    let id: UUID
    let displayName: String
    let avatarUrl: String?
    let ratingAverage: Double
    let ratingCount: Int
    let phoneNumber: String?
}

nonisolated struct MeetingPoint: Codable, Hashable {
    let type: MeetingPointType
    let latitude: Double?
    let longitude: Double?
    let address: String?
}

/// A booking. Only the fields the app uses so far; the backend sends more.
nonisolated struct Ride: Codable, Hashable, Identifiable {
    let id: UUID
    let status: RideStatus
    let startsAt: Date
    let endsAt: Date
    let durationMinutes: Int
    let car: CarSummary
    let rider: RideParticipant
    let driver: RideParticipant
    let meetingPoint: MeetingPoint
    let riderNote: String?
    let price: Decimal
    let currency: String
    let respondBy: Date?
}

nonisolated struct UnreadCount: Decodable {
    let count: Int
}
