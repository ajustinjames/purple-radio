# Purple Radio: app architecture (first draft)

Status: first draft for the MVP ([#29](https://github.com/ajustinjames/purple-radio/issues/29)). It sets a shared structure for sign-in, followed streams, and playback so they can be built in parallel. It isn't the final HLD; open product and feasibility questions stay in the [PRD](prd.md#open-decisions-and-feasibility-risks).

## Source layout

The Apple Watch app's sources live in `apple/PurpleRadio/PurpleRadio Watch App/`, grouped by feature. It's a synchronized folder, so new files and folders join the app target without project file edits:

| Folder | Contents |
| --- | --- |
| `App/` | App entry point, `AppModel`, and `RootView`, which switches between signed-out and signed-in views. |
| `SignIn/` | QR sign-in UI and flow, `TwitchCredentials`, and the `TokenStore` protocol with its Keychain implementation ([#19](https://github.com/ajustinjames/purple-radio/issues/19)). |
| `Streams/` | Followed live streams view and the `LiveStream` model ([#20](https://github.com/ajustinjames/purple-radio/issues/20)). |
| `Twitch/` | Client for Twitch's documented APIs: the OAuth device code flow and Helix. Add it with #19. |
| `Playback/` | `AudioSession`, the player, Now Playing, and stream resolution ([#21](https://github.com/ajustinjames/purple-radio/issues/21), [#23](https://github.com/ajustinjames/purple-radio/issues/23)). |
| `Playback/Source/` | The **only** code that calls undocumented Twitch endpoints (`gql.twitch.tv`, usher). Add it with #21. |
| `Support/` | Logging and `AppConfiguration`. |

The asset catalog stays at the top of the folder.

Keep the undocumented playback flow inside `Playback/Source/`. Its output is an audio-only media playlist URL for a `LiveStream`. Nothing else should depend on how that URL was obtained, so the flow can be replaced or removed after the [distribution review](https://github.com/ajustinjames/purple-radio/issues/16).

## State and navigation

- `AppModel` (`@MainActor`, `@Observable`) owns app-wide state: whether the listener is signed in. `RootView` shows sign-in when signed out and followed streams when signed in.
- Each feature owns its own state in a `@MainActor @Observable` model: sign-in progress, the followed streams list, and playback status. Views read models; they don't call services directly.
- Signed in: followed live streams → choose a stream → now playing. Playback state outlives the view that started it, so listening continues after navigating away or leaving the app.

## Services and dependencies

- Services such as the token store, Twitch client, and stream resolver are `Sendable` types that use `async` APIs and expose protocols where tests need a substitute.
- Inject services through initializers, starting from `AppModel`. Avoid singletons other than system ones such as `AVAudioSession.sharedInstance()`.
- `LiveStream` is the hand-off between followed streams (#20) and playback (#21). `TwitchCredentials` and `TokenStore` are the hand-off between sign-in (#19) and the features that call Twitch.

## Concurrency

The project uses Swift 6 language mode with strict concurrency. The app target keeps the template's defaults: main-actor isolation by default and approachable concurrency. So views and models are on the main actor without annotations.

Networking, Keychain access, and playlist parsing run off the main actor in `Sendable` services and return results to the models. Declare those services, the data types they pass around (such as `TwitchCredentials` and `LiveStream`), and their protocols `nonisolated`. Otherwise their conformances, including `Codable`, are tied to the main actor and can't be used from a service.

## Configuration

`apple/PurpleRadio/Config/Config.xcconfig` is the base configuration for every target and holds `TWITCH_CLIENT_ID`. A public client's ID isn't a secret, so it's committed there once the Twitch app is registered. `Config/Info.plist` passes it to `AppConfiguration`. Signing settings stay in the ignored `Local.xcconfig`.

## Logging and secrets

- Use the `Log` loggers. Log errors with `Log.redacted(_:)`, which keeps only the domain and code.
- Never log tokens, device codes, signed URLs, or raw `NSError` descriptions. `TwitchCredentials` redacts its own descriptions as a safeguard.
- Store credentials only through `TokenStore`, which means the Keychain on device.

## Testing

Unit tests in `apple/PurpleRadio/PurpleRadio Watch AppTests/` use Swift Testing and run in CI on the watch simulator. They cover logic that doesn't need a device: playlist parsing and variant selection, Helix response decoding, and token expiry handling. Feature models are tested with fake services. Playback, audio routes, and background behavior are checked on the physical watch.
