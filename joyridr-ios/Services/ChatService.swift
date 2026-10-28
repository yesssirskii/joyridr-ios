import Foundation

/// Rider–driver chat. The app polls `messages(after:)` while a conversation is open.
struct ChatService {
    var api: APIClient = .shared

    /// Total unread messages, for the badge on the chat button.
    func unreadCount() async throws -> Int {
        let unread: UnreadCount = try await api.get("/api/conversations/unread-count")
        return unread.count
    }

    /// The inbox, most recent first.
    func conversations() async throws -> [Conversation] {
        try await api.get("/api/conversations")
    }

    /// Opens the conversation with another user, creating it the first time.
    func start(with otherUserID: UUID) async throws -> Conversation {
        try await api.post("/api/conversations", body: StartConversationRequest(otherUserId: otherUserID))
    }

    /// Messages oldest first. `after`: only newer than that message (polling).
    /// `before`: the page before that message (loading history). Neither: the latest page.
    func messages(in conversationID: UUID, after: UUID? = nil, before: UUID? = nil, limit: Int = 50) async throws -> [ChatMessage] {
        var query = ["limit": String(limit)]
        if let after { query["afterMessageId"] = after.uuidString }
        if let before { query["beforeMessageId"] = before.uuidString }
        return try await api.get("/api/conversations/\(conversationID.uuidString)/messages", query: query)
    }

    func send(_ body: String, in conversationID: UUID) async throws -> ChatMessage {
        try await api.post("/api/conversations/\(conversationID.uuidString)/messages", body: SendMessageRequest(body: body))
    }

    func markRead(_ conversationID: UUID) async throws {
        try await api.post("/api/conversations/\(conversationID.uuidString)/read")
    }
}
