import SwiftUI

/// The driver's app: Requests, My cars and Schedule tabs.
struct DriverHomeView: View {
    var body: some View {
        TabView {
            Tab("Requests", systemImage: "tray.full.fill") {
                RequestsView()
            }
            Tab("My cars", systemImage: "car.2.fill") {
                ComingSoonView(title: "My cars", message: "Add your cars and photos here.", systemImage: "car.2.fill")
            }
            Tab("Schedule", systemImage: "calendar") {
                ComingSoonView(title: "Schedule", message: "Set the days and times you're available.", systemImage: "calendar")
            }
        }
    }
}
