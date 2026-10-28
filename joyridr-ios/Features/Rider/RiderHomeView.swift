import SwiftUI

enum RiderTab: Hashable {
    case explore, myRides
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

/// The rider's app: Explore and My rides tabs.
struct RiderHomeView: View {
    @State private var tab: RiderTab = .explore

    var body: some View {
        TabView(selection: $tab) {
            Tab("Explore", systemImage: "magnifyingglass", value: .explore) {
                ExploreView()
            }
            Tab("My rides", systemImage: "car.fill", value: .myRides) {
                MyRidesView()
            }
        }
        .environment(\.selectRiderTab, SelectRiderTabAction { tab = $0 })
    }
}
