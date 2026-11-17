import Foundation
import Observation

/// Admin-only "All cars" list shown under Explore's own list: every car, whatever its status.
@Observable
final class AllCarsModel {
    enum LoadState: Equatable {
        case loading, loaded
        case failed(String)
    }

    private(set) var cars: [CarDetail] = []
    private(set) var state: LoadState = .loading

    private let admin: AdminService

    init(admin: AdminService = AdminService()) {
        self.admin = admin
    }

    func load() async {
        do {
            cars = try await admin.allCars()
            state = .loaded
        } catch {
            if Task.isCancelled { return }
            // Keep showing the old list if a refresh fails.
            if cars.isEmpty { state = .failed(error.localizedDescription) }
        }
    }
}

/// Admin-only "All rides" list shown under My rides: every booking on the platform, newest first.
/// Loads a page at a time; "Show more" fetches the next one.
@Observable
final class AllRidesModel {
    enum LoadState: Equatable {
        case loading, loaded
        case failed(String)
    }

    private(set) var rides: [Ride] = []
    private(set) var state: LoadState = .loading
    private(set) var totalCount = 0
    private(set) var hasMore = false
    private(set) var isLoadingMore = false
    /// The last page that has been loaded.
    private var page = 1

    private let admin: AdminService

    init(admin: AdminService = AdminService()) {
        self.admin = admin
    }

    /// Starts again from the first page (on appear and pull to refresh).
    func load() async {
        do {
            let first = try await admin.allRides(page: 1)
            rides = first.items
            totalCount = first.totalCount
            hasMore = first.hasMore
            page = 1
            state = .loaded
        } catch {
            if Task.isCancelled { return }
            if rides.isEmpty { state = .failed(error.localizedDescription) }
        }
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        guard let next = try? await admin.allRides(page: page + 1) else { return }
        // A ride booked since the last load shifts every page by one, so skip any we already have.
        let known = Set(rides.map(\.id))
        rides += next.items.filter { !known.contains($0.id) }
        totalCount = next.totalCount
        hasMore = next.hasMore
        page += 1
    }
}
