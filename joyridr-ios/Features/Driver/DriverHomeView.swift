import SwiftUI

/// The driver's app: Requests, My cars and Schedule tabs.
struct DriverHomeView: View {
    var body: some View {
        TabView {
            Tab("Requests", systemImage: "tray.full.fill") {
                RequestsView()
            }
            Tab("My cars", systemImage: "car.2.fill") {
                MyCarsView()
            }
            Tab("Schedule", systemImage: "calendar") {
                ComingSoonView(title: "Schedule", message: "Set the days and times you're available.", systemImage: "calendar")
            }
        }
    }
}
