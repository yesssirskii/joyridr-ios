import CoreLocation
import MapKit

/// Gets the phone's location once: for the nearby search, a pickup point, or a driver's base location.
enum LocationProvider {
    enum Result {
        case found(CLLocationCoordinate2D)
        /// Location is off for JOYRIDR (or the whole phone). Only the Settings app can change that.
        case denied
        /// Allowed, but no fix in time (no signal, airplane mode). Worth trying again.
        case unavailable
    }

    /// A coordinate in words, from Apple Maps.
    struct Place {
        /// "Samobor"
        let city: String?
        /// "Trg kralja Tomislava 5, Samobor"
        let address: String?
    }

    /// Asks for permission the first time, then returns the current location.
    static func currentLocation() async -> Result {
        // Give the user time to answer the permission prompt the first time.
        let timeout: Duration = CLLocationManager().authorizationStatus == .notDetermined ? .seconds(60) : .seconds(10)
        return await withTaskGroup(of: Result.self) { group in
            group.addTask { await firstLocation() }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return .unavailable
            }
            let first = await group.next() ?? .unavailable
            group.cancelAll()
            return first
        }
    }

    /// The town and street at a coordinate, or nil if Apple Maps can't tell (or there's no connection).
    static func place(at coordinate: CLLocationCoordinate2D) async -> Place? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first else { return nil }
        return Place(city: item.addressRepresentations?.cityName,
                     address: item.address?.shortAddress ?? item.address?.fullAddress)
    }

    private static func firstLocation() async -> Result {
        // Keeping a service session alive is what triggers the "Allow location?" prompt.
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if let location = update.location { return .found(location.coordinate) }
                if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted { return .denied }
            }
        } catch {}
        return .unavailable
    }
}
