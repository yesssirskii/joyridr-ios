import Foundation
import Observation

/// The driver's garage: every car with its review status, plus the unread chat count.
@Observable
final class MyCarsModel {
    enum LoadState: Equatable {
        case loading, loaded
        case failed(String)
    }

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All cars"
        case live = "Live"
        case inReview = "In review"
        case rejected = "Rejected"
        case hidden = "Hidden"

        var id: Self { self }

        var systemImage: String {
            switch self {
            case .all: "car.2.fill"
            case .live: "checkmark.seal.fill"
            case .inReview: "hourglass"
            case .rejected: "xmark.seal.fill"
            case .hidden: "eye.slash.fill"
            }
        }

        func matches(_ car: CarDetail) -> Bool {
            switch self {
            case .all: true
            case .live: car.isLive
            case .inReview: car.status == .pendingReview
            case .rejected: car.status == .rejected
            case .hidden: car.status == .approved && !car.isActive
            }
        }
    }

    private(set) var cars: [CarDetail] = []
    private(set) var state: LoadState = .loading
    private(set) var unreadMessages = 0
    var filter: Filter = .all

    private let carsService: CarsService
    private let chat: ChatService

    init(carsService: CarsService = CarsService(), chat: ChatService = ChatService()) {
        self.carsService = carsService
        self.chat = chat
    }

    var visibleCars: [CarDetail] { cars.filter(filter.matches) }

    /// "3 cars · 2 live"
    var summary: String {
        guard !cars.isEmpty else { return "Add your first car" }
        let live = cars.filter(\.isLive).count
        return "\(cars.count) \(cars.count == 1 ? "car" : "cars") · \(live) live"
    }

    func load() async {
        do {
            cars = try await carsService.myCars()
            state = .loaded
        } catch {
            if Task.isCancelled { return }
            if cars.isEmpty { state = .failed(error.localizedDescription) }
        }
        if let count = try? await chat.unreadCount() {
            unreadMessages = count
        }
    }
}
