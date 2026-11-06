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

/// The rider's app: Explore and My rides tabs. Admins use it too and get an extra Reviews tab.
struct RiderHomeView: View {
    @Environment(SessionStore.self) private var session
    @State private var tab: RiderTab = .explore
    @State private var notificationBadge = NotificationBadge()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $tab) {
            Tab("Explore", systemImage: "magnifyingglass", value: .explore) {
                ExploreView()
            }
            Tab("My rides", systemImage: "car.fill", value: .myRides) {
                MyRidesView()
            }
            if session.me?.user.role == .admin {
                Tab("Reviews", systemImage: "checkmark.seal.fill", value: .reviews) {
                    CarReviewsView()
                }
                Tab("Reports", systemImage: "flag.fill", value: .reports) {
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
}
