import SwiftUI

/// Admin-only "Reviews" tab: cars waiting for approval, built like My cars.
/// Tapping a car zooms into its details, where the admin approves or rejects it.
struct CarReviewsView: View {
    @State private var model = CarReviewsModel()
    @State private var selectedCar: CarDetail?
    @Namespace private var carTransition

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HomeHeader()

                    SectionTitle(title: "Car reviews", subtitle: model.summary)

                    GlowCard {
                        carList
                    }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 90)
            }
            .background {
                ZStack(alignment: .top) {
                    Theme.background
                    RacingStripes(count: 4, lineWidth: 14, spacing: 36, startX: -0.15)
                }
                .ignoresSafeArea()
            }
            .refreshable { await model.load() }
            .task { await model.load() }
            .animation(.snappy, value: model.cars)
            .sheet(item: $selectedCar) { car in
                CarReviewDetailView(car: car, model: model)
                    .navigationTransition(.zoom(sourceID: car.id, in: carTransition))
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var carList: some View {
        switch model.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 160)
        case let .failed(message):
            ContentUnavailableView {
                Label("Couldn't load the review queue", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { Task { await model.load() } }
                    .buttonStyle(.primary)
                    .frame(width: 180)
            }
        case .loaded where model.cars.isEmpty:
            ContentUnavailableView("All caught up", systemImage: "checkmark.seal",
                                   description: Text("New cars from drivers show up here for review."))
        case .loaded:
            LazyVStack(spacing: 6) {
                ForEach(model.cars) { car in
                    Button {
                        selectedCar = car
                    } label: {
                        CarReviewRow(car: car)
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: car.id, in: carTransition)
                }
            }
        }
    }
}

/// One car in the review queue: photo, name and who submitted it.
struct CarReviewRow: View {
    let car: CarDetail

    var body: some View {
        HStack(spacing: 14) {
            RemoteImage(path: car.coverPhotoUrl)
                .frame(width: 64, height: 64)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(car.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(String(car.year)) · \(car.color) · \(car.category.title)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Text("by \(car.driver.displayName) · \(car.pricePerHour.price(car.currency))/h")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "arrow.right")
                .font(.title3)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
