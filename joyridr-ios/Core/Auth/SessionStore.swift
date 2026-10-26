import Foundation
import Observation

/// Who's logged in. The root view switches between the login flow and the rider/driver app based on `state`.
@Observable
final class SessionStore {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(Me)
        /// We have tokens but couldn't reach the server at launch.
        case offline(String)
    }

    private(set) var state: State = .loading

    private let api: APIClient
    private let tokens: TokenStore

    init(api: APIClient = .shared, tokens: TokenStore = .shared) {
        self.api = api
        self.tokens = tokens
        api.onSessionExpired = { [weak self] in
            self?.state = .signedOut
        }
    }

    var me: Me? {
        if case let .signedIn(me) = state { return me }
        return nil
    }

    /// On launch: if we have saved tokens, load the user; otherwise show login.
    func restore() async {
        guard tokens.current != nil else {
            state = .signedOut
            await api.ping()
            return
        }
        state = .loading
        do {
            state = .signedIn(try await api.get("/api/me"))
        } catch APIError.cannotConnect {
            state = .offline(APIError.cannotConnect.localizedDescription)
        } catch {
            tokens.clear()
            state = .signedOut
        }
    }

    func login(email: String, password: String) async throws {
        let response: AuthResponse = try await api.post(
            "/api/auth/login", body: LoginRequest(email: email, password: password), authorized: false)
        try await finishSignIn(response)
    }

    func register(_ request: RegisterRequest) async throws {
        let response: AuthResponse = try await api.post("/api/auth/register", body: request, authorized: false)
        try await finishSignIn(response)
    }

    /// Reloads the user and profile, e.g. after editing them.
    func reloadMe() async {
        if let me: Me = try? await api.get("/api/me") {
            state = .signedIn(me)
        }
    }

    func logout() async {
        if let refreshToken = tokens.current?.refreshToken {
            try? await api.post("/api/auth/logout", body: RefreshRequest(refreshToken: refreshToken), authorized: false)
        }
        tokens.clear()
        state = .signedOut
    }

    private func finishSignIn(_ response: AuthResponse) async throws {
        tokens.save(response)
        state = .signedIn(try await api.get("/api/me"))
    }
}
