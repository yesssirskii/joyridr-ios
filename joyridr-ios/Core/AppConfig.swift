import Foundation

enum AppConfig {
    /// Where the backend runs, in this order:
    /// 1. A `JOYRIDR_API_URL` environment variable in the scheme (only applies when started from Xcode).
    /// 2. Simulator: `localhost`, because the Simulator shares your Mac's network.
    /// 3. Real iPhone: the `JOYRIDR_API_URL` build setting (your Mac's `.local` name), which reaches the
    ///    Mac over Wi-Fi. Change it under target › Build Settings › User-Defined if you use another Mac.
    static let apiBaseURL: URL = {
        if let override = ProcessInfo.processInfo.environment["JOYRIDR_API_URL"], let url = URL(string: override) {
            return url
        }
        #if !targetEnvironment(simulator)
        if let value = Bundle.main.object(forInfoDictionaryKey: "JoyridrAPIURL") as? String,
           !value.isEmpty, !value.hasPrefix("$("), let url = URL(string: value) {
            return url
        }
        #endif
        return URL(string: "http://localhost:5105")!
    }()

    /// Turns a server path like "/uploads/cars/1.jpg" into a full URL.
    static func url(for path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: path, relativeTo: apiBaseURL)
    }
}
