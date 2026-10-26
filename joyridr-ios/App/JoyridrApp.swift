import SwiftUI

@main
struct JoyridrApp: App {
    /// Created once and shared with every screen through the environment.
    @State private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .preferredColorScheme(.dark)   // the app is designed dark-only for now
                .tint(Theme.accentRed)
        }
    }
}
