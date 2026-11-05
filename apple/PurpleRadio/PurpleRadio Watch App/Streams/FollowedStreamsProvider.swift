/// Lists the live streams of channels the signed-in listener follows. Followed streams
/// (#20) provides the Helix implementation on top of the Twitch client from #19; tests
/// and previews use a fake.
nonisolated protocol FollowedStreamsProvider: Sendable {
    /// The followed channels that are live now. Empty when none are live.
    func liveFollowedStreams() async throws -> [LiveStream]
}
