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

    func ride(_ rideID: Ride.ID) async throws -> Ride {
        try await api.get("/api/rides/\(rideID.uuidString)")
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

    /// Driver: from 30 minutes before the start time.
    func start(_ rideID: Ride.ID) async throws -> Ride {
        try await api.post("/api/rides/\(rideID.uuidString)/start")
    }

    func complete(_ rideID: Ride.ID) async throws -> Ride {
        try await api.post("/api/rides/\(rideID.uuidString)/complete")
    }

    /// Rider: free (or full refund) until 24 h before a confirmed ride. Driver: always a full refund for the rider.
    func cancel(_ rideID: Ride.ID, reason: String? = nil) async throws -> Ride {
        try await api.post("/api/rides/\(rideID.uuidString)/cancel", body: ReasonRequest(reason: reason))
    }

    /// Rate the other person after a completed ride (once).
    func review(_ rideID: Ride.ID, rating: Int, comment: String?) async throws {
        let _: Review = try await api.post("/api/rides/\(rideID.uuidString)/reviews", body: ReviewRequest(rating: rating, comment: comment))
    }
}

nonisolated struct ReasonRequest: Encodable {
    let reason: String?
}

nonisolated struct ReviewRequest: Encodable {
    let rating: Int
    let comment: String?
}
