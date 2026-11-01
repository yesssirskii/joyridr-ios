import Foundation
import Observation

/// The admin's review queue: cars drivers added that aren't listed yet.
/// Approving or rejecting a car takes it off the list.
@Observable
final class CarReviewsModel {
    enum LoadState: Equatable {
        case loading, loaded
        case failed(String)
    }

    private(set) var cars: [CarDetail] = []
    private(set) var state: LoadState = .loading
    /// The car being approved or rejected, so its buttons show a spinner.
    private(set) var busyID: CarDetail.ID?
    var errorMessage: String?

    private let admin: AdminService

    init(admin: AdminService = AdminService()) {
        self.admin = admin
    }

    /// "3 cars waiting" / "Nothing to review"
    var summary: String {
        switch cars.count {
        case 0: "Nothing to review"
        case 1: "1 car waiting"
        default: "\(cars.count) cars waiting"
        }
    }

    func load() async {
        do {
            cars = try await admin.pendingCars()
            state = .loaded
        } catch {
            if Task.isCancelled { return }
            if cars.isEmpty { state = .failed(error.localizedDescription) }
        }
    }

    /// Returns true when it worked, so the detail sheet knows to close.
    func approve(_ car: CarDetail) async -> Bool {
        await decide(car) { try await $0.approve(car.id) }
    }

    func reject(_ car: CarDetail, reason: String) async -> Bool {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        return await decide(car) { try await $0.reject(car.id, reason: trimmed.isEmpty ? nil : trimmed) }
    }

    private func decide(_ car: CarDetail, _ call: (AdminService) async throws -> CarDetail) async -> Bool {
        guard busyID == nil else { return false }
        busyID = car.id
        errorMessage = nil
        defer { busyID = nil }
        do {
            _ = try await call(admin)
            cars.removeAll { $0.id == car.id }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
