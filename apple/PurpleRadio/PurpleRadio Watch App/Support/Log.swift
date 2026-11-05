import Foundation
import OSLog

/// App loggers. Never log tokens, signed URLs, or raw `NSError` descriptions:
/// errors from networking and AVFoundation can embed signed URLs. Use `redacted(_:)`.
nonisolated enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "PurpleRadio"

    static let signIn = Logger(subsystem: subsystem, category: "SignIn")
    static let twitch = Logger(subsystem: subsystem, category: "Twitch")
    static let playback = Logger(subsystem: subsystem, category: "Playback")

    /// The error's domain and code only.
    static func redacted(_ error: any Error) -> String {
        let error = error as NSError
        return "\(error.domain) \(error.code)"
    }
}
