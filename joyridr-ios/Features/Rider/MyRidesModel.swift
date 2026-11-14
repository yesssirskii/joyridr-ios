import Foundation
import Observation

/// The rider's bookings, split into upcoming (requested/confirmed/in progress) and past.
@Observable
final class MyRidesModel {
    enum LoadState: Equatable {
        case idle, loading, loaded
        case failed(String)
    }

    var view: RidesService.View = .upcoming
    private(set) var state: LoadState = .idle
    private(set) var unreadMessages = 0
    /// Both lists are kept, so switching between Upcoming and Past is instant (then refreshed).
    private var ridesByView: [RidesService.View: [Ride]] = [:]

    private let rides: RidesService
    private let chat: ChatService

    init(rides: RidesService = RidesService(), chat: ChatService = ChatService()) {
        self.rides = rides
        self.chat = chat
    }

    var currentRides: [Ride] { ridesByView[view] ?? [] }

    /// Shown in their own section under Upcoming, so a ride that never happened doesn't just vanish.
    private(set) var timedOut: [Ride] = []

    func load() async {
        let view = view
        if ridesByView[view] == nil { state = .loading }
        do {
            if view == .upcoming {
                // Both requests run at the same time. The timed-out list is extra: if it fails, Upcoming still shows.
                async let timedOutRides = try? rides.list(.timedOut)
                ridesByView[view] = try await rides.list(view)
                timedOut = await timedOutRides ?? timedOut
            } else {
                ridesByView[view] = try await rides.list(view)
            }
            if view == self.view { state = .loaded }
        } catch {
            if Task.isCancelled { return }
            if ridesByView[view] == nil { state = .failed(error.localizedDescription) }
        }
        if let count = try? await chat.unreadCount() {
            unreadMessages = count
        }
    }
}
