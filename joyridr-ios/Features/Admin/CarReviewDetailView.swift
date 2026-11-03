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
                        SpecTile(systemImage: "bolt.fill", value: "\(car.horsepower)", label: "hp")
                        SpecTile(systemImage: "gauge.with.dots.needle.67percent",
                                 value: car.zeroToHundredSeconds.map { "\($0.formatted()) s" } ?? "—", label: "0–100 km/h")
                        SpecTile(systemImage: "speedometer", value: car.topSpeedKmh.map { "\($0)" } ?? "—", label: "km/h top")
                        SpecTile(systemImage: "person.2.fill", value: "\(car.passengerSeats)", label: car.passengerSeats == 1 ? "seat" : "seats")
                        SpecTile(systemImage: "gearshift.layout.sixspeed", value: car.transmission.title, label: "gearbox")
                        SpecTile(systemImage: "eurosign", value: car.pricePerHour.price(car.currency), label: "per hour")
                    }

                    BookingSection("Listing") {
                        VStack(alignment: .leading, spacing: 14) {
                            LabeledValue(label: "License plate", value: car.licensePlate ?? "Not added")
                            LabeledValue(label: "Description", value: car.description.flatMap { $0.isEmpty ? nil : $0 } ?? "No description")
                        }
                    }

                    BookingSection("Driver") {
                        HStack(spacing: 14) {
                            RemoteImage(path: car.driver.avatarUrl, placeholder: "person.fill")
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(car.driver.displayName)
                                    .font(.headline)
                                Text([car.driver.city, car.driver.isVerified ? "Verified" : "Not verified yet"]
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
                    Text("Car review").displayTitle(18)
                }
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton { dismiss() }
                }
            }
            .animation(.snappy, value: model.errorMessage)
        }
        .onAppear { model.errorMessage = nil }
        .alert("Reject this car?", isPresented: $showReject) {
            TextField("Reason (optional)", text: $reason)
            Button("Reject car", role: .destructive) {
                Task { if await model.reject(car, reason: reason) { dismiss() } }
            }
            Button("Keep reviewing", role: .cancel) {}
        } message: {
            Text("\(car.driver.firstName) will see your reason and can update the car.")
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
                Button("Reject") {
                    reason = ""
                    showReject = true
                }
                .buttonStyle(.secondary)
                Button("Approve") {
                    Task { if await model.approve(car) { dismiss() } }
                }
                .buttonStyle(.primary(isLoading: isBusy))
            }
            .disabled(model.busyID != nil)
            Text(car.isActive
                 ? "Riders can book it as soon as you approve it."
                 : "The driver has hidden this car, so it stays out of Explore until they show it.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 30))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}
