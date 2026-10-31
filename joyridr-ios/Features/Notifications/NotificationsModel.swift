import Foundation
import Observation

/// The notifications inbox: loads it a page at a time, marks things read and fetches the ride to open.
@Observable
final class NotificationsModel {
    enum LoadState: Equatable {
        case loading, loaded
        case failed(String)
    }

    private(set) var items: [AppNotification] = []
    private(set) var state: LoadState = .loading
    private(set) var hasMore = false
    private(set) var isLoadingMore = false
    /// The notification whose ride is being fetched, so its row shows a spinner.
    private(set) var openingID: AppNotification.ID?
    var errorMessage: String?

    private var page = 1
    private let notifications: NotificationsService
    private let rides: RidesService

    init(notifications: NotificationsService = NotificationsService(), rides: RidesService = RidesService()) {
        self.notifications = notifications
        self.rides = rides
    }

    var hasUnread: Bool {
        items.contains { !$0.isRead }
    }

    func load() async {
        do {
            let first = try await notifications.list(page: 1)
            items = first.items
            hasMore = first.hasMore
            page = 1
            state = .loaded
        } catch {
            if Task.isCancelled { return }
            if items.isEmpty { state = .failed(error.localizedDescription) }
        }
    }

    /// Called when the last row appears.
    func loadMore() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        if let next = try? await notifications.list(page: page + 1) {
            // Skip anything already shown, in case new notifications shifted the pages.
            let known = Set(items.map(\.id))
            items += next.items.filter { !known.contains($0.id) }
            hasMore = next.hasMore
            page += 1
        }
    }

    func markAllRead() async {
        for index in items.indices { items[index].isRead = true }
        do {
            try await notifications.markAllRead()
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
    }

    /// Marks the notification read and, if it's about a ride, returns that ride to open.
    func open(_ notification: AppNotification) async -> Ride? {
        if !notification.isRead, let index = items.firstIndex(where: { $0.id == notification.id }) {
            items[index].isRead = true
            // Not worth bothering the user if this fails; it just stays unread on the server.
            Task { try? await notifications.markRead(notification.id) }
        }
        guard let rideID = notification.rideId, openingID == nil else { return nil }
        openingID = notification.id
        defer { openingID = nil }
        do {
            return try await rides.ride(rideID)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
