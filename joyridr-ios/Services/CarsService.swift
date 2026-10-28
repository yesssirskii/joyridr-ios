import CoreLocation
import Foundation

struct CarsService {
    var api: APIClient = .shared

    func nearby(_ coordinate: CLLocationCoordinate2D, radiusKm: Int) async throws -> [NearbyCar] {
        let page: Page<NearbyCar> = try await api.get("/api/cars/nearby", query: [
            "latitude": String(coordinate.latitude),
            "longitude": String(coordinate.longitude),
            "radiusKm": String(radiusKm),
            "pageSize": "50",
        ])
        return page.items
    }

    func car(_ id: UUID) async throws -> CarDetail {
        try await api.get("/api/cars/\(id.uuidString)")
    }

    // MARK: Driver: my cars

    /// All of the logged-in driver's cars, including ones waiting for review.
    func myCars() async throws -> [CarDetail] {
        try await api.get("/api/drivers/me/cars")
    }

    /// Adds a car. It starts as "pending review" until an admin approves it.
    func create(_ request: UpsertCarRequest) async throws -> CarDetail {
        try await api.post("/api/cars", body: request)
    }

    /// Changing make, model, year or category sends the car back for review.
    func update(_ carID: UUID, _ request: UpsertCarRequest) async throws -> CarDetail {
        try await api.put("/api/cars/\(carID.uuidString)", body: request)
    }

    /// Fails with "car_has_rides" while the car has upcoming rides.
    func delete(_ carID: UUID) async throws {
        try await api.delete("/api/cars/\(carID.uuidString)")
    }

    /// Uploads one JPEG. The first photo becomes the cover.
    func uploadPhoto(_ carID: UUID, jpeg: Data) async throws -> CarPhoto {
        try await api.upload("/api/cars/\(carID.uuidString)/photos", data: jpeg, fileName: "photo.jpg", mimeType: "image/jpeg")
    }

    func deletePhoto(_ carID: UUID, photoID: UUID) async throws {
        try await api.delete("/api/cars/\(carID.uuidString)/photos/\(photoID.uuidString)")
    }

    // MARK: Booking

    /// `date` is "yyyy-MM-dd" in the driver's time zone.
    func slots(carID: UUID, date: String, durationMinutes: Int) async throws -> SlotsResponse {
        try await api.get("/api/cars/\(carID.uuidString)/slots", query: [
            "date": date,
            "durationMinutes": String(durationMinutes),
        ])
    }
}
