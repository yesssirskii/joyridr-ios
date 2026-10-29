import Foundation
import Observation

/// One booking seen by the driver: confirm or decline the request, start and finish the ride,
/// cancel it, and rate the rider afterwards.
@Observable
final class DriverRideModel {
    enum Action {
        case confirm, decline, start, complete, cancel
    }

    private(set) var ride: Ride
    /// The action in flight, so its button shows a spinner.
    private(set) var busyAction: Action?
    private(set) var isSubmittingReview = false
    private(set) var reviewSent = false
    var rating = 0
    var comment = ""
    var errorMessage: String?

    private let rides: RidesService

    init(ride: Ride, rides: RidesService = RidesService()) {
        self.ride = ride
        self.rides = rides
    }

    var riderFirstName: String {
        ride.rider.displayName.split(separator: " ").first.map(String.init) ?? ride.rider.displayName
    }

    /// The backend lets a confirmed ride start at most 30 minutes early.
    var startAvailableAt: Date {
        ride.startsAt.addingTimeInterval(-30 * 60)
    }

    func canStart(at now: Date) -> Bool {
        ride.status == .confirmed && now >= startAvailableAt
    }

    /// Picks up changes made elsewhere, e.g. the rider cancelling while this sheet is open.
    func refresh() async {
        if let fresh = try? await rides.ride(ride.id) {
            ride = fresh
        }
    }

    func confirm() async {
        await perform(.confirm) { try await self.rides.confirm(self.ride.id) }
    }

    func decline(reason: String) async {
        await perform(.decline) { try await self.rides.decline(self.ride.id, reason: Self.optional(reason)) }
    }

    func start() async {
        await perform(.start) { try await self.rides.start(self.ride.id) }
    }

    func complete() async {
        await perform(.complete) { try await self.rides.complete(self.ride.id) }
    }

    func cancel(reason: String) async {
        await perform(.cancel) { try await self.rides.cancel(self.ride.id, reason: Self.optional(reason)) }
    }

    func submitReview() async {
        guard rating > 0, !isSubmittingReview else { return }
        isSubmittingReview = true
        errorMessage = nil
        defer { isSubmittingReview = false }
        do {
            try await rides.review(ride.id, rating: rating, comment: Self.optional(comment))
            reviewSent = true
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func perform(_ action: Action, _ call: () async throws -> Ride) async {
        guard busyAction == nil else { return }
        busyAction = action
        errorMessage = nil
        defer { busyAction = nil }
        do {
            ride = try await call()
        } catch {
            errorMessage = error.localizedDescription
            await refresh() // the ride may have changed (e.g. expired), so show its real state
        }
    }

    private static func optional(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
