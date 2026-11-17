import SwiftUI

/// "All drivers" (every car and who drives it), the admin's Drivers tab in place of Explore's nearby cars. Tapping a car opens the same review screen
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

/// "All rides", the admin's Rides tab in place of their own bookings: who booked whom, when, and how it went,
/// in whichever filter (upcoming, past, timed out) is selected at the top.
/// The rows don't open anything yet, because the ride screen is built for the rider (pay, cancel, review).
struct AllRidesSection: View {
    let model: AllRidesModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionTitle(title: title, subtitle: subtitle)

            GlowCard {
                content
            }
        }
    }

    private var title: String {
        switch model.view {
        case .past: t("admin.all_rides.past_title")
        case .timedOut: t("admin.all_rides.timed_out_title")
        default: t("admin.all_rides.upcoming_title")
        }
    }

    private var subtitle: String? {
        model.state == .loaded ? t("admin.all_rides.subtitle", count: model.totalCount) : nil
    }

    /// Same wording as the admin's own empty list above, since it's the same filter.
    private var emptyTitle: String {
        switch model.view {
        case .past: t("my_rides.past_empty")
        case .timedOut: t("my_rides.timed_out_empty")
        default: t("my_rides.upcoming_empty")
        }
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
                Button(t("common.try_again")) { Task { await model.load(model.view) } }
                    .buttonStyle(.primary)
                    .frame(width: 180)
            }
        case .loaded where model.rides.isEmpty:
            ContentUnavailableView(emptyTitle, systemImage: model.view == .timedOut ? "hourglass" : "car.side")
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
