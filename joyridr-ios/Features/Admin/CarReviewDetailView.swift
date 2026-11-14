import SwiftUI

/// Everything a driver entered for one car, with Approve and Reject at the bottom.
/// Closes itself once the decision goes through.
struct CarReviewDetailView: View {
    let car: CarDetail
    let model: CarReviewsModel

    @Environment(\.dismiss) private var dismiss
    @State private var showReject = false
    /// Typed into the reject alert; the driver sees it.
    @State private var reason = ""

    private var isBusy: Bool { model.busyID == car.id }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    photos

                    VStack(alignment: .leading, spacing: 4) {
                        Text(car.name)
                            .displayTitle(22)
                        Text("\(String(car.year)) · \(car.color) · \(car.category.title)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        SpecTile(systemImage: "bolt.fill", value: "\(car.horsepower)", label: t("cars.spec.hp"))
                        SpecTile(systemImage: "gauge.with.dots.needle.67percent",
                                 value: car.zeroToHundredSeconds.map { "\($0.formatted(.number.locale(Localizer.shared.locale))) s" } ?? "—", label: t("cars.spec.zero_to_hundred"))
                        SpecTile(systemImage: "speedometer", value: car.topSpeedKmh.map { "\($0)" } ?? "—", label: t("cars.spec.top_speed"))
                        SpecTile(systemImage: "person.2.fill", value: "\(car.passengerSeats)", label: t("cars.spec.seats", count: car.passengerSeats))
                        SpecTile(systemImage: "gearshift.layout.sixspeed", value: car.transmission.title, label: t("cars.spec.gearbox"))
                        SpecTile(systemImage: "eurosign", value: car.pricePerHour.price(car.currency), label: t("cars.spec.per_hour"))
                    }

                    BookingSection(t("admin.cars.listing")) {
                        VStack(alignment: .leading, spacing: 14) {
                            LabeledValue(label: t("cars.editor.plate"), value: car.licensePlate ?? t("admin.cars.not_added"))
                            LabeledValue(label: t("admin.cars.description"), value: car.description.flatMap { $0.isEmpty ? nil : $0 } ?? t("admin.cars.no_description"))
                        }
                    }

                    BookingSection(t("booking.car_info.driver")) {
                        HStack(spacing: 14) {
                            RemoteImage(path: car.driver.avatarUrl, placeholder: "person.fill")
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(car.driver.displayName)
                                    .font(.headline)
                                Text([car.driver.city, car.driver.isVerified ? t("profile.verified") : t("profile.not_verified")]
                                    .compactMap(\.self).joined(separator: " · "))
                                    .font(.subheadline)
                                    .foregroundStyle(car.driver.isVerified ? Theme.textSecondary : .orange)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .background { RedGlow().ignoresSafeArea() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(t("admin.cars.title")).displayTitle(18)
                }
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton { dismiss() }
                }
            }
            .animation(.snappy, value: model.errorMessage)
        }
        .onAppear { model.errorMessage = nil }
        .alert(t("admin.cars.reject_title"), isPresented: $showReject) {
            TextField(t("ride.driver.reason"), text: $reason)
            Button(t("admin.cars.reject_car"), role: .destructive) {
                Task { if await model.reject(car, reason: reason) { dismiss() } }
            }
            Button(t("admin.cars.keep_reviewing"), role: .cancel) {}
        } message: {
            Text(t("admin.cars.reject_message", ["name": car.driver.firstName]))
        }
    }

    @ViewBuilder
    private var photos: some View {
        if car.photos.isEmpty {
            RemoteImage(path: nil)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        } else {
            TabView {
                ForEach(car.photos.sorted { $0.sortOrder < $1.sortOrder }) { photo in
                    RemoteImage(path: photo.url)
                }
            }
            .tabViewStyle(.page)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            FormError(message: model.errorMessage)
            HStack(spacing: 12) {
                Button(t("admin.cars.reject")) {
                    reason = ""
                    showReject = true
                }
                .buttonStyle(.secondary)
                Button(t("admin.cars.approve")) {
                    Task { if await model.approve(car) { dismiss() } }
                }
                .buttonStyle(.primary(isLoading: isBusy))
            }
            .disabled(model.busyID != nil)
            Text(car.isActive
                 ? t("admin.cars.approve_note")
                 : t("admin.cars.hidden_note"))
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}
