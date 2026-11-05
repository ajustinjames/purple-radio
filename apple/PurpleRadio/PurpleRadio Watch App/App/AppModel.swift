import Observation

/// App-wide state: whether the listener is signed in. `RootView` switches on `phase`.
///
/// Feature models (sign-in, followed streams, playback) own their own state. As their
/// services land (#19–#21), they're passed in through this type's initializer so tests
/// can replace them. See docs/architecture.md.
@Observable
final class AppModel {
    enum Phase: Equatable {
        case signedOut
        case signedIn
    }

    var phase: Phase = .signedOut
}
