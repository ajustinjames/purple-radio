/// Persists the listener's credentials. Sign-in (#19) provides the Keychain-backed
/// implementation; tests use an in-memory one.
nonisolated protocol TokenStore: Sendable {
    func load() throws -> TwitchCredentials?
    func save(_ credentials: TwitchCredentials) throws
    func clear() throws
}
