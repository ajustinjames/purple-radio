import Foundation

/// The signed-in listener's Twitch OAuth tokens. Its descriptions are redacted so the
/// tokens can't reach a log through string interpolation.
nonisolated struct TwitchCredentials: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var scopes: [String]
}

nonisolated extension TwitchCredentials: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { "TwitchCredentials(redacted)" }
    var debugDescription: String { description }
}
