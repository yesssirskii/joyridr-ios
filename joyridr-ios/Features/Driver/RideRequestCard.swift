import SwiftUI

/// A ride request the driver can confirm or decline. Tapping anywhere else opens the full details.
struct RideRequestCard: View {
    let ride: Ride
    let isBusy: Bool
    let onOpen: () -> Void
    let onConfirm: () -> Void
    let onDecline: () -> Void
    let onMessage: () -> Void

    @State private var confirmDecline = false

    var body: some View {
        GlowCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    RemoteImage(path: ride.rider.avatarUrl, placeholder: "person.fill")
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ride.rider.displayName)
                            .font(.headline)
                        Text(ride.rider.ratingText)
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Text(ride.price.price(ride.currency))
                        .font(.title3.weight(.bold))
                    CircleIconButton(systemImage: "bubble.left", size: 40,
                                     accessibilityLabel: t("chat.message_name", ["name": ride.rider.displayName]), action: onMessage)
                }

                Divider().overlay(.white.opacity(0.1))

                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(ride.car.name, systemImage: "car.fill")
                        Label(timeText, systemImage: "calendar")
                        Label(meetingText, systemImage: "mappin.and.ellipse")
                        if let note = ride.riderNote, !note.isEmpty {
                            Label("“\(note)”", systemImage: "text.bubble")
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .font(.subheadline)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right")
                        .font(.title3)
                        .foregroundStyle(Theme.textSecondary)
                }

                if let respondBy = ride.respondBy {
                    // A date with style: .relative counts down by itself.
                    Text("\(Image(systemName: "hourglass")) \(t("requests.respond_within")) \(respondBy, style: .relative)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accentRed)
                }

                HStack(spacing: 12) {
                    Button(t("requests.decline")) { confirmDecline = true }
                        .buttonStyle(.secondary)
                    Button(t("requests.confirm"), action: onConfirm)
                        .buttonStyle(.primary(isLoading: isBusy))
                }
                .disabled(isBusy)
            }
        }
        // The buttons inside keep their own taps; everywhere else opens the details.
        .contentShape(.rect)
        .onTapGesture(perform: onOpen)
        .accessibilityAction(named: t("booking.car_info.title"), onOpen)
        .confirmationDialog(t("requests.decline_title"), isPresented: $confirmDecline, titleVisibility: .visible) {
            Button(t("requests.decline_ride"), role: .destructive, action: onDecline)
        } message: {
            Text(t("requests.decline_message", ["name": ride.rider.displayName]))
        }
    }

    /// "Sat 1 Nov, 10:00 – 11:00 (60 min)"
    private var timeText: String {
        let start = ride.startsAt.localized(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
        let end = ride.endsAt.localized(date: .omitted, time: .shortened)
        return "\(start) – \(end) (\(durationLabel(ride.durationMinutes)))"
    }

    private var meetingText: String {
        if let address = ride.meetingPoint.address, !address.isEmpty {
            return "\(ride.meetingPoint.type.title): \(address)"
        }
        return ride.meetingPoint.type.title
    }
}

/// Compact row for a confirmed ride.
struct UpcomingRideRow: View {
    let ride: Ride

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text(ride.startsAt.localized(.dateTime.day()))
                    .font(.title2.weight(.bold))
                Text(ride.startsAt.localized(.dateTime.month(.abbreviated)))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.accentRed)
            }
            .frame(width: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(ride.car.name)
                    .font(.headline)
                Text("\(ride.rider.displayName) · \(ride.startsAt.localized(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            StatusChip(status: ride.status, isTimedOut: ride.isTimedOut)
        }
        .accessibilityElement(children: .combine)
    }
}
