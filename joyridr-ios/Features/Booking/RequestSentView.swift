import SwiftUI

/// Shown in the booking sheet after the request went through.
struct RequestSentView: View {
    let ride: Ride
    let timeZone: TimeZone
    let onDone: () -> Void
    var onViewRides: (() -> Void)?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            RacingStripes().ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()
                Image(systemName: "flag.checkered")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(26)
                    .glassEffect(.regular, in: Circle())

                Text("Request sent!")
                    .displayTitle(26)

                Text(waitingText)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                GlowCard {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledValue(label: "Car", value: "\(ride.car.name) with \(ride.driver.displayName)")
                        LabeledValue(label: "When", value: whenText)
                        LabeledValue(label: "Meeting point", value: meetingText)
                        LabeledValue(label: "Price", value: ride.price.price(ride.currency))
                    }
                }

                Spacer()
                VStack(spacing: 12) {
                    Button("Done", action: onDone)
                        .buttonStyle(.primary)
                    if let onViewRides {
                        Button("See it in My rides", action: onViewRides)
                            .buttonStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, Theme.horizontalPadding)
            .padding(.bottom, 12)
        }
    }

    private func format(_ date: Date, _ style: Date.FormatStyle) -> String {
        var style = style
        style.timeZone = timeZone
        return date.formatted(style)
    }

    private var waitingText: String {
        guard let respondBy = ride.respondBy else { return "We'll let you know when the driver responds." }
        return "\(ride.driver.displayName) has until \(format(respondBy, .dateTime.weekday(.abbreviated).hour().minute())) to confirm. You won't be charged until then."
    }

    private var whenText: String {
        "\(format(ride.startsAt, .dateTime.weekday(.wide).day().month(.wide))), \(format(ride.startsAt, .dateTime.hour().minute()))–\(format(ride.endsAt, .dateTime.hour().minute()))"
    }

    private var meetingText: String {
        let driver = ride.driver.displayName.split(separator: " ").first.map(String.init) ?? ride.driver.displayName
        let title = ride.meetingPoint.type.riderTitle(driver: driver)
        if let address = ride.meetingPoint.address, !address.isEmpty {
            return "\(title): \(address)"
        }
        return title
    }
}
