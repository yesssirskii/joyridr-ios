import Foundation

nonisolated enum CarCategory: String, Codable, Hashable, CaseIterable {
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
    /// "Ivan K." (first name + last initial).
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

nonisolated enum Transmission: String, Codable, Hashable, CaseIterable {
    case manual, automatic

    var title: String { self == .manual ? "Manual" : "Automatic" }
}

nonisolated struct CarPhoto: Codable, Hashable, Identifiable {
    let id: UUID
    let url: String
    let sortOrder: Int
}

/// `GET /api/cars/{id}`: everything about one car.
nonisolated struct CarDetail: Codable, Hashable, Identifiable {
    let id: UUID
    let make: String
    let model: String
    let year: Int
    let color: String
    let category: CarCategory
    let transmission: Transmission
    let horsepower: Int
    let zeroToHundredSeconds: Decimal?
    let topSpeedKmh: Int?
    let passengerSeats: Int
    let description: String?
    let pricePerHour: Decimal
    let currency: String
    let photos: [CarPhoto]
    let driver: DriverSummary
    /// Every car is reviewed by an admin before riders can see it.
    let status: CarStatus
    /// The driver can hide a car from search without deleting it.
    let isActive: Bool
    /// Only sent to the car's owner.
    let licensePlate: String?
    /// Only sent to the car's owner, when an admin rejected the car.
    let rejectionReason: String?

    var name: String { "\(make) \(model)" }

    /// Approved and not hidden: riders can find and book it.
    var isLive: Bool { status == .approved && isActive }

    var coverPhotoUrl: String? { photos.min { $0.sortOrder < $1.sortOrder }?.url }
}

nonisolated enum CarStatus: String, Codable, Hashable {
    case pendingReview, approved, rejected
}

/// Body of `POST /api/cars` and `PUT /api/cars/{id}`.
nonisolated struct UpsertCarRequest: Encodable {
    let make: String
    let model: String
    let year: Int
    let color: String
    let category: CarCategory
    let transmission: Transmission
    let horsepower: Int
    let zeroToHundredSeconds: Decimal?
    let topSpeedKmh: Int?
    let passengerSeats: Int
    let description: String?
    let licensePlate: String?
    let pricePerHour: Decimal
    let currency: String
    let isActive: Bool
}

extension CarCategory {
    var title: String {
        switch self {
        case .sportsCar: "Sports car"
        case .supercar: "Supercar"
        case .hypercar: "Hypercar"
        }
    }
}

extension DriverSummary {
    /// "Ivan" from "Ivan K.".
    var firstName: String { displayName.split(separator: " ").first.map(String.init) ?? displayName }

    /// "★ 4.9 (12)", or "New" when there are no reviews yet.
    var ratingText: String {
        ratingCount == 0 ? "New" : "★ \(ratingAverage.formatted(.number.precision(.fractionLength(1)))) (\(ratingCount))"
    }
}
