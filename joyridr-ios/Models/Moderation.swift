import Foundation

nonisolated enum ReportReason: String, Codable, CaseIterable, Identifiable {
    case spam, harassment, inappropriate, scam, other

    var id: Self { self }

    var title: String {
        switch self {
        case .spam: "Spam"
        case .harassment: "Harassment or bullying"
        case .inappropriate: "Inappropriate or offensive"
        case .scam: "Scam or paying outside the app"
        case .other: "Something else"
        }
    }
}

nonisolated enum ReportKind: String, Codable, Hashable {
    case user, message, review

    var title: String {
        switch self {
        case .user: "Person"
        case .message: "Chat message"
        case .review: "Review"
        }
    }
}

nonisolated enum ReportStatus: String, Codable, Hashable {
    case open, dismissed, resolved
}

/// `POST /api/reports`. Exactly one of the three ids is set.
nonisolated struct CreateReportRequest: Encodable {
    var userId: UUID?
    var messageId: UUID?
    var reviewId: UUID?
    let reason: ReportReason
    let details: String?
}

nonisolated struct BlockUserRequest: Encodable {
    let userId: UUID
}

/// Someone the logged-in user blocked (`GET /api/blocks`).
nonisolated struct BlockedUser: Codable, Hashable, Identifiable {
    let id: UUID
    let displayName: String
    let avatarUrl: String?
    let blockedAt: Date
}

nonisolated struct DeleteAccountRequest: Encodable {
    let password: String
}

nonisolated struct BanUserRequest: Encodable {
    let reason: String?
}

/// A user as admins see them in the report queue.
nonisolated struct ReportUser: Codable, Hashable, Identifiable {
    let id: UUID
    let displayName: String
    let username: String
    let avatarUrl: String?
    let role: UserRole
    let isBanned: Bool
    let isDeleted: Bool
}

/// One report in the admin queue (`GET /api/admin/reports`).
nonisolated struct Report: Codable, Hashable, Identifiable {
    let id: UUID
    let kind: ReportKind
    let reason: ReportReason
    let details: String?
    /// The message or review text when it was reported. Kept after the content is removed.
    let contentSnapshot: String?
    /// False once the message or review has been removed (always false for reports about a person).
    let contentExists: Bool
    let reporter: ReportUser
    let reportedUser: ReportUser
    /// Open reports about the same person, this one included.
    let openReportsAboutUser: Int
    let status: ReportStatus
    let createdAt: Date
    let resolvedAt: Date?
    let resolution: String?
}

/// What the report sheet is reporting, and whose name to show.
enum ReportTarget: Hashable, Identifiable {
    case user(id: UUID, name: String)
    case message(ChatMessage, authorID: UUID, authorName: String)
    case review(Review)

    var id: String {
        switch self {
        case let .user(id, _): "user-\(id)"
        case let .message(message, _, _): "message-\(message.id)"
        case let .review(review): "review-\(review.id)"
        }
    }

    /// The person behind it, who can also be blocked. Nil for reviews: the app doesn't know the author's id.
    var person: (id: UUID, name: String)? {
        switch self {
        case let .user(id, name): (id, name)
        case let .message(_, authorID, authorName): (authorID, authorName)
        case .review: nil
        }
    }

    var request: (ReportReason, String?) -> CreateReportRequest {
        { reason, details in
            switch self {
            case let .user(id, _): CreateReportRequest(userId: id, reason: reason, details: details)
            case let .message(message, _, _): CreateReportRequest(messageId: message.id, reason: reason, details: details)
            case let .review(review): CreateReportRequest(reviewId: review.id, reason: reason, details: details)
            }
        }
    }
}
