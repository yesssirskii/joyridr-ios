import CoreLocation
import Foundation
import Observation

/// Loads nearby cars for the Explore screen and keeps them sorted.
@Observable
final class ExploreModel {
    enum SortOption: String, CaseIterable, Identifiable {
        case distance = "Distance"
        case popularity = "Popularity"
        case rating = "Rating"
        case price = "Price"

        var id: Self { self }

        var title: String {
            switch self {
            case .distance: t("explore.sort.distance")
            case .popularity: t("explore.sort.popularity")
            case .rating: t("explore.sort.rating")
            case .price: t("explore.sort.price")
            }
        }

        var systemImage: String {
            switch self {
            case .distance: "location"
            case .popularity: "star.fill"
            case .rating: "hand.thumbsup.fill"
            case .price: "eurosign"
            }
        }
    }

    enum LoadState: Equatable {
        case idle, loading, loaded
        case failed(String)
        /// Location is off for JOYRIDR; nothing to search around until it's turned on in Settings.
        case locationOff
        /// Allowed, but no fix this time.
        case locationUnavailable
    }

    static let radiusOptions = [10, 30, 50, 100]

    private(set) var cars: [NearbyCar] = []
    private(set) var state: LoadState = .idle
    private(set) var locationName = t("explore.locating")
    private(set) var unreadMessages = 0
    var sort: SortOption = .distance {
        didSet { cars = sorted(cars) }
    }
    var radiusKm = 30

    private let carsService: CarsService
    private let chat: ChatService
    /// Where `locationName` was looked up, so small moves don't ask Apple Maps again.
    private var namedLocation: CLLocation?

    init(carsService: CarsService = CarsService(), chat: ChatService = ChatService()) {
        self.carsService = carsService
        self.chat = chat
    }

    var locationLabel: String { "\(locationName), \(radiusKm) km" }

    func loadIfNeeded() async {
        if state == .idle { await load() }
    }

    func load() async {
        if cars.isEmpty { state = .loading }
        await loadNearby()
        await loadUnreadCount()
    }

    private func loadNearby() async {
        switch await LocationProvider.currentLocation() {
        case .denied:
            cars = []
            locationName = t("explore.location_off_short")
            state = .locationOff
        case .unavailable:
            state = .locationUnavailable
        case let .found(coordinate):
            await updateLocationName(for: coordinate)
            do {
                cars = sorted(try await carsService.nearby(coordinate, radiusKm: radiusKm))
                state = .loaded
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    /// "Samobor" for the pill, looked up again only after moving more than a kilometre.
    private func updateLocationName(for coordinate: CLLocationCoordinate2D) async {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let namedLocation, namedLocation.distance(from: location) < 1_000 { return }
        locationName = await LocationProvider.place(at: coordinate)?.city ?? t("explore.near_you")
        namedLocation = location
    }

    func loadUnreadCount() async {
        if let count = try? await chat.unreadCount() {
            unreadMessages = count
        }
    }

    /// Sorting happens in the app for now (the backend always returns closest first).
    /// "Popularity" = most reviewed drivers, until we decide on a better definition.
    private func sorted(_ cars: [NearbyCar]) -> [NearbyCar] {
        switch sort {
        case .distance: cars.sorted { $0.distanceKm < $1.distanceKm }
        case .popularity: cars.sorted { $0.driver.ratingCount > $1.driver.ratingCount }
        case .rating: cars.sorted { $0.driver.ratingAverage > $1.driver.ratingAverage }
        case .price: cars.sorted { $0.car.pricePerHour < $1.car.pricePerHour }
        }
    }
}
