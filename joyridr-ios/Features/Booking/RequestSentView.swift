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

                Text(t("booking.sent.title"))
                    .displayTitle(26)

                Text(waitingText)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                GlowCard {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledValue(label: t("booking.sent.car"), value: t("booking.sent.car_with", ["car": ride.car.name, "driver": ride.driver.displayName]))
                        LabeledValue(label: t("ride.when"), value: whenText)
                        LabeledValue(label: t("ride.meeting_point"), value: meetingText)
                        LabeledValue(label: t("ride.price"), value: ride.price.price(ride.currency))
                    }
                }

                Spacer()
                VStack(spacing: 12) {
                    Button(t("common.done"), action: onDone)
                        .buttonStyle(.primary)
                    if let onViewRides {
                        Button(t("booking.sent.see_rides"), action: onViewRides)
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
        return date.localized(style)
    }

    private var waitingText: String {
        guard let respondBy = ride.respondBy else { return t("booking.sent.waiting_unknown") }
        return t("ride.rider.waiting_until", ["driver": ride.driver.displayName, "time": format(respondBy, .dateTime.weekday(.abbreviated).hour().minute())])
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
