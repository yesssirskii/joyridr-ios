import SwiftUI

/// The rider's app: Explore and My rides tabs.
struct RiderHomeView: View {
    var body: some View {
        TabView {
            Tab("Explore", systemImage: "magnifyingglass") {
                ExploreView()
            }
            Tab("My rides", systemImage: "car.fill") {
                ComingSoonView(title: "My rides", message: "Your upcoming and past rides will show up here.", systemImage: "car.fill")
            }
        }
    }
}
