import Foundation
import OSLog
import Observation

/// Runs QR sign-in: requests a device code, shows it, and polls Twitch until the listener
/// approves it in a browser on another device. An expired code is replaced on the same
/// screen.
@Observable
final class SignInModel {
    enum State: Equatable {
        case requestingCode
        case awaitingApproval(DeviceAuthorization, QRCode)
        case failed
    }

    private(set) var state: State = .requestingCode
    /// Changes on retry, so the view restarts `run()`.
    private(set) var attempt = 0

    private let auth: any TwitchAuthAPI
    private let session: TwitchSession
    private let onSignedIn: @MainActor () -> Void
    private let sleep: @Sendable (Duration) async throws -> Void
    private let now: @Sendable () -> Date

    init(
        auth: any TwitchAuthAPI,
        session: TwitchSession,
        onSignedIn: @escaping @MainActor () -> Void,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.auth = auth
        self.session = session
        self.onSignedIn = onSignedIn
        self.sleep = sleep
        self.now = now
    }

    /// Signs in, returning when the listener is signed in, sign-in fails, or the task is
    /// cancelled.
    func run() async {
        do {
            while true {
                state = .requestingCode
                let authorization = try await auth.startDeviceAuthorization()
                let qrCode = try QRCode(text: authorization.verificationURL.absoluteString)
                state = .awaitingApproval(authorization, qrCode)
                if let credentials = try await poll(authorization) {
                    try await session.begin(with: credentials)
                    onSignedIn()
                    return
                }
                Log.signIn.info("Device code expired; requesting a new one")
            }
        } catch is CancellationError {
            return
        } catch {
            Log.signIn.error("Sign-in failed: \(Log.redacted(error), privacy: .public)")
            state = .failed
        }
    }

    func retry() {
        state = .requestingCode
        attempt += 1
    }

    /// Polls until approval (returning credentials) or expiry (returning `nil`). A
    /// network error during a poll is retried at the next interval while the code lasts.
    private func poll(_ authorization: DeviceAuthorization) async throws -> TwitchCredentials? {
        var interval = authorization.pollInterval
        while now() < authorization.expiresAt {
            try await sleep(interval)
            let result: DeviceTokenPoll
            do {
                result = try await auth.pollDeviceToken(authorization)
            } catch let error as URLError {
                Log.signIn.notice("Poll failed, retrying: \(Log.redacted(error), privacy: .public)")
                continue
            }
            switch result {
            case .pending: continue
            case .slowDown: interval += .seconds(5)
            case .expired: return nil
            case .authorized(let credentials): return credentials
            }
        }
        return nil
    }
}
