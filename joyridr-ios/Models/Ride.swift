import Foundation

nonisolated enum RideStatus: String, Codable, Hashable {
    case awaitingPayment, requested, confirmed, inProgress, completed, declined, cancelled, expired
}

nonisolated enum MeetingPointType: String, Codable, Hashable, CaseIterable {
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

nonisolated enum PaymentStatus: String, Codable, Hashable {
    case pending, authorized, captured, voided, refunded, partiallyRefunded, failed
}

nonisolated struct RidePayment: Codable, Hashable {
    let status: PaymentStatus
    let amount: Decimal
    let refundedAmount: Decimal
    let currency: String
}

/// A booking, as returned by `GET /api/rides` and `GET /api/rides/{id}`.
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
    let createdAt: Date
    let confirmedAt: Date?
    let declineReason: String?
    let cancelledAt: Date?
    /// True if the logged-in user cancelled it, false if the other person did, nil if not cancelled.
    let cancelledByMe: Bool?
    let cancellationReason: String?
    let completedAt: Date?
    let payment: RidePayment?
    /// Completed and not reviewed by the logged-in user yet.
    let canReview: Bool
}

nonisolated struct UnreadCount: Decodable {
    let count: Int
}
