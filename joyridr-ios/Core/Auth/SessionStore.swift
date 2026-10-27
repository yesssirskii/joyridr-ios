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
    private let auth: AuthService
    private let tokens: TokenStore

    init(api: APIClient = .shared, tokens: TokenStore = .shared) {
        self.api = api
        self.auth = AuthService(api: api)
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
            state = .signedIn(try await auth.me())
        } catch APIError.cannotConnect {
            state = .offline(APIError.cannotConnect.localizedDescription)
        } catch {
            tokens.clear()
            state = .signedOut
        }
    }

    func login(email: String, password: String) async throws {
        try await finishSignIn(auth.login(email: email, password: password))
    }

    func register(_ request: RegisterRequest) async throws {
        try await finishSignIn(auth.register(request))
    }

    /// Reloads the user and profile, e.g. after editing them.
    func reloadMe() async {
        if let me = try? await auth.me() {
            state = .signedIn(me)
        }
    }

    func logout() async {
        if let refreshToken = tokens.current?.refreshToken {
            await auth.logout(refreshToken: refreshToken)
        }
        tokens.clear()
        state = .signedOut
    }

    private func finishSignIn(_ response: AuthResponse) async throws {
        tokens.save(response)
        state = .signedIn(try await auth.me())
    }
}
