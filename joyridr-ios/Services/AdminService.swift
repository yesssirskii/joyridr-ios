import Foundation

/// Admin-only endpoints: the car review queue and reports. The backend refuses these for anyone who isn't an admin.
struct AdminService {
    var api: APIClient = .shared

    /// Cars waiting for review, oldest first.
    func pendingCars() async throws -> [CarDetail] {
        try await api.get("/api/admin/cars", query: ["status": CarStatus.pendingReview.rawValue])
    }

    /// Lists the car so riders can find and book it.
    func approve(_ carID: CarDetail.ID) async throws -> CarDetail {
        try await api.post("/api/admin/cars/\(carID.uuidString)/approve")
    }

    /// The driver sees the reason. Without one they get a general "doesn't meet our requirements" message.
    func reject(_ carID: CarDetail.ID, reason: String?) async throws -> CarDetail {
        try await api.post("/api/admin/cars/\(carID.uuidString)/reject", body: ReasonRequest(reason: reason))
    }

    /// Open reports, oldest first.
    func openReports() async throws -> [Report] {
        try await api.get("/api/admin/reports", query: ["status": ReportStatus.open.rawValue])
    }

    func dismiss(_ reportID: Report.ID) async throws {
        try await api.post("/api/admin/reports/\(reportID.uuidString)/dismiss")
    }

    /// Deletes the reported message or review, and closes every open report about it.
    func removeContent(of reportID: Report.ID) async throws {
        try await api.post("/api/admin/reports/\(reportID.uuidString)/remove-content")
    }

    /// Logs the user out everywhere and stops them logging in; closes open reports about them.
    func ban(_ userID: UUID, reason: String?) async throws {
        try await api.post("/api/admin/users/\(userID.uuidString)/ban", body: BanUserRequest(reason: reason))
    }
}
