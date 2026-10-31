import Foundation

/// The notifications inbox: ride updates, car approvals and new reviews.
struct NotificationsService {
    var api: APIClient = .shared

    /// Newest first, a page at a time.
    func list(page: Int = 1, pageSize: Int = 30) async throws -> Page<AppNotification> {
        try await api.get("/api/notifications", query: ["page": String(page), "pageSize": String(pageSize)])
    }

    /// For the badge on the bell.
    func unreadCount() async throws -> Int {
        let unread: UnreadCount = try await api.get("/api/notifications/unread-count")
        return unread.count
    }

    func markRead(_ notificationID: AppNotification.ID) async throws {
        try await api.post("/api/notifications/\(notificationID.uuidString)/read")
    }

    func markAllRead() async throws {
        try await api.post("/api/notifications/read-all")
    }
}
