import Foundation
import OSLog

/// The signed-in listener's session: the one place that hands out access tokens,
/// refreshes them, and ends the session when Twitch won't refresh it.
///
/// Twitch's refresh tokens for public clients are single use, so two refreshes at once
/// would sign the listener out. Concurrent callers share one refresh here. Features ask
/// this actor for a token instead of reading `TokenStore` themselves.
actor TwitchSession {
    enum SessionError: Error, Equatable {
        case signedOut
    }

    /// Refresh this long before the access token expires, so a request doesn't race expiry.
    static let refreshMargin: TimeInterval = 5 * 60

    private let auth: any TwitchAuthAPI
    private let store: any TokenStore
    private let now: @Sendable () -> Date
    private var credentials: TwitchCredentials?
    private var refreshTask: Task<TwitchCredentials, any Error>?
    private let endedContinuation: AsyncStream<Void>.Continuation

    /// Yields when the session ends without the listener signing out, such as a failed
    /// refresh, so the app can return to sign-in.
    nonisolated let ended: AsyncStream<Void>

    init(auth: any TwitchAuthAPI, store: any TokenStore, now: @escaping @Sendable () -> Date = { Date() }) {
        self.auth = auth
        self.store = store
        self.now = now
        (ended, endedContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    /// Loads stored credentials. Returns whether the listener is signed in.
    func restore() async -> Bool {
        do {
            credentials = try await store.load()
        } catch {
            Log.signIn.error("Loading credentials failed: \(Log.redacted(error), privacy: .public)")
            credentials = nil
        }
        return credentials != nil
    }

    /// Starts a session with newly issued credentials.
    func begin(with credentials: TwitchCredentials) async throws {
        try await store.save(credentials)
        self.credentials = credentials
    }

    /// A valid access token, refreshed first if it's about to expire.
    func accessToken() async throws -> String {
        guard let credentials else { throw SessionError.signedOut }
        if credentials.expiresAt.timeIntervalSince(now()) > Self.refreshMargin {
            return credentials.accessToken
        }
        return try await refreshed().accessToken
    }

    /// Call when Twitch rejects `rejectedToken` with 401. Returns a fresh token, unless
    /// another caller already replaced the rejected one.
    func accessToken(replacing rejectedToken: String) async throws -> String {
        guard let credentials else { throw SessionError.signedOut }
        if credentials.accessToken != rejectedToken { return credentials.accessToken }
        return try await refreshed().accessToken
    }

    /// Checks the token with Twitch, which requires apps to validate at launch and
    /// hourly. Refreshes an invalid token; network errors leave the session as is.
    func validate() async {
        guard let token = credentials?.accessToken else { return }
        do {
            if try await auth.validate(accessToken: token) { return }
            _ = try await accessToken(replacing: token)
        } catch {
            Log.signIn.error("Token validation failed: \(Log.redacted(error), privacy: .public)")
        }
    }

    /// Signs out: forgets the credentials and asks Twitch to revoke the access token.
    func signOut() async {
        let token = credentials?.accessToken
        await clear()
        guard let token else { return }
        do {
            try await auth.revoke(accessToken: token)
        } catch {
            Log.signIn.error("Token revocation failed: \(Log.redacted(error), privacy: .public)")
        }
    }

    // MARK: - Refresh

    private func refreshed() async throws -> TwitchCredentials {
        if let refreshTask {
            do {
                return try await refreshTask.value
            } catch TwitchAuthError.invalidRefreshToken {
                throw SessionError.signedOut  // The caller that started it ends the session.
            }
        }
        guard let current = credentials else { throw SessionError.signedOut }

        let task = Task { [auth, store] in
            let renewed = try await auth.refresh(current)
            // Each refresh returns a new refresh token; the old one is spent.
            try await store.save(renewed)
            return renewed
        }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            let renewed = try await task.value
            credentials = renewed
            return renewed
        } catch TwitchAuthError.invalidRefreshToken {
            Log.signIn.notice("Refresh token rejected; signing out")
            await clear()
            endedContinuation.yield()
            throw SessionError.signedOut
        }
    }

    private func clear() async {
        credentials = nil
        do {
            try await store.clear()
        } catch {
            Log.signIn.error("Clearing credentials failed: \(Log.redacted(error), privacy: .public)")
        }
    }
}
