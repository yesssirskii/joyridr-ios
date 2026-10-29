import Foundation

struct DriversService {
    var api: APIClient = .shared

    func profile(_ driverID: UUID) async throws -> PublicDriverProfile {
        try await api.get("/api/drivers/\(driverID.uuidString)")
    }

    func schedule(_ driverID: UUID) async throws -> WeeklySchedule {
        try await api.get("/api/drivers/\(driverID.uuidString)/schedule")
    }

    // MARK: Logged-in driver

    func myProfile() async throws -> DriverProfile {
        try await api.get("/api/drivers/me")
    }

    func updateMyProfile(_ request: UpdateDriverProfileRequest) async throws -> DriverProfile {
        try await api.put("/api/drivers/me", body: request)
    }

    func mySchedule() async throws -> WeeklySchedule {
        try await api.get("/api/drivers/me/schedule")
    }

    /// Replaces the whole week. Times are "HH:mm:ss" on a 30-minute grid, in the driver's time zone.
    func replaceMySchedule(_ windows: [WeeklySchedule.Window]) async throws -> WeeklySchedule {
        try await api.put("/api/drivers/me/schedule", body: UpdateWeeklyScheduleRequest(windows: windows))
    }

    /// Upcoming time off (blocks that haven't ended yet).
    func myTimeOff() async throws -> [TimeOff] {
        try await api.get("/api/drivers/me/time-off")
    }

    /// Fails with "time_off_clashes_with_rides" if rides are booked in that period.
    func addTimeOff(_ request: CreateTimeOffRequest) async throws -> TimeOff {
        try await api.post("/api/drivers/me/time-off", body: request)
    }

    func deleteTimeOff(_ id: UUID) async throws {
        try await api.delete("/api/drivers/me/time-off/\(id.uuidString)")
    }
}
