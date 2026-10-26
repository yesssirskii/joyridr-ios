import Foundation
import Security

/// Keeps the access and refresh tokens in the Keychain (encrypted by iOS, survives app restarts).
/// Never store tokens in UserDefaults.
final class TokenStore {
    static let shared = TokenStore()

    struct Tokens: Codable {
        let accessToken: String
        let accessTokenExpiresAt: Date
        let refreshToken: String
    }

    /// Cached copy so we don't hit the Keychain on every request.
    private(set) var current: Tokens?

    private let service = "com.joyridr.auth"
    private let account = "tokens"

    init() {
        current = load()
    }

    func save(_ response: AuthResponse) {
        let tokens = Tokens(accessToken: response.accessToken, accessTokenExpiresAt: response.accessTokenExpiresAt,
                            refreshToken: response.refreshToken)
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        current = tokens

        let query = baseQuery
        let attributes: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    func clear() {
        current = nil
        SecItemDelete(baseQuery as CFDictionary)
    }

    private func load() -> Tokens? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Tokens.self, from: data)
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}
