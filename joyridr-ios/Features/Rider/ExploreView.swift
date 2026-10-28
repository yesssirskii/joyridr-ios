import SwiftUI

/// Rider home: nearby cars, closest first.
struct ExploreView: View {
    @State private var model = ExploreModel()
    @State private var showProfile = false
    @State private var showChat = false
    /// The car whose booking sheet is open.
    @State private var selectedCar: NearbyCar?
    /// Ties each car row to its booking sheet, so the sheet zooms out of the row it was opened from.
    @Namespace private var rideTransition

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HomeHeader { showProfile = true }

                    HStack(spacing: 14) {
                        Menu {
                            Picker("Search radius", selection: $model.radiusKm) {
                                ForEach(ExploreModel.radiusOptions, id: \.self) { Text("\($0) km") }
                            }
                        } label: {
                            FilterPill(systemImage: "map", title: model.locationLabel)
                        }
                        Menu {
                            Picker("Sort by", selection: $model.sort) {
                                ForEach(ExploreModel.SortOption.allCases) { option in
                                    Label(option.rawValue, systemImage: option.systemImage).tag(option)
                                }
                            }
                        } label: {
                            FilterPill(systemImage: model.sort.systemImage, title: model.sort.rawValue, fillsWidth: false)
                        }
                    }

                    SectionTitle(title: "Available drivers", subtitle: "Choose your next ride")

                    GlowCard {
                        carList
                    }
                }
                .padding(.horizontal, Theme.horizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 90) // room for the chat button
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
            .task { await model.loadIfNeeded() }
            .onChange(of: model.radiusKm) {
                Task { await model.load() }
            }
            .sheet(item: $selectedCar, onDismiss: { Task { await model.load() } }) { item in
                NewRideView(car: item)
                    .navigationTransition(.zoom(sourceID: item.id, in: rideTransition))
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .sheet(isPresented: $showChat, onDismiss: { Task { await model.loadUnreadCount() } }) {
                InboxView()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var carList: some View {
        switch model.state {
        case .idle, .loading:
            VStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    CarRow(item: .placeholder)
                }
            }
            .redacted(reason: .placeholder)
        case let .failed(message):
            ContentUnavailableView {
                Label("Couldn't load cars", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { Task { await model.load() } }
                    .buttonStyle(.primary)
                    .frame(width: 180)
            }
        case .loaded where model.cars.isEmpty:
            ContentUnavailableView(
                "No cars nearby",
                systemImage: "car.side",
                description: Text("Try a bigger search radius."))
        case .loaded:
            LazyVStack(spacing: 6) {
                ForEach(model.cars) { item in
                    Button {
                        selectedCar = item
                    } label: {
                        CarRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: item.id, in: rideTransition)
                }
            }
        }
    }
}

#Preview {
    ExploreView()
        .environment(SessionStore())
        .preferredColorScheme(.dark)
}
