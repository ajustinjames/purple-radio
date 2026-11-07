import Foundation
import Security
import Testing
@testable import PurpleRadio_Watch_App

/// Unsigned builds, such as CI's, have no Keychain entitlement, so these run only in
/// signed builds (`errSecMissingEntitlement` otherwise).
struct KeychainTokenStoreTests {
    static var keychainAvailable: Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "tests.probe",
            kSecReturnData as String: true,
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) != errSecMissingEntitlement
    }

    @Test(.enabled(if: keychainAvailable, "Needs a signed build"))
    func savesLoadsUpdatesAndClears() async throws {
        let store = KeychainTokenStore(service: "tests.\(UUID().uuidString)")
        #expect(try await store.load() == nil)
        try await store.save(.sample("1"))
        #expect(try await store.load()?.accessToken == "access-1")
        try await store.save(.sample("2"))
        #expect(try await store.load()?.refreshToken == "refresh-2")
        try await store.clear()
        #expect(try await store.load() == nil)
        try await store.clear()  // Clearing nothing isn't an error.
    }
}
