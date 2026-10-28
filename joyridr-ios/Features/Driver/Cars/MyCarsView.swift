import SwiftUI

/// Driver's "My cars" tab, built like Explore: header, glowing pills, the car list in a glow card.
/// The add/edit sheet zooms out of the pill or row that was tapped.
struct MyCarsView: View {
    /// Which car the editor sheet is open for.
    enum EditorTarget: Identifiable {
        case new
        case edit(CarDetail)

        var id: String {
            switch self {
            case .new: "new-car"
            case let .edit(car): car.id.uuidString
            }
        }
    }

    @State private var model = MyCarsModel()
    @State private var editor: EditorTarget?
    @State private var showProfile = false
    @State private var showChat = false
    @Namespace private var carTransition

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HomeHeader { showProfile = true }

                    HStack(spacing: 14) {
                        Button {
                            editor = .new
                        } label: {
                            FilterPill(systemImage: "plus.circle.fill", title: "Add car")
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: EditorTarget.new.id, in: carTransition)

                        Menu {
                            Picker("Show", selection: $model.filter) {
                                ForEach(MyCarsModel.Filter.allCases) { filter in
                                    Label(filter.rawValue, systemImage: filter.systemImage).tag(filter)
                                }
                            }
                        } label: {
                            FilterPill(systemImage: model.filter.systemImage, title: model.filter.rawValue, fillsWidth: false)
                        }
                    }

                    SectionTitle(title: "My cars", subtitle: model.summary)

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
                    RacingStripes(count: 4, lineWidth: 14, spacing: 36, startX: -0.15, length: 0.4)
                }
                .ignoresSafeArea()
            }
            .overlay(alignment: .bottomTrailing) {
                ChatButton(unreadCount: model.unreadMessages) { showChat = true }
                    .padding(Theme.horizontalPadding)
            }
            .refreshable { await model.load() }
            .task { await model.load() }
            .animation(.snappy, value: model.filter)
            .sheet(item: $editor, onDismiss: { Task { await model.load() } }) { target in
                CarEditorView(car: target.car)
                    .navigationTransition(.zoom(sourceID: target.id, in: carTransition))
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .sheet(isPresented: $showChat, onDismiss: { Task { await model.load() } }) {
                InboxView()
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
                Label("Couldn't load your cars", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { Task { await model.load() } }
                    .buttonStyle(.primary)
                    .frame(width: 180)
            }
        case .loaded where model.cars.isEmpty:
            ContentUnavailableView {
                Label("Your garage is empty", systemImage: "car.side")
            } description: {
                Text("Add your sports car or supercar. Our team reviews every car before JoyRiders can book it.")
            } actions: {
                Button("Add a car") { editor = .new }
                    .buttonStyle(.primary)
                    .frame(width: 180)
            }
        case .loaded where model.visibleCars.isEmpty:
            ContentUnavailableView("No \(model.filter.rawValue.lowercased()) cars", systemImage: model.filter.systemImage,
                                   description: Text("Pick another filter to see the rest of your garage."))
        case .loaded:
            LazyVStack(spacing: 6) {
                ForEach(model.visibleCars) { car in
                    Button {
                        editor = .edit(car)
                    } label: {
                        DriverCarRow(car: car)
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: car.id.uuidString, in: carTransition)
                }
            }
        }
    }
}

private extension MyCarsView.EditorTarget {
    var car: CarDetail? {
        if case let .edit(car) = self { return car }
        return nil
    }
}

/// One of the driver's cars, styled like the car rows in Explore.
struct DriverCarRow: View {
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
                HStack(spacing: 8) {
                    Text("\(String(car.year)) · \(car.color)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    CarStatusChip(car: car)
                }
                Text("\(car.pricePerHour.price(car.currency))/h · \(car.horsepower) hp · \(car.passengerSeats) \(car.passengerSeats == 1 ? "seat" : "seats")")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
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

/// Live / In review / Rejected / Hidden.
struct CarStatusChip: View {
    let car: CarDetail

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .fixedSize()
    }

    private var title: String {
        switch car.status {
        case .pendingReview: "In review"
        case .rejected: "Rejected"
        case .approved: car.isActive ? "Live" : "Hidden"
        }
    }

    private var color: Color {
        switch car.status {
        case .pendingReview: .orange
        case .rejected: Theme.accentRed
        case .approved: car.isActive ? Theme.available : Theme.textSecondary
        }
    }
}

#Preview {
    MyCarsView()
        .environment(SessionStore())
        .preferredColorScheme(.dark)
}
