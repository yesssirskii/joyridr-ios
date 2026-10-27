import Observation
import SwiftUI

/// Read-only details about the car and its driver, opened from the ⓘ button in the booking sheet.
struct CarInfoSheet: View {
    let carID: UUID
    let driverID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var model = CarInfoModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                switch model.state {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 240)
                case let .failed(message):
                    ContentUnavailableView("Couldn't load details", systemImage: "exclamationmark.triangle", description: Text(message))
                case let .loaded(car, driver):
                    content(car: car, driver: driver)
                }
            }
            .background { RedGlow().ignoresSafeArea() }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await model.load(carID: carID, driverID: driverID) }
    }

    private func content(car: CarDetail, driver: PublicDriverProfile) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            photos(car)

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

            if let description = car.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary.opacity(0.9))
            }

            SectionTitle(title: "Driver")
            driverCard(driver)

            if !driver.recentReviews.isEmpty {
                SectionTitle(title: "Reviews")
                VStack(spacing: 12) {
                    ForEach(driver.recentReviews.prefix(3)) { review in
                        ReviewRow(review: review)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.horizontalPadding)
        .padding(.bottom, 30)
    }

    @ViewBuilder
    private func photos(_ car: CarDetail) -> some View {
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

    private func driverCard(_ profile: PublicDriverProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                RemoteImage(path: profile.driver.avatarUrl, placeholder: "person.fill")
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(profile.driver.displayName)
                            .font(.headline)
                        if profile.driver.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Theme.accentRed)
                                .accessibilityLabel("Verified driver")
                        }
                    }
                    Text("\(profile.driver.ratingText) · \(profile.completedRides) rides")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Text([profile.driver.city, "Member since \(profile.memberSince.formatted(.dateTime.month(.abbreviated).year()))"]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .font(.subheadline)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

private struct SpecTile: View {
    let systemImage: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.accentRed)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 92)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

private struct ReviewRow: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(String(repeating: "★", count: review.rating) + String(repeating: "☆", count: 5 - review.rating))
                    .foregroundStyle(Theme.accentRed)
                    .accessibilityLabel("\(review.rating) out of 5 stars")
                Spacer()
                Text(review.createdAt.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(.subheadline)
            }
            Text(review.authorName)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }
}

/// Loads the car and the driver's public profile at the same time.
@Observable
final class CarInfoModel {
    enum State {
        case loading
        case loaded(CarDetail, PublicDriverProfile)
        case failed(String)
    }

    private(set) var state: State = .loading

    private let cars: CarsService
    private let drivers: DriversService

    init(cars: CarsService = CarsService(), drivers: DriversService = DriversService()) {
        self.cars = cars
        self.drivers = drivers
    }

    func load(carID: UUID, driverID: UUID) async {
        do {
            async let car = cars.car(carID)
            async let driver = drivers.profile(driverID)
            state = .loaded(try await car, try await driver)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
