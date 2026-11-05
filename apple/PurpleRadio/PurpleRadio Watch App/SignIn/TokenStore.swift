/// Persists the listener's credentials. Sign-in (#19) provides the Keychain-backed
/// implementation; tests use an in-memory one.
///
/// The methods are `async` so the implementation can keep Keychain access off the
/// main actor (see docs/architecture.md, Concurrency).
nonisolated protocol TokenStore: Sendable {
    func load() async throws -> TwitchCredentials?
    func save(_ credentials: TwitchCredentials) async throws
    func clear() async throws
}
