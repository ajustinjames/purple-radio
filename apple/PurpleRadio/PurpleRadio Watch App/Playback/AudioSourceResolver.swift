import Foundation

/// Finds the audio to play for a live stream. Playback (#21) provides the
/// implementation in `Playback/Source/`, the only code that calls undocumented Twitch
/// endpoints. Everything else depends on this protocol, so that implementation can be
/// replaced or removed after the distribution review (#16).
nonisolated protocol AudioSourceResolver: Sendable {
    /// The URL of the stream's AAC `audio_only` media playlist. Never a multivariant
    /// playlist or a video variant.
    func audioPlaylistURL(for stream: LiveStream) async throws -> URL
}
