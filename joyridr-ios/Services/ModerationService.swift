import Foundation

/// Blocking and reporting other users. A block works both ways: no messages and no bookings between the two.
struct ModerationService {
    var api: APIClient = .shared

    func blockedUsers() async throws -> [BlockedUser] {
        try await api.get("/api/blocks")
    }

    func block(_ userID: UUID) async throws {
        try await api.post("/api/blocks", body: BlockUserRequest(userId: userID))
    }

    func unblock(_ userID: UUID) async throws {
        try await api.delete("/api/blocks/\(userID.uuidString)")
    }

    func report(_ request: CreateReportRequest) async throws {
        try await api.post("/api/reports", body: request)
    }
}
