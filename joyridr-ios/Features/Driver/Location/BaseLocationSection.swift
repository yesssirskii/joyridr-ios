import SwiftUI

/// Profile section where a driver sets their base location. Until it's set, riders can't find their cars.
struct BaseLocationSection: View {
    let driver: DriverProfile

    @Environment(SessionStore.self) private var session
    @State private var model = BaseLocationModel()

    var body: some View {
        BookingSection(t("base_location.title")) {
            VStack(alignment: .leading, spacing: 14) {
                if driver.baseLatitude != nil {
                    LabeledValue(label: t("base_location.label"), value: driver.baseAddress ?? driver.city ?? t("base_location.saved"))
                } else {
                    Text(t("base_location.not_set"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(t("base_location.radius"))
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
                        Label(driver.baseLatitude == nil ? t("base_location.use_current") : t("base_location.move_current"),
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
