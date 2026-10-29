import SwiftUI

/// Driver home: incoming ride requests to confirm or decline, then upcoming rides.
/// Tapping a request or a ride zooms its details out of the card.
struct RequestsView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = RequestsModel()
    @State private var showProfile = false
    @State private var showChat = false
    /// The rider whose chat is open from a request card.
    @State private var chatWith: ChatParticipant?
    @State private var selectedRide: Ride?
    @Namespace private var rideTransition

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HomeHeader { showProfile = true }

                    if let driver = session.me?.driverProfile, driver.baseLatitude == nil {
                        SetupHintCard()
                    }

                    SectionTitle(title: "Ride requests", subtitle: "Confirm before they expire")
                    requestsSection

                    if !model.upcoming.isEmpty {
                        SectionTitle(title: "Upcoming rides")
                        GlowCard {
                            VStack(spacing: 14) {
                                ForEach(model.upcoming) { ride in
                                    Button {
                                        selectedRide = ride
                                    } label: {
                                        UpcomingRideRow(ride: ride)
                                            .contentShape(.rect)
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
                    RacingStripes(count: 4, lineWidth: 14, spacing: 36, startX: -0.15, length: 0.4)
                }
                .ignoresSafeArea()
            }
            .overlay(alignment: .bottomTrailing) {
                ChatButton(unreadCount: model.unreadMessages) { showChat = true }
                    .padding(Theme.horizontalPadding)
            }
            .refreshable { await model.load() }
            .task { await model.loadIfNeeded() }
            .alert("Something went wrong", isPresented: Binding(
                get: { model.actionError != nil },
                set: { if !$0 { model.actionError = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.actionError ?? "")
            }
            .sheet(item: $selectedRide, onDismiss: { Task { await model.load() } }) { ride in
                DriverRideDetailView(ride: ride)
                    .navigationTransition(.zoom(sourceID: ride.id, in: rideTransition))
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .sheet(isPresented: $showChat, onDismiss: { Task { await model.load() } }) {
                InboxView()
            }
            .sheet(item: $chatWith, onDismiss: { Task { await model.load() } }) { rider in
                ConversationSheet(otherUser: rider)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var requestsSection: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 160)
        case let .failed(message):
            GlowCard {
                ContentUnavailableView {
                    Label("Couldn't load rides", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") { Task { await model.load() } }
                        .buttonStyle(.primary)
                        .frame(width: 180)
                }
            }
        case .loaded where model.requests.isEmpty:
            GlowCard {
                ContentUnavailableView(
                    "No requests right now",
                    systemImage: "tray",
                    description: Text("When a JoyRider books one of your cars, it shows up here."))
            }
        case .loaded:
            VStack(spacing: 14) {
                ForEach(model.requests) { ride in
                    RideRequestCard(
                        ride: ride,
                        isBusy: model.busyRideIDs.contains(ride.id),
                        onOpen: { selectedRide = ride },
                        onConfirm: { Task { await model.confirm(ride) } },
                        onDecline: { Task { await model.decline(ride) } },
                        onMessage: {
                            chatWith = ChatParticipant(id: ride.rider.id, displayName: ride.rider.displayName,
                                                       avatarUrl: ride.rider.avatarUrl, isDriver: false)
                        })
                    .matchedTransitionSource(id: ride.id, in: rideTransition)
                }
            }
        }
    }
}

/// Shown until the driver has set a base location, since their cars can't appear in search before that.
private struct SetupHintCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(Theme.accentRed)
            VStack(alignment: .leading, spacing: 4) {
                Text("Finish setting up")
                    .font(.headline)
                Text("Add your location, a car and your schedule so JoyRiders can find you. Setup screens are coming next.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

#Preview {
    RequestsView()
        .environment(SessionStore())
        .preferredColorScheme(.dark)
}
