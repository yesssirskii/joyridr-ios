import Foundation
import Observation

/// The unread count on the bell in every home header. Owned by the rider or driver home view and
/// shared through the environment, so every tab shows the same number.
@Observable
final class NotificationBadge {
    private(set) var unreadCount = 0

    private let notifications: NotificationsService

    init(notifications: NotificationsService = NotificationsService()) {
        self.notifications = notifications
    }

    func refresh() async {
        if let count = try? await notifications.unreadCount() {
            unreadCount = count
        }
    }

    /// Checks every 30 seconds while the home screen is around, so ride updates show up on their own.
    /// Push notifications will replace most of this later.
    func keepFresh() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(30))
        }
    }
}
