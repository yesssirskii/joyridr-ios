import Foundation

enum AppConfig {
    /// Where the backend runs. Pick the scheme next to the Run button:
    /// - **JOYRIDR Local**: the API on your Mac. The Simulator reaches it at `localhost`; a real iPhone
    ///   over Wi-Fi at the Mac's `.local` name.
    /// - **JOYRIDR Dev**: the Dev server on Railway. Release builds (TestFlight) use it too, for now.
    ///
    /// Each build configuration sets its address in `JOYRIDR_API_URL` (target › Build Settings › User-Defined),
    /// which Info.plist passes to the app as `JoyridrAPIURL`.
    /// A `JOYRIDR_API_URL` environment variable overrides it (only when started from Xcode or `simctl`).
    static let apiBaseURL: URL = {
        if let override = ProcessInfo.processInfo.environment["JOYRIDR_API_URL"], let url = URL(string: override) {
            return url
        }
        #if LOCAL && targetEnvironment(simulator)
        return URL(string: "http://localhost:5105")!   // the Simulator shares your Mac's network
        #else
        guard let value = Bundle.main.object(forInfoDictionaryKey: "JoyridrAPIURL") as? String,
              let url = URL(string: value) else {
            fatalError("JOYRIDR_API_URL isn't set for this build configuration.")
        }
        return url
        #endif
    }()

    /// Turns a server path like "/uploads/cars/1.jpg" into a full URL.
    static func url(for path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: path, relativeTo: apiBaseURL)
    }
}
