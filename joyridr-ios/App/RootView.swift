import SwiftUI

/// Decides what to show: login, the rider app or the driver app.
struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        ZStack {
            switch session.state {
            case .loading:
                SplashView()
            case .signedOut:
                AuthFlowView()
            case let .offline(message):
                OfflineView(message: message) {
                    Task { await session.restore() }
                }
            case let .signedIn(me):
                if me.user.role == .joyDriver {
                    DriverHomeView()
                } else {
                    RiderHomeView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: session.state)
        .task { await session.restore() }
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            Theme.background
            RacingStripes()
            Text("JOYRIDR")
                .font(Theme.display(52))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal)
        }
        .ignoresSafeArea()
    }
}

private struct OfflineView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No connection", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try again", action: retry)
                .buttonStyle(.primary)
                .frame(width: 200)
        }
        .background(Theme.background)
    }
}
