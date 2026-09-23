# Mini POC feasibility: Twitch live audio on Apple Watch

Status: research and proposed experiment, 2026-09-22. No watch playback has been tested. This document addresses the [draft PRD's mini POC](prd.md#mini-poc-media-feasibility), not the main POC or an app design.

## Question and current finding

Can an Apple Watch Series 10 on watchOS 27 play one **live Twitch stream as audio-only media** over its own Wi-Fi connection, through both its speaker and AirPods Pro 3, without downloading video segments?

**Feasible in principle, unproven for Twitch.** Apple documents HLS playback with `AVPlayer` and audio-only HLS variants. Twitch documents an audio-only playback mode in its own mobile apps, but the reviewed public [Get Streams API](https://dev.twitch.tv/docs/api/reference/#get-streams) returns stream metadata, and the [embed player API](https://dev.twitch.tv/docs/embed/video-and-clips/) exposes video playback controls rather than an audio-only HLS URL. These documents do not establish a supported way for this watch app to obtain a live audio-only rendition. That access gap is the main risk.

## Evidence and limits

| Finding | Status | Evidence and limit |
| --- | --- | --- |
| `AVPlayer` plays HLS, and HLS can identify audio-only variants by their `CODECS` attribute. | Documented Apple capability | [AVPlayer](https://developer.apple.com/documentation/avfoundation/avplayer); [Creating a Multivariant Playlist](https://developer.apple.com/documentation/http-live-streaming/creating-a-multivariant-playlist). This establishes format support, not that a Twitch URL is available or works on this watch. |
| Twitch has an audio-only mode in its mobile apps. | Documented Twitch product behavior | The [Extensions reference](https://dev.twitch.tv/docs/extensions/reference/) defines `playbackMode: audio` as an audio-only mode applying to mobile apps. It does not expose the mode as a playback API for third parties or prove every live stream has an accessible separate rendition. |
| The Series 10 speaker can play third-party media; watchOS 27 allows selecting the watch speaker or paired Bluetooth output. | Documented Apple capability | [Series 10 announcement](https://www.apple.com/newsroom/2024/09/introducing-apple-watch-series-10/); [watchOS 27 audio destinations](https://support.apple.com/guide/watch/choose-an-audio-destination-apd0110baf0e/27/watchos/27). Speaker media playback is unavailable while charging. Neither source confirms this app's specific audio-session behavior. |
| watchOS has an Audio background mode with the `.playback` category and `.longFormAudio` route policy. | Documented Apple capability, route uncertainty | [Playing Background Audio](https://developer.apple.com/documentation/watchkit/playing-background-audio) says to enable Audio background mode and activate the session, but also says long-form activation requires an eligible Bluetooth route. [Apple's route policy reference](https://developer.apple.com/documentation/avfaudio/avaudiosession/routesharingpolicy-swift.enum/longformaudio) conditions background playback on an eligible route. Test whether the speaker works with this policy on Series 10; do not assume the older Bluetooth wording settles the newer speaker behavior. |
| The official Twitch embed is a video player with minimum size and visibility requirements. | Documented Twitch integration, poor fit | [Embedding Twitch](https://dev.twitch.tv/docs/embed) and [Video & Clips](https://dev.twitch.tv/docs/embed/video-and-clips/) require a visible, unobscured player at least 400 × 300 pixels. Its controls expose video qualities, not a documented audio-only selection. Hiding a video embed or merely muting its picture cannot demonstrate zero video transfer. |

## Candidate paths

| Path | Feasibility for this mini POC | Dependency and risk |
| --- | --- | --- |
| **A. Direct audio-only HLS rendition → `AVPlayer` on watch.** Use a media playlist confirmed to carry audio only; avoid giving `AVPlayer` a multivariant playlist that can select video. | **Recommended experiment.** If a valid live URL can be obtained and remains playable, Apple provides the playback primitive and the watch receives only the chosen audio media. | Obtaining Twitch playback URLs and selecting its audio-only rendition are **not documented in the reviewed Twitch public APIs**. Any discovered endpoint, token exchange, rendition name, or signed URL lifecycle is an experimental dependency. An audio-sounding label alone is insufficient: inspect playlist and segments. |
| **B. Controlled audio-only HLS relay → `AVPlayer` on watch.** A test server fetches a verified Twitch audio-only rendition and serves only audio playlists/segments to the watch. | Conditional fallback if direct playback fails because of watch networking, headers, or URL lifetime. Server logs make watch transfer easier to audit. | Still depends on the same undocumented Twitch source. Adds server operation, latency, credential handling, and distribution questions. If the server instead downloads Twitch video and extracts audio, watch-only transfer may satisfy PR-4, but it **does not prove a Twitch audio-only source path**; report that result separately. |
| **C. Official Twitch video embed on watch.** | Unlikely to meet mini POC criteria. It is documented as a web video player, and no documented control guarantees audio-only network transfer. | The 400 × 300 minimum and visibility requirements conflict with a watch listening UI. Do not count hidden video or audio playback from a normal video rendition as a pass. |

This is a feasibility ranking, not an implementation or distribution decision. Do not treat a manually captured, expiring URL as a maintainable way to find streams.

**Mini POC decision (2026-09-22):** The project owner approved testing the undocumented Twitch playback flow for this private feasibility experiment. Start with path A and record every undocumented dependency and the observed network behavior. This approval does not select a release mechanism or settle Twitch/App Store distribution permission.

## Recommended mini POC experiment

1. **Preflight on a computer, for one known live channel.** Record how a candidate Twitch playlist was obtained and whether each step is documented or observed only. Inspect the multivariant and selected media playlist. Verify audio codec and container/track contents of **initialization and media segments**, sampling each distinct format and any discontinuity, including after a playlist refresh. Reject a muxed audio/video segment even if playback displays no picture. Do not save credentials, signed URLs, or captured content in the repository.
2. **Isolate Apple playback.** If necessary, first try a controlled, clearly labeled audio-only live HLS test feed on the physical watch. This checks watch HLS and audio routing; it is **not** a Twitch mini POC pass. Then play the verified Twitch audio-only media playlist directly with `AVPlayer`. If the URL cannot be used directly, record the failure and try path B as a distinct result.
3. **Test watch-driven Wi-Fi and routes.** Keep the paired iPhone unavailable as a stream relay; verify the watch is connected to the test Wi-Fi and that the playback requests originate from the watch or, for path B, arrive at the relay from the watch. Play at least five continuous minutes off the charger through the Series 10 speaker, then five through paired AirPods Pro 3. Note the actual selected route, starts, stalls, and stream latency. Do not substitute iPhone speaker output.
4. **Try background audio after foreground playback works.** Enable the standard watchOS Audio background mode and `.playback` / `.longFormAudio` session setup; test wrist down and returning to the watch face with each route. Log any route activation failure. A foreground-only success still meets this mini POC's playback scope; background failures move to the main POC.
5. **Preserve a reproducible, redacted test record.** Record watch model, watchOS build, test time, channel, source-path classification, playlist structure, sample segment track/codec inspection, route and duration results, request log, and failures. Note whether ads, stream discontinuities, or signed URL renewal were encountered; one short session cannot establish their long-term behavior.

### Proving no video reaches the watch

The decisive evidence is a **complete request and content inventory for the watch's playback session**, not audible output or low data use. For a controlled relay, log every requested playlist, initialization file, segment, byte range, and response size; classify each returned media object by its actual tracks. For direct Twitch playback, capture the watch's HLS requests with a trusted inspection setup *if technically possible*, or use equivalent per-request instrumentation; do not claim proof from encrypted packet sizes or hostnames alone. Compare every requested media URL against the chosen audio playlist and inspect segment contents for each distinct format and discontinuity. Check the beginning, steady state, and a playlist refresh, since adaptive or fallback selection could change. Apple's [`AVPlayerItemAccessLogEvent`](https://developer.apple.com/documentation/avfoundation/avplayeritemaccesslogevent) can provide transfer counts and bitrates as corroboration, but [`averageVideoBitrate`](https://developer.apple.com/documentation/avfoundation/avplayeritemaccesslogevent/averagevideobitrate) may describe combined content for muxed streams, so it is not a standalone proof. If full request visibility is unavailable, mark the no-video criterion **unverified**, even when the playlist appears audio-only.

### Pass/fail criteria

| Criterion | Pass | Fail or unresolved |
| --- | --- | --- |
| Live source and path | Audible content follows one live Twitch channel for the test; the documented/undocumented source steps and any relay are recorded. | Prerecorded sample, unrelated feed, or an unexplained media source. |
| Audio-only transfer | Complete watch request inventory contains only audio playlists and audio-only initialization/media segments; segment track inspection finds no video, across start and refresh. | Any video-bearing segment reaches the watch. **Unresolved** if requests or tracks cannot be fully observed. |
| Wi-Fi independence | Watch uses its Wi-Fi and plays without the iPhone relaying audio or data. | Phone relay, cellular fallback, or network path cannot be established. |
| Output routes | At least five continuous minutes of audible in-app playback through the **off-charger watch speaker** and five through **AirPods Pro 3**, with each route confirmed. | Either route cannot start or sustain playback. Record stalls and restarts; a restart does not count as continuous playback. |
| Background (exploratory) | Record whether audio continues wrist down and at the watch face with normal audio setup. | Failure here does **not** fail the mini POC; carry it into the main POC. |

A mini POC **technical pass** requires the first four rows to pass on the physical watch. A relay pass must be labeled as such. A result using a server that extracts audio from Twitch video is a **watch-only audio transfer result**, not proof that Twitch provided an audio-only rendition. An unavailable Twitch audio source, an unplayable source, or any video download is a technical failure for path A; an evidence gap is unresolved rather than a pass.

## Distribution is a separate decision

No candidate has been cleared for public release. Twitch's [developer documentation](https://dev.twitch.tv/docs) binds its products to the [Developer Services Agreement](https://legal.twitch.com/en/legal/developer-agreement/), and its [embed rules](https://dev.twitch.tv/docs/embed) constrain that specific player. Apple's [App Review Guidelines, sections 5.2.2–5.2.3](https://developer.apple.com/app-store/review/guidelines/#intellectual-property) require appropriate permission for third-party services and warn that media streaming can violate service terms. An observed Twitch HLS endpoint, successful playback, or a broadcaster's consent to a test does not establish Twitch permission for a general-purpose distributed player or relay. Review the exact media-access method, rights, ads/entitlements, and App Store submission evidence before choosing a release architecture.

## Decisions for review after the experiment

- If direct audio-only Twitch HLS works only through undocumented access, is a relay worth testing further, or should this path stop pending Twitch support/permission?
- Is the mini POC's five-minute-per-route threshold enough before investing in the main POC? Longer reliability targets belong to that stage.
- If Series 10 speaker playback conflicts with Apple's long-form route setup, which foreground route configuration is acceptable for further investigation? Do not generalize one successful route to background playback.
- Who will confirm Twitch and content-rights permission for a distributable audio-only player or relay? Keep that outcome separate from the technical result.
