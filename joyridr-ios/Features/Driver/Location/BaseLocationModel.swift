import CoreLocation
import Foundation
import Observation

/// Saves where a driver is based (riders find their cars around it) and how far they'll drive to pick riders up.
@Observable
final class BaseLocationModel {
    static let radiusOptions = [10, 25, 50, 100]

    private(set) var isLocating = false
    private(set) var isSaving = false
    var errorMessage: String?

    private let drivers: DriversService

    init(drivers: DriversService = DriversService()) {
        self.drivers = drivers
    }

    var isBusy: Bool { isLocating || isSaving }

    /// Moves the base to where the phone is now, with its town, street and time zone. True when saved.
    func useCurrentLocation(_ profile: DriverProfile) async -> Bool {
        errorMessage = nil
        isLocating = true
        let result = await LocationProvider.currentLocation()
        defer { isLocating = false }

        switch result {
        case .denied:
            errorMessage = t("base_location.error_denied")
            return false
        case .unavailable:
            errorMessage = t("base_location.error_unavailable")
            return false
        case let .found(coordinate):
            let place = await LocationProvider.place(at: coordinate)
            let base = UpdateDriverProfileRequest.Base(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                city: place?.city,
                address: place?.address,
                timeZoneId: TimeZone.current.identifier)
            return await save(UpdateDriverProfileRequest(profile, base: base))
        }
    }

    func setRadius(_ km: Int, _ profile: DriverProfile) async -> Bool {
        guard km != profile.serviceRadiusKm else { return false }
        errorMessage = nil
        return await save(UpdateDriverProfileRequest(profile, serviceRadiusKm: km))
    }

    private func save(_ request: UpdateDriverProfileRequest) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await drivers.updateMyProfile(request)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
