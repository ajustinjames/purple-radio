import Foundation
import Security

/// Stores credentials as one generic password item in the watch's Keychain.
///
/// The item stays on this device (`ThisDeviceOnly`, no iCloud sync) and is readable after
/// the first unlock, so a token refresh can run during background playback.
nonisolated struct KeychainTokenStore: TokenStore {
    struct KeychainError: Error, Equatable {
        let status: OSStatus
    }

    var service = (Bundle.main.bundleIdentifier ?? "PurpleRadio") + ".twitch"
    var account = "credentials"

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    @concurrent func load() async throws -> TwitchCredentials? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError(status: status)
        }
        return try JSONDecoder().decode(TwitchCredentials.self, from: data)
    }

    @concurrent func save(_ credentials: TwitchCredentials) async throws {
        let data = try JSONEncoder().encode(credentials)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(baseQuery.merging(attributes) { $1 } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    @concurrent func clear() async throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}
