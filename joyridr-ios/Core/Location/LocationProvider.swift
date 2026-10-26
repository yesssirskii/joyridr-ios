import CoreLocation

/// Gets the user's location once, for the nearby search.
enum LocationProvider {
    struct Result {
        let coordinate: CLLocationCoordinate2D
        /// True when we couldn't get the real location and fell back to Zagreb.
        let isFallback: Bool
    }

    static let fallback = CLLocationCoordinate2D(latitude: 45.8131, longitude: 15.9775) // Zagreb, Ban Jelačić Square

    /// Asks for permission the first time, then returns the current location.
    /// Falls back to Zagreb if permission is denied or it takes longer than a few seconds.
    static func currentLocation() async -> Result {
        // Give the user time to answer the permission prompt the first time.
        let timeout: Duration = CLLocationManager().authorizationStatus == .notDetermined ? .seconds(60) : .seconds(6)
        let coordinate = await withTaskGroup(of: CLLocationCoordinate2D?.self) { group in
            group.addTask { await firstLocation() }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        return coordinate.map { Result(coordinate: $0, isFallback: false) } ?? Result(coordinate: fallback, isFallback: true)
    }

    private static func firstLocation() async -> CLLocationCoordinate2D? {
        // Keeping a service session alive is what triggers the "Allow location?" prompt.
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if let location = update.location { return location.coordinate }
                if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted { return nil }
            }
        } catch {}
        return nil
    }
}
