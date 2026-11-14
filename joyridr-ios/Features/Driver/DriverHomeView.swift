import SwiftUI

/// The driver's app: Requests, My cars and Schedule tabs.
struct DriverHomeView: View {
    @State private var notificationBadge = NotificationBadge()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab(t("tabs.requests"), systemImage: "tray.full.fill") {
                RequestsView()
            }
            Tab(t("tabs.my_cars"), systemImage: "car.2.fill") {
                MyCarsView()
            }
            Tab(t("tabs.schedule"), systemImage: "calendar") {
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
