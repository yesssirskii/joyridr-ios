import Foundation

nonisolated enum CarCategory: String, Codable, Hashable {
    case sportsCar, supercar, hypercar
}

nonisolated struct CarSummary: Codable, Hashable, Identifiable {
    let id: UUID
    let make: String
    let model: String
    let year: Int
    let color: String
    let category: CarCategory
    let horsepower: Int
    let passengerSeats: Int
    let pricePerHour: Decimal
    let currency: String
    let photoUrl: String?

    var name: String { "\(make) \(model)" }
}

nonisolated struct DriverSummary: Codable, Hashable, Identifiable {
    let id: UUID
    let displayName: String
    let avatarUrl: String?
    let city: String?
    let isVerified: Bool
    let ratingAverage: Double
    let ratingCount: Int
}

/// One row of `GET /api/cars/nearby` (one per car).
nonisolated struct NearbyCar: Codable, Hashable, Identifiable {
    let car: CarSummary
    let driver: DriverSummary
    let distanceKm: Double
    let approximateLatitude: Double
    let approximateLongitude: Double
    let isAvailableToday: Bool
    let nextAvailableAt: Date?

    var id: UUID { car.id }
}

nonisolated struct Page<Item: Decodable>: Decodable {
    let items: [Item]
    let page: Int
    let pageSize: Int
    let totalCount: Int
    let hasMore: Bool
}
