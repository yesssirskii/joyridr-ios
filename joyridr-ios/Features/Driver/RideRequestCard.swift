import SwiftUI

/// A ride request the driver can confirm or decline.
struct RideRequestCard: View {
    let ride: Ride
    let isBusy: Bool
    let onConfirm: () -> Void
    let onDecline: () -> Void

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
                        Text(ride.rider.ratingCount == 0
                             ? "New rider"
                             : "★ \(ride.rider.ratingAverage.formatted(.number.precision(.fractionLength(1)))) · \(ride.rider.ratingCount) reviews")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Text(ride.price.price(ride.currency))
                        .font(.title3.weight(.bold))
                }

                Divider().overlay(.white.opacity(0.1))

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

                if let respondBy = ride.respondBy {
                    // A date with style: .relative counts down by itself.
                    Text("\(Image(systemName: "hourglass")) Respond within \(respondBy, style: .relative)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accentRed)
                }

                HStack(spacing: 12) {
                    Button("Decline") { confirmDecline = true }
                        .buttonStyle(.secondary)
                    Button("Confirm", action: onConfirm)
                        .buttonStyle(.primary(isLoading: isBusy))
                }
                .disabled(isBusy)
            }
        }
        .confirmationDialog("Decline this ride?", isPresented: $confirmDecline, titleVisibility: .visible) {
            Button("Decline ride", role: .destructive, action: onDecline)
        } message: {
            Text("\(ride.rider.displayName) won't be charged.")
        }
    }

    /// "Sat 1 Nov, 10:00 – 11:00 (60 min)"
    private var timeText: String {
        let start = ride.startsAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
        let end = ride.endsAt.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end) (\(ride.durationMinutes) min)"
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
                Text(ride.startsAt.formatted(.dateTime.day()))
                    .font(.title2.weight(.bold))
                Text(ride.startsAt.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.accentRed)
            }
            .frame(width: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(ride.car.name)
                    .font(.headline)
                Text("\(ride.rider.displayName) · \(ride.startsAt.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            StatusChip(status: ride.status)
        }
        .accessibilityElement(children: .combine)
    }
}
