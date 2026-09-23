# Purple Radio: product requirements (draft)

Status: draft for review. This document defines the intended product and the proof-of-concept checkpoints. It does not select a Twitch playback mechanism or approve one for distribution. [Brainstorming notes](brainstorming.md) retain the discussion and open ideas.

## Purpose

Purple Radio lets a Twitch viewer listen to live streams directly on an Apple Watch while away from a phone. It is a watch-driven, audio-only listening experience that uses less data and processing than downloading video.

The first audience is a viewer who already follows channels on Twitch and wants to hear those channels live while using Wi-Fi or the watch's cellular connection.

## Core journey

1. Open Purple Radio on the watch. If signed out, begin Twitch sign-in on the watch using a QR-based flow. Approval in a browser on another device is acceptable; an iPhone companion app is not required.
2. See the live streams from followed channels. If none are live, see a clear "no live channels" state.
3. Choose a stream and listen to its audio. Control playback on the watch and use the watch speaker or paired AirPods.
4. Continue listening when the watch is no longer displaying the app.

## Product requirements

| ID | Requirement |
| --- | --- |
| PR-1 | The listener can complete the app experience from the watch, with browser approval on another device allowed for Twitch sign-in. Setup and playback do not depend on an iPhone companion app. |
| PR-2 | After sign-in, the primary browse view shows live streams from channels the listener follows. If there are none, it shows "no live channels." |
| PR-3 | Selecting a live stream starts its audio, and the listener can stop playback from the watch. |
| PR-4 | Playback uses an audio-only media feed; the watch must not download video segments merely to extract or play their audio. |
| PR-5 | Playback works over Wi-Fi and the watch's own cellular connection, without relying on an iPhone to relay the stream. |
| PR-6 | Playback works through the supported watch speaker and paired AirPods. Background listening is part of the intended app experience. |

The initial experience does not include video, chat, search, broader discovery, following or unfollowing channels, or creator/account management. It does not need an iPhone app.

## Validation stages

### Mini POC: media feasibility

On the available Apple Watch Series 10 cellular running watchOS 27, play one known live Twitch stream's **audio-only feed over Wi-Fi**. Demonstrate that no video segments are transferred. Test playback through both the watch speaker, while off the charger, and AirPods Pro 3. Record the media path and dependencies.

Try background playback using watchOS's standard audio-session support. If that needs additional live-stream work, working in-app playback still passes the mini POC; carry the background work into the main POC. Sign-in, followed streams, and cellular are outside this stage.

### Main POC: complete listening loop

On the same physical watch, demonstrate QR-based Twitch sign-in, a live-followed-streams view, an empty state when no followed channels are live, selection of a stream, and audio-only playback over both Wi-Fi and the watch's cellular connection. Test the watch speaker, AirPods Pro 3, and listening after leaving the app. Record what happens when a stream ends, the network changes, or audio is interrupted; acceptable recovery behavior still needs definition.

POC code is experimental. A successful POC establishes feasibility, not the final app architecture or permission to distribute it.

## Separate distribution decision

The App Store path needs its own review of Twitch's rules, the chosen media-access method, and Apple's requirements. An experimental playback method may be used to learn in the POCs, but a public release requires a documented, supportable conclusion about that method. Keep this decision separate from whether the POCs work technically.

## Open decisions and feasibility risks

- How to obtain a stable, truly audio-only feed for a live Twitch stream on watchOS.
- How QR sign-in, credential storage, renewal, and sign-out should work without a companion app.
- Whether the chosen playback path supports long-running background audio and route changes reliably.
- What playback duration and recovery behavior count as acceptable for a release.
- Whether the media-access path is permitted and maintainable for App Store distribution.

These questions should be answered through feasibility research and POC evidence before the HLD is finalized. LLDs can follow when individual components are ready to implement.
