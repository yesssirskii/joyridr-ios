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
        // Dates, times and system controls (pickers, relative times) follow the app's language.
        .environment(\.locale, Localizer.shared.locale)
        .task {
            async let warmup: Void = KeyboardWarmup.run()
            await session.restore()
            await warmup
        }
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
            Label(t("app.offline.title"), systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button(t("common.try_again"), action: retry)
                .buttonStyle(.primary)
                .frame(width: 200)
        }
        .background(Theme.background)
    }
}
