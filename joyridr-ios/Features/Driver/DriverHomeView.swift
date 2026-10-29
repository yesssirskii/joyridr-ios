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
                ScheduleView()
            }
        }
    }
}
