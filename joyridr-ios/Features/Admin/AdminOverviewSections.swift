import SwiftUI

/// "All cars" under Explore's list, for admins only. Tapping a car opens the same review screen
/// as the Reviews tab, so an admin can also reject a live car or approve a rejected one from here.
struct AllCarsSection: View {
    let model: AllCarsModel

    @State private var reviews = CarReviewsModel()
    @State private var selectedCar: CarDetail?
    @Namespace private var carTransition

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionTitle(title: t("admin.all_cars.title"), subtitle: subtitle)

            GlowCard {
                content
            }
        }
        .sheet(item: $selectedCar, onDismiss: { Task { await model.load() } }) { car in
            CarReviewDetailView(car: car, model: reviews)
                .navigationTransition(.zoom(sourceID: car.id, in: carTransition))
        }
    }

    private var subtitle: String? {
        model.state == .loaded ? t("admin.all_cars.subtitle", count: model.cars.count) : nil
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        case let .failed(message):
            ContentUnavailableView {
                Label(t("admin.all_cars.load_failed"), systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button(t("common.try_again")) { Task { await model.load() } }
                    .buttonStyle(.primary)
                    .frame(width: 180)
            }
        case .loaded where model.cars.isEmpty:
            ContentUnavailableView(t("admin.all_cars.empty"), systemImage: "car.side")
        case .loaded:
            LazyVStack(spacing: 6) {
                ForEach(model.cars) { car in
                    Button {
                        selectedCar = car
                    } label: {
                        CarReviewRow(car: car, showsStatus: true)
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: car.id, in: carTransition)
                }
            }
        }
    }
}

/// "All rides" under My rides' upcoming list, for admins only: who booked whom, when, and how it went.
/// The rows don't open anything yet, because the ride screen is built for the rider (pay, cancel, review).
struct AllRidesSection: View {
    let model: AllRidesModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionTitle(title: t("admin.all_rides.title"), subtitle: subtitle)

            GlowCard {
                content
            }
        }
    }

    private var subtitle: String? {
        model.state == .loaded ? t("admin.all_rides.subtitle", count: model.totalCount) : nil
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        case let .failed(message):
            ContentUnavailableView {
                Label(t("admin.all_rides.load_failed"), systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button(t("common.try_again")) { Task { await model.load() } }
                    .buttonStyle(.primary)
                    .frame(width: 180)
            }
        case .loaded where model.rides.isEmpty:
            ContentUnavailableView(t("admin.all_rides.empty"), systemImage: "car.side")
        case .loaded:
            LazyVStack(spacing: 6) {
                ForEach(model.rides) { ride in
                    RideRow(ride: ride, showsRider: true)
                }
                if model.hasMore {
                    Button(t("common.show_more")) { Task { await model.loadMore() } }
                        .buttonStyle(.secondary)
                        .disabled(model.isLoadingMore)
                        .padding(.top, 8)
                }
            }
        }
    }
}
