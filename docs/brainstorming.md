# Brainstorming

These are working notes for discussion, not approved requirements or an implementation plan.

## Core idea

Let someone sign in on an Apple Watch, find a live Twitch stream, and listen to its audio directly on the watch over Wi-Fi or cellular. The watch should receive an audio-only stream, without downloading video data, to save network data and processing. The intended audio routes are the watch speaker and paired AirPods or other supported Bluetooth audio devices; actual behavior still needs testing in this app.

The experience should be watch-driven. It should not require an iPhone companion app for setup or playback, and it should not include tools for managing a Twitch account or channel. A QR-based Twitch sign-in flow, with approval on another device, is acceptable.

## Possible first listening experience

The first browsing view prioritizes live streams from channels the listener follows. A listener can select a stream, start or stop audio, and control playback on the watch.

This is a listening app, not a video viewer or a Twitch creator dashboard.

If no followed channels are live, show a simple "no live channels" state. Search and broader discovery are outside this initial experience.

## Proof-of-concept stages

The available test device is an Apple Watch Series 10 with cellular service, running watchOS 27. AirPods Pro 3 are available for Bluetooth audio testing.

### Mini POC: one stream

Play an audio-only feed from one known live Twitch stream on the watch over Wi-Fi, without transferring video. Test playback through both the watch speaker and AirPods Pro 3. Try the standard watchOS background-audio setup and check whether audio continues after lowering the wrist or returning to the watch face. If live-stream background playback takes more than the normal audio-session setup, in-app playback is sufficient to pass this mini POC; carry background playback into the main POC. This stage does not include sign-in, browsing, or cellular support.

Apple [documents background audio for watchOS apps](https://developer.apple.com/documentation/watchkit/playing-background-audio) and [confirms third-party media playback through the Series 10 speaker](https://www.apple.com/newsroom/2024/09/introducing-apple-watch-series-10/). Apple's [watchOS 27 audio-route guide](https://support.apple.com/guide/watch/choose-an-audio-destination-apd0110baf0e/27/watchos/27) says media playback through the watch speaker is unavailable while charging, so test speaker playback off the charger.

### Main POC: listening loop

Prove the core listening loop on a physical Apple Watch:

1. Start a QR-based Twitch sign-in from the watch and obtain the access needed to show live followed streams.
2. Select a live stream and play its audio on the watch over Wi-Fi and cellular.
3. Confirm the intended audio routes and behavior when the app is no longer foregrounded.
4. Record the playback mechanism and its dependencies.

The POC may use focused experimental code. Its findings should inform a deliberate app architecture; experimental code is not automatically production code.

## Separate distribution track

Assess Twitch terms, playback access, and App Store suitability independently of whether the POC plays audio. Experimental playback is acceptable for the POC; a working experiment alone does not settle whether the app can be distributed.

## Intent to preserve

- Keep the core experience on the watch.
- Build an original, maintainable application. Other apps may inform research, but their code is not the product's foundation.
- Make technical and distribution risks explicit before expanding the feature set.
- Keep scope centered on finding and listening to live streams.

## Open questions

- Can QR-based Twitch sign-in and credential renewal work without an iPhone companion app?
- Does the live audio feed work through the Series 10 speaker and AirPods Pro 3 in practice, including expected route changes?
- What technically stable path provides live stream audio to a third-party watch app?
- Is that playback path permitted by Twitch and suitable for a public App Store release?
- What counts as acceptable playback reliability across Wi-Fi, cellular handoff, interruptions, and background use?

We can turn decisions from this discussion into a product brief, feasibility notes, and then issues once the scope is agreed.
