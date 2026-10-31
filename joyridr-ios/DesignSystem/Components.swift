import SwiftUI

/// "JOYRIDR" wordmark with the notifications bell and the profile button, at the top of both home screens.
/// The bell shows when a `NotificationBadge` is in the environment and opens the inbox with a zoom.
struct HomeHeader: View {
    let onProfile: () -> Void

    @Environment(NotificationBadge.self) private var badge: NotificationBadge?
    @State private var showNotifications = false
    @Namespace private var bellTransition

    var body: some View {
        HStack(spacing: 10) {
            Text("JOYRIDR")
                .font(Theme.display(34))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 16)
            if let badge {
                CircleIconButton(systemImage: "bell", accessibilityLabel: "Notifications") { showNotifications = true }
                    .overlay(alignment: .topTrailing) {
                        CountBadge(count: badge.unreadCount)
                            .offset(x: 4, y: -4)
                    }
                    .accessibilityValue(badge.unreadCount > 0 ? "\(badge.unreadCount) unread" : "")
                    .matchedTransitionSource(id: "bell", in: bellTransition)
            }
            CircleIconButton(systemImage: "person", accessibilityLabel: "Profile", action: onProfile)
        }
        .sheet(isPresented: $showNotifications, onDismiss: { Task { await badge?.refresh() } }) {
            NotificationsView()
                .navigationTransition(.zoom(sourceID: "bell", in: bellTransition))
        }
    }
}

/// Section title with an optional subtitle ("AVAILABLE DRIVERS / Choose your next ride").
struct SectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .displayTitle(15)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Dark pill with an icon ("Zagreb, 30km", "Popularity").
struct FilterPill: View {
    let systemImage: String
    let title: String
    /// Stretch to share the row's width, or just fit the text.
    var fillsWidth = true
    /// When used as a toggle (e.g. Upcoming / Past), the unselected pill is dimmed.
    var isSelected = true

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(1)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(isSelected ? .white : Theme.textSecondary)
        .padding(.horizontal, 18)
        .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 44)
        .background {
            RedGlow()
                .opacity(isSelected ? 1 : 0.3)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(.white.opacity(isSelected ? 0.18 : 0.08), lineWidth: 1))
    }
}

/// Rounded card with the dark red glow, used for lists.
struct GlowCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RedGlow().clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
            }
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(.white.opacity(0.08), lineWidth: 1))
    }
}

/// Image loaded from the backend (car photo, avatar), with an icon while loading or if there's none.
struct RemoteImage: View {
    let path: String?
    var placeholder = "car.side.fill"

    var body: some View {
        AsyncImage(url: AppConfig.url(for: path)) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.12)
                    Image(systemName: placeholder)
                        .font(.title2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}

/// Floating chat button with the unread badge.
struct ChatButton: View {
    let unreadCount: Int
    let action: () -> Void

    var body: some View {
        CircleIconButton(systemImage: "bubble.left", size: 60, accessibilityLabel: "Messages", action: action)
            .overlay(alignment: .topTrailing) {
                CountBadge(count: unreadCount)
                    .offset(x: 4, y: -4)
            }
            .accessibilityValue(unreadCount > 0 ? "\(unreadCount) unread" : "")
    }
}

/// Placeholder for screens that aren't built yet.
struct ComingSoonView: View {
    let title: String
    var message = "This part of JOYRIDR is coming soon."
    var systemImage = "hammer"

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            RacingStripes(count: 3, length: 0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.accentRed)
                Text(title)
                    .displayTitle(20)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
        }
    }
}

/// Little coloured label for a ride's status.
struct StatusChip: View {
    let status: RideStatus

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
    }

    private var title: String {
        switch status {
        case .awaitingPayment: "Awaiting payment"
        case .requested: "Requested"
        case .confirmed: "Confirmed"
        case .inProgress: "In progress"
        case .completed: "Completed"
        case .declined: "Declined"
        case .cancelled: "Cancelled"
        case .expired: "Expired"
        }
    }

    private var color: Color { status.color }
}

extension RideStatus {
    var color: Color {
        switch self {
        case .confirmed, .completed: Theme.available
        case .inProgress: .yellow
        case .requested, .awaitingPayment: .orange
        case .declined, .cancelled, .expired: Theme.textSecondary
        }
    }

    var icon: String {
        switch self {
        case .awaitingPayment: "creditcard"
        case .requested: "hourglass"
        case .confirmed: "checkmark.seal.fill"
        case .inProgress: "flag.checkered"
        case .completed: "trophy.fill"
        case .declined, .cancelled: "xmark.circle.fill"
        case .expired: "clock.badge.xmark"
        }
    }
}

/// Coloured banner with an icon, a title and a line or two of explanation.
/// Used at the top of the ride sheets and for the paused state in Schedule.
struct StatusBanner: View {
    let icon: String
    let color: Color
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(color.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Five tappable stars for rating the other person after a ride.
struct StarRatingPicker: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    rating = star
                } label: {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.title)
                        .foregroundStyle(star <= rating ? Theme.accentRed : Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
            }
        }
    }
}

extension Decimal {
    /// "180 €" style price, formatted for the user's locale.
    func price(_ currency: String) -> String {
        formatted(.currency(code: currency).precision(.fractionLength(0...2)))
    }
}

/// Compact car card: photo, car name, a subtitle and an ⓘ button for the full car and driver details.
/// Used at the top of the booking and ride detail sheets.
struct CarSummaryCard: View {
    let photoPath: String?
    let title: String
    let subtitle: String
    let onInfo: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            RemoteImage(path: photoPath)
                .frame(width: 56, height: 56)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            CircleIconButton(systemImage: "info", size: 40, accessibilityLabel: "Car and driver details", action: onInfo)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

extension View {
    /// Keeps `isVisible` in sync with the on-screen keyboard. Used to hide bottom bars while typing,
    /// so they don't ride up with the keyboard and cover the field being edited.
    func trackKeyboard(_ isVisible: Binding<Bool>) -> some View {
        onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isVisible.wrappedValue = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isVisible.wrappedValue = false
        }
    }
}
