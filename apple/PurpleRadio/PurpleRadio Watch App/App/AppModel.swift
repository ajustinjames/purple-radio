import Foundation
import Observation

/// App-wide state: whether the listener is signed in. `RootView` switches on `phase`.
///
/// Feature models (sign-in, followed streams, playback) own their own state. Their
/// services are passed in through this type's initializer so tests can replace them.
/// See docs/architecture.md.
@Observable
final class AppModel {
    enum Phase: Equatable {
        /// Loading stored credentials, so a signed-in listener doesn't see sign-in flash.
        case launching
        case signedOut
        case signedIn
    }

    private(set) var phase: Phase = .launching
    /// Present while signed out, when sign-in is configured.
    private(set) var signIn: SignInModel?

    /// `nil` when no Twitch client ID is configured.
    private let auth: (any TwitchAuthAPI)?
    let session: TwitchSession?
    private let sleep: @Sendable (Duration) async throws -> Void

    init(
        auth: (any TwitchAuthAPI)?,
        store: any TokenStore,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.auth = auth
        self.session = auth.map { TwitchSession(auth: $0, store: store) }
        self.sleep = sleep
    }

    /// The app's services for `configuration`: Twitch sign-in when a client ID is set.
    convenience init(configuration: AppConfiguration = AppConfiguration()) {
        self.init(
            auth: configuration.twitchClientID.map { TwitchAuthClient(clientID: $0) },
            store: KeychainTokenStore()
        )
    }

    /// Restores the session, then follows it: returns to sign-in when it ends. Runs for
    /// the app's lifetime.
    func start() async {
        guard let session else {
            enterSignedOut()
            return
        }
        if await session.restore() {
            phase = .signedIn
        } else {
            enterSignedOut()
        }
        for await _ in session.ended {
            enterSignedOut()
        }
    }

    /// Validates the token now and hourly while signed in, as Twitch requires:
    /// https://dev.twitch.tv/docs/authentication/validate-tokens/
    func validatePeriodically() async {
        guard let session else { return }
        while phase == .signedIn {
            await session.validate()
            do {
                try await sleep(.seconds(60 * 60))
            } catch {
                return
            }
        }
    }

    func signOut() async {
        await session?.signOut()
        enterSignedOut()
    }

    private func enterSignedOut() {
        phase = .signedOut
        guard let auth, let session else {
            signIn = nil
            return
        }
        signIn = SignInModel(auth: auth, session: session) { [weak self] in
            self?.phase = .signedIn
            self?.signIn = nil
        }
    }
}
