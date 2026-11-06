import Foundation

/// The person on the other side of a conversation.
nonisolated struct ChatParticipant: Codable, Hashable, Identifiable {
    let id: UUID
    let displayName: String
    let avatarUrl: String?
    let isDriver: Bool

    var firstName: String { displayName.split(separator: " ").first.map(String.init) ?? displayName }
}

nonisolated struct ChatMessage: Codable, Hashable, Identifiable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    /// Sent by the logged-in user: draw the bubble on the right.
    let isMine: Bool
    let body: String
    let createdAt: Date
}

/// One row of the inbox (`GET /api/conversations`).
nonisolated struct Conversation: Codable, Hashable, Identifiable {
    let id: UUID
    let otherUser: ChatParticipant
    let lastMessage: ChatMessage?
    let unreadCount: Int
    let createdAt: Date
    /// False when either side blocked the other, or the other account was deleted or banned.
    let canMessage: Bool
    /// The logged-in user blocked the other person, so the chat can offer to unblock.
    let blockedByMe: Bool

    /// When the conversation last changed, for sorting and the time in the inbox.
    var lastActivity: Date { lastMessage?.createdAt ?? createdAt }
}

nonisolated struct StartConversationRequest: Encodable {
    let otherUserId: UUID
}

nonisolated struct SendMessageRequest: Encodable {
    let body: String
}
