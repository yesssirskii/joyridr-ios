import SwiftUI

/// One booking in My rides, styled like the car rows in Explore.
struct RideRow: View {
    let ride: Ride

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
                    Text(ride.driver.displayName)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    StatusChip(status: ride.status)
                }
                Text("\(ride.startsAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))), \(ride.startsAt.formatted(date: .omitted, time: .shortened)) · \(durationLabel(ride.durationMinutes)) · \(ride.price.price(ride.currency))")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 8)

            Image(systemName: "arrow.right")
                .font(.title3)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
