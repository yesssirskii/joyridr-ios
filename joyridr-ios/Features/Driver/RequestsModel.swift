import Foundation
import Observation

/// Ride requests waiting for the driver, plus their confirmed upcoming rides.
@Observable
final class RequestsModel {
    enum LoadState: Equatable {
        case idle, loading, loaded
        case failed(String)
    }

    private(set) var requests: [Ride] = []
    private(set) var upcoming: [Ride] = []
    private(set) var state: LoadState = .idle
    private(set) var unreadMessages = 0
    /// Rides with a confirm/decline in flight, so their buttons show a spinner.
    private(set) var busyRideIDs: Set<Ride.ID> = []
    var actionError: String?

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func loadIfNeeded() async {
        if state == .idle { await load() }
    }

    func load() async {
        if requests.isEmpty && upcoming.isEmpty { state = .loading }
        do {
            // Both requests run at the same time.
            async let requestsPage: Page<Ride> = api.get("/api/rides", query: ["view": "requests", "pageSize": "50"])
            async let upcomingPage: Page<Ride> = api.get("/api/rides", query: ["view": "upcoming", "pageSize": "50"])
            let (pending, scheduled) = try await (requestsPage, upcomingPage)
            requests = pending.items
            // "upcoming" also contains requests; those are already shown above.
            upcoming = scheduled.items.filter { $0.status == .confirmed || $0.status == .inProgress }
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
        if let unread: UnreadCount = try? await api.get("/api/conversations/unread-count") {
            unreadMessages = unread.count
        }
    }

    func confirm(_ ride: Ride) async {
        await perform(on: ride) {
            let _: Ride = try await self.api.post("/api/rides/\(ride.id.uuidString)/confirm")
        }
    }

    func decline(_ ride: Ride) async {
        await perform(on: ride) {
            let _: Ride = try await self.api.post("/api/rides/\(ride.id.uuidString)/decline", body: ReasonRequest(reason: nil))
        }
    }

    private func perform(on ride: Ride, _ action: () async throws -> Void) async {
        busyRideIDs.insert(ride.id)
        defer { busyRideIDs.remove(ride.id) }
        do {
            try await action()
            await load()
        } catch {
            actionError = error.localizedDescription
            await load() // the ride may have changed (e.g. expired), so show its real state
        }
    }
}

nonisolated struct ReasonRequest: Encodable {
    let reason: String?
}
