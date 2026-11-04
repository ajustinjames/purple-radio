import AVFoundation

/// Audio session setup carried over from the mini POC.
///
/// `.playback` with the `.longFormAudio` policy played through the Series 10 speaker
/// and AirPods without a route prompt. Background playback also needs `audio` under
/// `UIBackgroundModes` in Info.plist; `WKBackgroundModes` doesn't enable it.
enum AudioSession {
    /// Configures and activates the shared session for long-form playback.
    /// Returns `false` if the system declined activation.
    static func activateForPlayback() async throws -> Bool {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, policy: .longFormAudio, options: [])
        return try await session.activate(options: [])
    }

    static func deactivate() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Log.playback.error("Audio session deactivation failed: \(Log.redacted(error), privacy: .public)")
        }
    }
}
