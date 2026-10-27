import Foundation

struct DriversService {
    var api: APIClient = .shared

    func profile(_ driverID: UUID) async throws -> PublicDriverProfile {
        try await api.get("/api/drivers/\(driverID.uuidString)")
    }

    func schedule(_ driverID: UUID) async throws -> WeeklySchedule {
        try await api.get("/api/drivers/\(driverID.uuidString)/schedule")
    }
}
