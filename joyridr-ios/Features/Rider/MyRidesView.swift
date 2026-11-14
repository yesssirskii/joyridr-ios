import SwiftUI

/// Rider's bookings. Same look as Explore: tapping a ride zooms its details out of the row.
struct MyRidesView: View {
    @Environment(\.selectRiderTab) private var selectRiderTab
    @State private var model = MyRidesModel()
    @State private var showChat = false
    @State private var selectedRide: Ride?
    @Namespace private var rideTransition

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HomeHeader()

                    // Same pills as the radius and sort buttons in Explore; the selected one glows.
                    HStack(spacing: 14) {
                        viewPill(.upcoming, title: t("my_rides.upcoming"), systemImage: "calendar")
                        viewPill(.past, title: t("my_rides.past"), systemImage: "clock.arrow.circlepath")
                    }

                    SectionTitle(
                        title: model.view == .upcoming ? t("my_rides.upcoming_title") : t("my_rides.past_title"),
                        subtitle: model.view == .upcoming ? t("my_rides.upcoming_subtitle") : t("my_rides.past_subtitle"))

                    GlowCard {
                        rideList
                    }

                    if model.view == .upcoming && !model.timedOut.isEmpty {
                        SectionTitle(title: t("my_rides.timed_out_title"), subtitle: t("my_rides.timed_out_subtitle_rider"))
                        GlowCard {
                            LazyVStack(spacing: 6) {
                                ForEach(model.timedOut) { ride in
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
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 90)
            }
            .background {
                ZStack(alignment: .top) {
                    Theme.background
                    RacingStripes(count: 4, lineWidth: 14, spacing: 36, startX: -0.15)
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
            .sheet(isPresented: $showChat, onDismiss: { Task { await model.load() } }) {
                InboxView()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func viewPill(_ view: RidesService.View, title: String, systemImage: String) -> some View {
        Button {
            model.view = view
        } label: {
            FilterPill(systemImage: systemImage, title: title, isSelected: model.view == view)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(model.view == view ? .isSelected : [])
    }

    @ViewBuilder
    private var rideList: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 160)
        case let .failed(message):
            ContentUnavailableView {
                Label(t("my_rides.load_failed"), systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button(t("common.try_again")) { Task { await model.load() } }
                    .buttonStyle(.primary)
                    .frame(width: 180)
            }
        case .loaded where model.currentRides.isEmpty:
            if model.view == .upcoming {
                ContentUnavailableView {
                    Label(t("my_rides.upcoming_empty"), systemImage: "car.side")
                } description: {
                    Text(t("my_rides.upcoming_empty_message"))
                } actions: {
                    Button(t("my_rides.find_car")) { selectRiderTab(.explore) }
                        .buttonStyle(.primary)
                        .frame(width: 180)
                }
            } else {
                ContentUnavailableView(t("my_rides.past_empty"), systemImage: "clock.arrow.circlepath",
                                       description: Text(t("my_rides.past_empty_message")))
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
