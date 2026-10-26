import Foundation

enum AppConfig {
    /// Where the backend runs. The Simulator reaches your Mac's `localhost` directly.
    /// Override it without changing code by adding a `JOYRIDR_API_URL` environment variable to the scheme
    /// (Product › Scheme › Edit Scheme › Run › Arguments). A real iPhone needs your Mac's network address.
    static let apiBaseURL: URL = {
        if let override = ProcessInfo.processInfo.environment["JOYRIDR_API_URL"], let url = URL(string: override) {
            return url
        }
        return URL(string: "http://localhost:5105")!
    }()

    /// Turns a server path like "/uploads/cars/1.jpg" into a full URL.
    static func url(for path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: path, relativeTo: apiBaseURL)
    }
}
