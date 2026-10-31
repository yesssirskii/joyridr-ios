import SwiftUI

/// "Notifications": ride updates, car approvals and reviews, newest first. Opened from the bell in the
/// home header. Tapping a ride notification zooms that ride's details out of the row.
struct NotificationsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(NotificationBadge.self) private var badge: NotificationBadge?
    @Environment(\.dismiss) private var dismiss
    @State private var model = NotificationsModel()
    @State private var openedRide: OpenedRide?
    @Namespace private var rideTransition

    /// A ride opened from a notification. The notification's id is the zoom source.
    private struct OpenedRide: Identifiable {
        let ride: Ride
        let id: AppNotification.ID
    }

    private var isDriver: Bool { session.me?.user.role == .joyDriver }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SectionTitle(title: "Notifications", subtitle: subtitle)
                    GlowCard {
                        content
                    }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .background {
                ZStack(alignment: .top) {
                    Theme.background
                    RacingStripes(count: 4, lineWidth: 14, spacing: 36, startX: -0.15)
                }
                .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.hasUnread {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Mark all read", systemImage: "checkmark.circle") {
                            Task {
                                await model.markAllRead()
                                await badge?.refresh()
                            }
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .refreshable { await model.load() }
            .task { await model.load() }
            .animation(.snappy, value: model.items)
            .alert("Something went wrong", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
            .sheet(item: $openedRide, onDismiss: {
                Task {
                    await model.load()
                    await badge?.refresh()
                }
            }) { opened in
                Group {
                    if isDriver {
                        DriverRideDetailView(ride: opened.ride)
                    } else {
                        RideDetailView(ride: opened.ride)
                    }
                }
                .navigationTransition(.zoom(sourceID: opened.id, in: rideTransition))
            }
        }
    }

    private var subtitle: String {
        guard model.state == .loaded else { return " " }
        let unread = model.items.filter { !$0.isRead }.count
        return unread == 0 ? "You're all caught up" : "\(unread) unread"
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 160)
        case let .failed(message):
            ContentUnavailableView {
                Label("Couldn't load notifications", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { Task { await model.load() } }
                    .buttonStyle(.primary)
                    .frame(width: 180)
            }
        case .loaded where model.items.isEmpty:
            ContentUnavailableView(
                "No notifications yet",
                systemImage: "bell",
                description: Text(isDriver
                    ? "New ride requests, cancellations and reviews show up here."
                    : "Updates about your rides show up here, like when a driver confirms."))
        case .loaded:
            LazyVStack(spacing: 6) {
                ForEach(model.items) { notification in
                    Button {
                        Task {
                            if let ride = await model.open(notification) {
                                openedRide = OpenedRide(ride: ride, id: notification.id)
                            }
                            await badge?.refresh()
                        }
                    } label: {
                        NotificationRow(notification: notification, isOpening: model.openingID == notification.id)
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: notification.id, in: rideTransition)
                    .onAppear {
                        if notification.id == model.items.last?.id {
                            Task { await model.loadMore() }
                        }
                    }
                }
                if model.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 8)
                }
            }
        }
    }
}

/// One notification: an icon for what happened, the text, and when.
private struct NotificationRow: View {
    let notification: AppNotification
    let isOpening: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: notification.type.icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(notification.type.color)
                .frame(width: 48, height: 48)
                .background(notification.type.color.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(notification.title)
                        .font(.headline)
                        .foregroundStyle(notification.isRead ? Theme.textSecondary : .white)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(timeText)
                        .font(.caption)
                        .foregroundStyle(notification.isRead ? Theme.textSecondary : Theme.accentRed)
                }
                HStack(alignment: .top) {
                    Text(notification.body)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(3)
                    Spacer(minLength: 8)
                    if isOpening {
                        ProgressView()
                    } else if !notification.isRead {
                        Circle()
                            .fill(Theme.accentRed)
                            .frame(width: 10, height: 10)
                            .padding(.top, 5)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityValue(notification.isRead ? "" : "Unread")
    }

    private var timeText: String {
        let date = notification.createdAt
        if Calendar.current.isDateInToday(date) { return date.formatted(date: .omitted, time: .shortened) }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

private extension NotificationKind {
    var icon: String {
        switch self {
        case .rideRequested: "tray.and.arrow.down.fill"
        case .rideConfirmed: "checkmark.seal.fill"
        case .rideDeclined, .rideCancelled: "xmark.circle.fill"
        case .rideExpired: "clock.badge.xmark"
        case .rideStarted: "flag.checkered"
        case .rideCompleted: "trophy.fill"
        case .meetingPointUpdated: "mappin.and.ellipse"
        case .carApproved: "car.fill"
        case .carRejected: "exclamationmark.triangle.fill"
        case .newReview: "star.fill"
        case .unknown: "bell.fill"
        }
    }

    var color: Color {
        switch self {
        case .rideConfirmed, .rideCompleted, .carApproved: Theme.available
        case .rideRequested, .carRejected: .orange
        case .rideStarted, .newReview: .yellow
        case .meetingPointUpdated, .unknown: Theme.accentRed
        case .rideDeclined, .rideCancelled, .rideExpired: Theme.textSecondary
        }
    }
}

#Preview {
    NotificationsView()
        .environment(SessionStore())
        .preferredColorScheme(.dark)
}
