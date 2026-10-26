import SwiftUI

/// Rider home: nearby cars, closest first.
struct ExploreView: View {
    @State private var model = ExploreModel()
    @State private var showProfile = false
    @State private var showChat = false

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
            .navigationDestination(for: NearbyCar.self) { item in
                ComingSoonView(title: item.car.name, message: "Car details and booking are coming next.", systemImage: "car.side.fill")
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .sheet(isPresented: $showChat) {
                ComingSoonView(title: "Messages", message: "Chat with drivers is coming soon.", systemImage: "bubble.left.and.bubble.right")
                    .presentationDetents([.medium])
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
                    NavigationLink(value: item) {
                        CarRow(item: item)
                    }
                    .buttonStyle(.plain)
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
