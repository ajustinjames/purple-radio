/// A followed channel that is live, as listed by Helix Get Followed Streams (#20) and
/// handed to playback (#21).
struct LiveStream: Identifiable, Hashable, Sendable {
    /// Helix stream ID.
    let id: String
    /// Channel login (`user_login`), used to resolve playback.
    let channelLogin: String
    /// Channel display name (`user_name`).
    let channelName: String
    let title: String
    /// Category name (`game_name`); empty if none is set.
    let category: String
}
