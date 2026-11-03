import SwiftUI

/// Profile section where a driver sets their base location. Until it's set, riders can't find their cars.
struct BaseLocationSection: View {
    let driver: DriverProfile

    @Environment(SessionStore.self) private var session
    @State private var model = BaseLocationModel()

    var body: some View {
        BookingSection("Base location") {
            VStack(alignment: .leading, spacing: 14) {
                if driver.baseLatitude != nil {
                    LabeledValue(label: "Riders find your cars around", value: driver.baseAddress ?? driver.city ?? "Your saved location")
                } else {
                    Text("Not set yet. Riders can't find your cars until you add it.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("How far you'll drive to pick riders up")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    HStack(spacing: 8) {
                        ForEach(BaseLocationModel.radiusOptions, id: \.self) { km in
                            Button("\(km) km") {
                                Task { if await model.setRadius(km, driver) { await session.reloadMe() } }
                            }
                            .buttonStyle(ChipStyle(isSelected: driver.serviceRadiusKm == km, fillsWidth: true))
                        }
                    }
                }

                FormError(message: model.errorMessage)

                Button {
                    Task { if await model.useCurrentLocation(driver) { await session.reloadMe() } }
                } label: {
                    if model.isLocating {
                        ProgressView()
                    } else {
                        Label(driver.baseLatitude == nil ? "Use my current location" : "Move to my current location",
                              systemImage: "location.fill")
                    }
                }
                .buttonStyle(.primary)
            }
            .disabled(model.isBusy)
            .animation(.snappy, value: model.errorMessage)
        }
    }
}
