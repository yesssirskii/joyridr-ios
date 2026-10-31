import SwiftUI

/// The driver's app: Requests, My cars and Schedule tabs.
struct DriverHomeView: View {
    @State private var notificationBadge = NotificationBadge()
    @Environment(\.scenePhase) private var scenePhase

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
        .environment(notificationBadge)
        .task { await notificationBadge.keepFresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await notificationBadge.refresh() } }
        }
    }
}
