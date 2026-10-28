import Foundation
import Observation

/// One booking seen by the rider: keeps it fresh, cancels it, and sends the review.
@Observable
final class RideDetailModel {
    private(set) var ride: Ride
    private(set) var isCancelling = false
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

    var driverFirstName: String {
        ride.driver.displayName.split(separator: " ").first.map(String.init) ?? ride.driver.displayName
    }

    var canCancel: Bool {
        [.awaitingPayment, .requested, .confirmed].contains(ride.status)
    }

    /// What happens to the rider's money if they cancel now (mirrors the backend's rules).
    var cancelConsequence: String {
        switch ride.status {
        case .awaitingPayment, .requested:
            "\(driverFirstName) hasn't confirmed yet, so you won't be charged."
        case .confirmed:
            ride.startsAt.timeIntervalSinceNow >= 24 * 3600
                ? "It's more than 24 hours before the ride, so you'll get a full refund."
                : "It's less than 24 hours before the ride, so you won't get a refund."
        default:
            ""
        }
    }

    /// Picks up changes made elsewhere, e.g. the driver confirming while this sheet is open.
    func refresh() async {
        if let fresh = try? await rides.ride(ride.id) {
            ride = fresh
        }
    }

    func cancel() async {
        guard !isCancelling else { return }
        isCancelling = true
        errorMessage = nil
        defer { isCancelling = false }
        do {
            ride = try await rides.cancel(ride.id)
        } catch {
            errorMessage = error.localizedDescription
            await refresh()
        }
    }

    func submitReview() async {
        guard rating > 0, !isSubmittingReview else { return }
        isSubmittingReview = true
        errorMessage = nil
        defer { isSubmittingReview = false }
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await rides.review(ride.id, rating: rating, comment: trimmed.isEmpty ? nil : trimmed)
            reviewSent = true
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
