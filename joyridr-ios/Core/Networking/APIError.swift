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
        case let .server(_, message, code, fieldErrors):
            Self.serverMessage(message, code: code, fieldErrors: fieldErrors)
        case .cannotConnect:
            #if DEBUG
            t("errors.cannot_connect_debug", ["url": AppConfig.apiBaseURL.absoluteString])
            #else
            t("errors.cannot_connect")
            #endif
        case .sessionExpired:
            t("errors.session_expired")
        case .invalidResponse:
            t("errors.generic")
        }
    }

    /// The backend writes its messages in English. In English they're shown as they are (they're the most
    /// specific, e.g. with distances or limits); in another language the error code is looked up in
    /// `errors.server.<code>`, falling back to the English message for codes without a translation.
    private static func serverMessage(_ message: String, code: String?, fieldErrors: [String: [String]]) -> String {
        let localizer = Localizer.shared
        if localizer.language != .en {
            if let code, let translated = localizer.translation("errors.server.\(code)") { return translated }
            if !fieldErrors.isEmpty { return t("errors.validation") }
        }
        // For validation errors, the first field message is more useful than the generic title.
        return fieldErrors.values.first?.first ?? message
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
