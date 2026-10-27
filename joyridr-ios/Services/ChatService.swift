import Foundation

struct ChatService {
    var api: APIClient = .shared

    /// Total unread messages, for the badge on the chat button.
    func unreadCount() async throws -> Int {
        let unread: UnreadCount = try await api.get("/api/conversations/unread-count")
        return unread.count
    }
}
