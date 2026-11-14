import SwiftUI

/// Rider home: nearby cars, closest first.
struct ExploreView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = ExploreModel()
    @State private var showChat = false
    /// The car whose booking sheet is open.
    @State private var selectedCar: NearbyCar?
    /// Ties each car row to its booking sheet, so the sheet zooms out of the row it was opened from.
    @Namespace private var rideTransition

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HomeHeader()

                    HStack(spacing: 14) {
                        Menu {
                            Picker(t("explore.radius"), selection: $model.radiusKm) {
                                ForEach(ExploreModel.radiusOptions, id: \.self) { Text("\($0) km") }
                            }
                        } label: {
                            FilterPill(systemImage: "map", title: model.locationLabel)
                        }
                        Menu {
                            Picker(t("explore.sort_by"), selection: $model.sort) {
                                ForEach(ExploreModel.SortOption.allCases) { option in
                                    Label(option.title, systemImage: option.systemImage).tag(option)
                                }
                            }
                        } label: {
                            FilterPill(systemImage: model.sort.systemImage, title: model.sort.title, fillsWidth: false)
                        }
                    }

                    SectionTitle(title: t("explore.title"), subtitle: t("explore.subtitle"))

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
                    RacingStripes(count: 4, lineWidth: 14, spacing: 36, startX: -0.15)
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
            // Coming back from Settings with location turned on.
            .onChange(of: scenePhase) {
                if scenePhase == .active, model.state == .locationOff {
                    Task { await model.load() }
                }
            }
            .sheet(item: $selectedCar, onDismiss: { Task { await model.load() } }) { item in
                NewRideView(car: item)
                    .navigationTransition(.zoom(sourceID: item.id, in: rideTransition))
            }
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
                Label(t("explore.load_failed"), systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button(t("common.try_again")) { Task { await model.load() } }
                    .buttonStyle(.primary)
                    .frame(width: 180)
            }
        case .locationOff:
            ContentUnavailableView {
                Label(t("explore.location_off"), systemImage: "location.slash")
            } description: {
                Text(t("explore.location_off_message"))
            } actions: {
                Button(t("common.open_settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.primary)
                .frame(width: 180)
            }
        case .locationUnavailable:
            ContentUnavailableView {
                Label(t("explore.location_unavailable"), systemImage: "location.magnifyingglass")
            } description: {
                Text(t("explore.location_unavailable_message"))
            } actions: {
                Button(t("common.try_again")) { Task { await model.load() } }
                    .buttonStyle(.primary)
                    .frame(width: 180)
            }
        case .loaded where model.cars.isEmpty:
            ContentUnavailableView(
                t("explore.empty"),
                systemImage: "car.side",
                description: Text(t("explore.empty_message")))
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
