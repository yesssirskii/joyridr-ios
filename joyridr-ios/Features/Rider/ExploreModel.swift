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
    }

    static let radiusOptions = [10, 30, 50, 100]

    private(set) var cars: [NearbyCar] = []
    private(set) var state: LoadState = .idle
    private(set) var locationName = "Locating…"
    private(set) var unreadMessages = 0
    var sort: SortOption = .distance {
        didSet { cars = sorted(cars) }
    }
    var radiusKm = 30

    private let carsService: CarsService
    private let chat: ChatService

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

        let location = await LocationProvider.currentLocation()
        locationName = location.isFallback ? "Zagreb" : "Near you"

        do {
            cars = sorted(try await carsService.nearby(location.coordinate, radiusKm: radiusKm))
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }

        await loadUnreadCount()
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
