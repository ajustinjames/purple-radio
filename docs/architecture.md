# Purple Radio: app architecture (first draft)

Status: first draft for the MVP ([#29](https://github.com/ajustinjames/purple-radio/issues/29)). It sets a shared structure for sign-in, followed streams, and playback so they can be built in parallel. It isn't the final HLD; open product and feasibility questions stay in the [PRD](prd.md#open-decisions-and-feasibility-risks).

## Source layout

The Apple Watch app's sources live in `apple/PurpleRadio/PurpleRadio Watch App/`, grouped by feature. It's a synchronized folder, so new files and folders join the app target without project file edits:

| Folder | Contents |
| --- | --- |
| `App/` | App entry point, `AppModel`, and `RootView`, which switches between signed-out and signed-in views. |
| `SignIn/` | QR sign-in UI and flow, `TwitchCredentials`, and the `TokenStore` protocol with its Keychain implementation ([#19](https://github.com/ajustinjames/purple-radio/issues/19)). |
| `Streams/` | Followed live streams view, the `LiveStream` model, and the `FollowedStreamsProvider` protocol with its Helix implementation ([#20](https://github.com/ajustinjames/purple-radio/issues/20)). |
| `Twitch/` | Client for Twitch's documented APIs: the OAuth device code flow and Helix. #19 adds it; #20's Helix implementation builds on it. |
| `Playback/` | `AudioSession`, the `AudioSourceResolver` protocol, the player, and Now Playing ([#21](https://github.com/ajustinjames/purple-radio/issues/21), [#23](https://github.com/ajustinjames/purple-radio/issues/23)). |
| `Playback/Source/` | The **only** code that calls undocumented Twitch endpoints (`gql.twitch.tv`, usher). Add it with #21. |
| `Support/` | Logging and `AppConfiguration`. |

The asset catalog stays at the top of the folder.

Keep the undocumented playback flow inside `Playback/Source/`, behind `AudioSourceResolver`. Its output is an audio-only media playlist URL for a `LiveStream`. Nothing else should depend on how that URL was obtained, so the flow can be replaced or removed after the [distribution review](https://github.com/ajustinjames/purple-radio/issues/16).

## State and navigation

- `AppModel` (`@MainActor`, `@Observable`) owns app-wide state: whether the listener is signed in. `RootView` shows sign-in when signed out and followed streams when signed in.
- Each feature owns its own state in a `@MainActor @Observable` model: sign-in progress, the followed streams list, and playback status. Views read models; they don't call services directly.
- Signed in: followed live streams → choose a stream → now playing. Playback state outlives the view that started it, so listening continues after navigating away or leaving the app. `AppModel` owns the playback model (#21) for that reason; views get it from `AppModel` rather than creating it.
- `AppModel` starts signed out. When #19 stores credentials, it adds a launch phase that loads them before choosing a view, so a signed-in listener doesn't see sign-in flash on launch.

## Services and dependencies

- Services such as the token store, Twitch client, and stream resolver are `Sendable` types that use `async` APIs and expose protocols where tests need a substitute.
- Inject services through initializers, starting from `AppModel`. Avoid singletons other than system ones such as `AVAudioSession.sharedInstance()`.
- The protocols between issues already exist, so each issue can start with a fake for the one it consumes:
  - `TokenStore` and `TwitchCredentials`: sign-in (#19) to the features that call Twitch.
  - `FollowedStreamsProvider`: followed streams (#20). Its Helix implementation uses #19's Twitch client; until that exists, #20 can build its view and model against a fake.
  - `LiveStream`: followed streams (#20) to playback (#21).
  - `AudioSourceResolver`: playback (#21) to the undocumented source in `Playback/Source/`.
- Refresh access tokens in one place. #19 provides a single shared component, such as an actor, that hands out a valid access token, refreshes it when it expires, and signs the listener out when refresh fails. Other features ask it for a token instead of reading `TokenStore` and refreshing themselves. Twitch's [device code flow](https://dev.twitch.tv/docs/authentication/getting-tokens-oauth/#device-code-grant-flow) issues refresh tokens that are "one time use only" and expire after 30 days of inactivity, so two concurrent refreshes would sign the listener out. Each refresh returns a new refresh token, which must be saved.

## Concurrency

The project uses Swift 6 language mode with strict concurrency. The app target keeps the template's defaults: main-actor isolation by default and approachable concurrency. So views and models are on the main actor without annotations.

Networking, Keychain access, and playlist parsing run off the main actor in `Sendable` services and return results to the models. Declare those services, the data types they pass around (such as `TwitchCredentials` and `LiveStream`), and their protocols `nonisolated`. Otherwise their conformances, including `Codable`, are tied to the main actor and can't be used from a service.

`nonisolated` alone doesn't move work off the main actor. With approachable concurrency, a `nonisolated async` function runs on its caller's actor, so a service called from a main-actor model would still do its work on the main thread. Make a service an `actor` when it holds mutable state, such as the token refresher. Otherwise mark its blocking or CPU-heavy `async` methods `@concurrent`. Both can conform to the `async` service protocols.

## Configuration

`apple/PurpleRadio/Config/Config.xcconfig` is the base configuration for every target and holds `TWITCH_CLIENT_ID`. A public client's ID isn't a secret, so it's committed there once the Twitch app is registered. `Config/Info.plist` passes it to `AppConfiguration`. Signing settings stay in the ignored `Local.xcconfig`.

## Logging and secrets

- Use the `Log` loggers. Log errors with `Log.redacted(_:)`, which keeps only the domain and code.
- Never log tokens, device codes, signed URLs, or raw `NSError` descriptions. `TwitchCredentials` redacts its own descriptions as a safeguard.
- Store credentials only through `TokenStore`, which means the Keychain on device.

## Testing

Unit tests in `apple/PurpleRadio/PurpleRadio Watch AppTests/` use Swift Testing and run in CI on the watch simulator. They cover logic that doesn't need a device: playlist parsing and variant selection, Helix response decoding, and token expiry handling. Feature models are tested with fake services. The test target isn't main-actor by default, so mark tests of main-actor types, such as feature models, `@MainActor`. Playback, audio routes, and background behavior, including `AudioSession`, are checked on the physical watch.

`apple/PurpleRadio/PurpleRadio Watch AppUITests/` holds a launch smoke test. CI skips it because it takes a few minutes; run the full scheme locally before merging app changes. Code that does something needs a test in the same change. Declarations such as protocols and plain data types don't.
