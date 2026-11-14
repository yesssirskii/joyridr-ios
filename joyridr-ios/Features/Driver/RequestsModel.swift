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
    /// Confirmed rides the driver never started, from the last 7 days (the rider was refunded).
    private(set) var timedOut: [Ride] = []
    private(set) var state: LoadState = .idle
    private(set) var unreadMessages = 0
    /// Rides with a confirm/decline in flight, so their buttons show a spinner.
    private(set) var busyRideIDs: Set<Ride.ID> = []
    var actionError: String?

    private let rides: RidesService
    private let chat: ChatService

    init(rides: RidesService = RidesService(), chat: ChatService = ChatService()) {
        self.rides = rides
        self.chat = chat
    }

    func loadIfNeeded() async {
        if state == .idle { await load() }
    }

    func load() async {
        if requests.isEmpty && upcoming.isEmpty { state = .loading }
        do {
            // All three requests run at the same time.
            async let pending = rides.list(.requests)
            async let scheduled = rides.list(.upcoming)
            // Extra: if this one fails, the rest of the screen still shows.
            async let missed = try? rides.list(.timedOut)
            requests = try await pending
            // "upcoming" also contains requests; those are already shown above.
            upcoming = try await scheduled.filter { $0.status == .confirmed || $0.status == .inProgress }
            timedOut = await missed ?? timedOut
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
        if let count = try? await chat.unreadCount() {
            unreadMessages = count
        }
    }

    func confirm(_ ride: Ride) async {
        await perform(on: ride) {
            _ = try await self.rides.confirm(ride.id)
        }
    }

    func decline(_ ride: Ride) async {
        await perform(on: ride) {
            _ = try await self.rides.decline(ride.id)
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
