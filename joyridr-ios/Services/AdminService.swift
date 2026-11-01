import Foundation

/// Admin-only endpoints: the car review queue. The backend refuses these for anyone who isn't an admin.
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
}
