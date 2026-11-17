import SwiftUI

enum RiderTab: Hashable {
    case explore, myRides, reviews, reports
}

/// Switches the rider's tab. Call it like a function: `selectRiderTab(.myRides)`.
/// (Same pattern as SwiftUI's `dismiss` action.)
struct SelectRiderTabAction {
    var action: (RiderTab) -> Void = { _ in }

    func callAsFunction(_ tab: RiderTab) {
        action(tab)
    }
}

extension EnvironmentValues {
    /// Lets any screen in the rider app switch tabs, e.g. "See it in My rides" after booking.
    @Entry var selectRiderTab = SelectRiderTabAction()
}

/// The rider's app: Explore and My rides tabs. Admins use it too, with Reviews and Reports tabs added.
/// Admins never book, so their first two tabs are "Drivers" (every car) and "Rides" (every ride).
struct RiderHomeView: View {
    @Environment(SessionStore.self) private var session
    @State private var tab: RiderTab = .explore
    @State private var notificationBadge = NotificationBadge()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $tab) {
            Tab(isAdmin ? t("tabs.drivers") : t("tabs.explore"), systemImage: isAdmin ? "steeringwheel" : "magnifyingglass", value: .explore) {
                ExploreView()
            }
            Tab(isAdmin ? t("tabs.rides") : t("tabs.my_rides"), systemImage: "car.fill", value: .myRides) {
                MyRidesView()
            }
            if isAdmin {
                Tab(t("tabs.car_reviews"), systemImage: "checkmark.seal.fill", value: .reviews) {
                    CarReviewsView()
                }
                Tab(t("tabs.reports"), systemImage: "flag.fill", value: .reports) {
                    ReportsView()
                }
            }
        }
        .environment(\.selectRiderTab, SelectRiderTabAction { tab = $0 })
        .environment(notificationBadge)
        .task { await notificationBadge.keepFresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await notificationBadge.refresh() } }
        }
    }

    private var isAdmin: Bool { session.me?.user.role == .admin }
}
