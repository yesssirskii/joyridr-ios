import Foundation
import Observation

/// The rider's bookings, split into upcoming (requested/confirmed/in progress), past and timed out.
@Observable
final class MyRidesModel {
    enum LoadState: Equatable {
        case idle, loading, loaded
        case failed(String)
    }

    var view: RidesService.View = .upcoming
    private(set) var state: LoadState = .idle
    private(set) var unreadMessages = 0
    /// Every list is kept, so switching between Upcoming, Past and Timed out is instant (then refreshed).
    private var ridesByView: [RidesService.View: [Ride]] = [:]

    private let rides: RidesService
    private let chat: ChatService

    init(rides: RidesService = RidesService(), chat: ChatService = ChatService()) {
        self.rides = rides
        self.chat = chat
    }

    var currentRides: [Ride] { ridesByView[view] ?? [] }

    func load() async {
        let view = view
        if ridesByView[view] == nil { state = .loading }
        do {
            // Timed out only returns rides from the last few days (the backend's Rides:TimedOutVisibleDays),
            // so they drop off this screen on their own. They also stay in Past.
            ridesByView[view] = try await rides.list(view)
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
