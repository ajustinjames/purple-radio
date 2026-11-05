import Observation

/// App-wide state: whether the listener is signed in. Feature models (sign-in, followed
/// streams, playback) own their own state; services are injected here so tests can
/// replace them. See docs/architecture.md.
@Observable
final class AppModel {
    enum Phase: Equatable {
        case signedOut
        case signedIn
    }

    var phase: Phase = .signedOut
}
