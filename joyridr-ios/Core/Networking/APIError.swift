import Foundation

/// Everything that can go wrong when talking to the backend, with messages you can show to the user.
enum APIError: LocalizedError {
    /// The server answered with an error (4xx/5xx). `code` is the backend's machine-readable code,
    /// e.g. "invalid_credentials" or "slot_unavailable".
    case server(status: Int, message: String, code: String?, fieldErrors: [String: [String]])
    case cannotConnect
    case sessionExpired
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case let .server(_, message, _, fieldErrors):
            // For validation errors, the first field message is more useful than the generic title.
            fieldErrors.values.first?.first ?? message
        case .cannotConnect:
            #if DEBUG
            "Can't reach the JOYRIDR server at \(AppConfig.apiBaseURL.absoluteString). Is the API running, and are your iPhone and Mac on the same Wi-Fi?"
            #else
            "Can't reach the JOYRIDR server. Check your internet connection."
            #endif
        case .sessionExpired:
            "Your session has expired. Please log in again."
        case .invalidResponse:
            "Something went wrong. Please try again."
        }
    }

    var code: String? {
        if case let .server(_, _, code, _) = self { return code }
        return nil
    }
}

/// The backend's error body (RFC 7807 ProblemDetails).
nonisolated struct ProblemDetails: Decodable {
    let title: String?
    let status: Int?
    let code: String?
    let errors: [String: [String]]?
}
