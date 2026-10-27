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

    /// `date` is "yyyy-MM-dd" in the driver's time zone.
    func slots(carID: UUID, date: String, durationMinutes: Int) async throws -> SlotsResponse {
        try await api.get("/api/cars/\(carID.uuidString)/slots", query: [
            "date": date,
            "durationMinutes": String(durationMinutes),
        ])
    }
}
