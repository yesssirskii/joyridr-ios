import Foundation

struct RidesService {
    enum View: String {
        case upcoming, past, requests
    }

    var api: APIClient = .shared

    func list(_ view: View) async throws -> [Ride] {
        let page: Page<Ride> = try await api.get("/api/rides", query: ["view": view.rawValue, "pageSize": "50"])
        return page.items
    }

    /// Books a ride. It starts as "requested" and waits for the driver to confirm.
    func request(_ request: CreateRideRequest) async throws -> Ride {
        try await api.post("/api/rides", body: request)
    }

    func confirm(_ rideID: Ride.ID) async throws -> Ride {
        try await api.post("/api/rides/\(rideID.uuidString)/confirm")
    }

    func decline(_ rideID: Ride.ID, reason: String? = nil) async throws -> Ride {
        try await api.post("/api/rides/\(rideID.uuidString)/decline", body: ReasonRequest(reason: reason))
    }
}

nonisolated struct ReasonRequest: Encodable {
    let reason: String?
}
