import SwiftUI

/// One booking in My rides, styled like the car rows in Explore.
struct RideRow: View {
    let ride: Ride
    /// "Rider → Driver" instead of just the driver, for the admin's All rides list.
    var showsRider = false

    var body: some View {
        HStack(spacing: 14) {
            RemoteImage(path: ride.car.photoUrl ?? ride.driver.avatarUrl)
                .frame(width: 64, height: 64)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(ride.car.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                HStack(spacing: 8) {
                    Text(showsRider ? "\(ride.rider.displayName) → \(ride.driver.displayName)" : ride.driver.displayName)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    StatusChip(status: ride.status, isTimedOut: ride.isTimedOut)
                }
                Text("\(ride.startsAt.localized(.dateTime.weekday(.abbreviated).day().month(.abbreviated))), \(ride.startsAt.localized(date: .omitted, time: .shortened)) · \(durationLabel(ride.durationMinutes)) · \(ride.price.price(ride.currency))")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 8)

            // The admin's All rides rows don't open anything yet, so they don't promise to.
            if !showsRider {
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
