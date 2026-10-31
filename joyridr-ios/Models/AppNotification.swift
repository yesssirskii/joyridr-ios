import Foundation

/// What a notification is about. Matches the backend's NotificationType.
nonisolated enum NotificationKind: String, Hashable {
    case rideRequested, rideConfirmed, rideDeclined, rideCancelled, rideExpired, rideStarted, rideCompleted
    case meetingPointUpdated, carApproved, carRejected, newReview
    /// A type this version of the app doesn't know yet, so one new type can't break the whole list.
    case unknown
}

extension NotificationKind: Decodable {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = NotificationKind(rawValue: raw) ?? .unknown
    }
}

/// One entry in the notifications inbox, from `GET /api/notifications`.
/// Named AppNotification so it doesn't clash with Foundation's Notification.
nonisolated struct AppNotification: Decodable, Hashable, Identifiable {
    let id: UUID
    let type: NotificationKind
    let title: String
    let body: String
    let rideId: UUID?
    let carId: UUID?
    let createdAt: Date
    var isRead: Bool
}
