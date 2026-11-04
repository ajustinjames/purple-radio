import Foundation

/// Build-time settings read from Info.plist, which gets them from Config.xcconfig.
struct AppConfiguration: Sendable {
    /// Twitch application client ID. Not a secret for a public client. `nil` until
    /// `TWITCH_CLIENT_ID` is set.
    let twitchClientID: String?

    init(bundle: Bundle = .main) {
        let value = bundle.object(forInfoDictionaryKey: "TwitchClientID") as? String
        twitchClientID = value?.isEmpty == false ? value : nil
    }
}
