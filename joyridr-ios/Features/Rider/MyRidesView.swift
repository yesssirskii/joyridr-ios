import SwiftUI

/// Rider's bookings. Same look as Explore: tapping a ride zooms its details out of the row.
struct MyRidesView: View {
    @Environment(\.selectRiderTab) private var selectRiderTab
    @State private var model = MyRidesModel()
    @State private var showProfile = false
    @State private var showChat = false
    @State private var selectedRide: Ride?
    @Namespace private var rideTransition

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HomeHeader { showProfile = true }

                    Picker("Rides", selection: $model.view) {
                        Text("Upcoming").tag(RidesService.View.upcoming)
                        Text("Past").tag(RidesService.View.past)
                    }
                    .pickerStyle(.segmented)

                    SectionTitle(
                        title: model.view == .upcoming ? "Upcoming rides" : "Past rides",
                        subtitle: model.view == .upcoming ? "Requested and confirmed" : "Completed, cancelled and declined")

                    GlowCard {
                        rideList
                    }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 90)
            }
            .background {
                ZStack(alignment: .top) {
                    Theme.background
                    RacingStripes(count: 4, lineWidth: 14, spacing: 36, startX: -0.15, length: 0.4)
                }
                .ignoresSafeArea()
            }
            .overlay(alignment: .bottomTrailing) {
                ChatButton(unreadCount: model.unreadMessages) { showChat = true }
                    .padding(Theme.horizontalPadding)
            }
            .refreshable { await model.load() }
            // Runs every time the tab is shown and whenever Upcoming/Past changes.
            .task(id: model.view) { await model.load() }
            .animation(.snappy, value: model.view)
            .sheet(item: $selectedRide, onDismiss: { Task { await model.load() } }) { ride in
                RideDetailView(ride: ride)
                    .navigationTransition(.zoom(sourceID: ride.id, in: rideTransition))
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .sheet(isPresented: $showChat) {
                ComingSoonView(title: "Messages", message: "Chat with drivers is coming soon.", systemImage: "bubble.left.and.bubble.right")
                    .presentationDetents([.medium])
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var rideList: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 160)
        case let .failed(message):
            ContentUnavailableView {
                Label("Couldn't load your rides", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { Task { await model.load() } }
                    .buttonStyle(.primary)
                    .frame(width: 180)
            }
        case .loaded where model.currentRides.isEmpty:
            if model.view == .upcoming {
                ContentUnavailableView {
                    Label("No upcoming rides", systemImage: "car.side")
                } description: {
                    Text("Book a ride and it'll show up here.")
                } actions: {
                    Button("Find a car") { selectRiderTab(.explore) }
                        .buttonStyle(.primary)
                        .frame(width: 180)
                }
            } else {
                ContentUnavailableView("No past rides yet", systemImage: "clock.arrow.circlepath",
                                       description: Text("Finished, cancelled and declined rides show up here."))
            }
        case .loaded:
            LazyVStack(spacing: 6) {
                ForEach(model.currentRides) { ride in
                    Button {
                        selectedRide = ride
                    } label: {
                        RideRow(ride: ride)
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: ride.id, in: rideTransition)
                }
            }
        }
    }
}

#Preview {
    MyRidesView()
        .environment(SessionStore())
        .preferredColorScheme(.dark)
}
