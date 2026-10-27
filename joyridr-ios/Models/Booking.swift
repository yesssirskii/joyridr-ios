import Foundation

nonisolated struct TimeSlot: Codable, Hashable, Identifiable {
    let startsAt: Date
    let endsAt: Date

    var id: Date { startsAt }
}

/// `GET /api/cars/{id}/slots`: bookable start times on one day, plus the price for that duration.
nonisolated struct SlotsResponse: Codable {
    let carId: UUID
    let date: String
    let timeZoneId: String
    let durationMinutes: Int
    let price: Decimal
    let currency: String
    let slots: [TimeSlot]
}

/// Body of `POST /api/rides`. Optional fields that are nil are left out of the JSON.
nonisolated struct CreateRideRequest: Encodable {
    let carId: UUID
    let startsAt: Date
    let durationMinutes: Int
    let meetingPointType: MeetingPointType
    let meetingLatitude: Double?
    let meetingLongitude: Double?
    let meetingAddress: String?
    let note: String?
}
