import SwiftUI

/// One car in the Explore list: photo, "BMW M4 G82", driver + availability dot, price · distance · rating.
struct CarRow: View {
    let item: NearbyCar

    var body: some View {
        HStack(spacing: 14) {
            RemoteImage(path: item.car.photoUrl ?? item.driver.avatarUrl)
                .frame(width: 64, height: 64)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(item.car.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text(item.driver.displayName)
                    if item.isAvailableToday {
                        Circle()
                            .fill(Theme.available)
                            .frame(width: 8, height: 8)
                            .accessibilityLabel("Available today")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                Text(details)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "arrow.right")
                .font(.title3)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    /// "180 €/h · 2.3 km · ★ 4.9"
    private var details: String {
        let price = "\(item.car.pricePerHour.price(item.car.currency))/h"
        let distance = "\(item.distanceKm.formatted(.number.precision(.fractionLength(0...1)))) km"
        let rating = item.driver.ratingCount == 0
            ? "New"
            : "★ \(item.driver.ratingAverage.formatted(.number.precision(.fractionLength(1))))"
        return [price, distance, rating].joined(separator: " · ")
    }
}

extension NearbyCar {
    /// Fake row shown (blurred) while loading.
    static let placeholder = NearbyCar(
        car: CarSummary(id: UUID(), make: "Porsche", model: "911 GT3", year: 2023, color: "Blue", category: .sportsCar,
                        horsepower: 510, passengerSeats: 1, pricePerHour: 180, currency: "EUR", photoUrl: nil),
        driver: DriverSummary(id: UUID(), displayName: "Ivan K.", avatarUrl: nil, city: "Zagreb", isVerified: true,
                              ratingAverage: 4.9, ratingCount: 12),
        distanceKm: 2.3, approximateLatitude: 45.81, approximateLongitude: 15.98, isAvailableToday: true, nextAvailableAt: nil)
}

#Preview {
    CarRow(item: .placeholder)
        .padding()
        .background(.black)
}
