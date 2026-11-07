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

## Views

Build screens from system SwiftUI and WatchKit components wherever possible, for compatibility with future watchOS releases and speed of development (owner decision, 2026-11-04). Use `NavigationStack` and `List` for the followed streams, `ContentUnavailableView` for empty and error states, `ProgressView` for loading, and `confirmationDialog` for sign-out. Playback uses WatchKit's `NowPlayingView`, fed through `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter`, instead of custom player controls. Write a custom view only when no system component fits, such as the sign-in QR code: Core Image isn't in the watchOS SDK, so there's no system QR generator.

The [watch screen mockups](mockups/watch-screens.html) show each screen and state, and the components it uses.

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

`apple/PurpleRadio/Config/Config.xcconfig` is the base configuration for every target. Signing settings and the Twitch client ID stay in the ignored `Local.xcconfig`. `Config/Info.plist` passes `TWITCH_CLIENT_ID` to `AppConfiguration` as the `$(TWITCH_CLIENT_ID)` build setting, so the committed plist holds no value.

No Twitch client ID is committed ([#31](https://github.com/ajustinjames/purple-radio/issues/31)). `Config.xcconfig` leaves `TWITCH_CLIENT_ID` empty, and each developer sets their own registered app's ID in `Local.xcconfig`. A public client's ID isn't a secret, since anyone can read it from a built app's Info.plist. The reason is ownership: a fork building with our ID would show our app's name when its users approve sign-in, and its traffic would count against our app's Twitch rate limits. `AppConfiguration` treats an empty value as unset, and sign-in shows that it isn't configured rather than failing. A fresh clone with no `Local.xcconfig` still builds and passes the unit tests, which don't call Twitch. If a CI job ever needs the ID, such as a release build, store it as a GitHub Actions variable or secret and pass it to `xcodebuild` as `TWITCH_CLIENT_ID=...`; don't write it into a committed file.

## Logging and secrets

- Use the `Log` loggers. Log errors with `Log.redacted(_:)`, which keeps only the domain and code.
- Never log tokens, device codes, signed URLs, or raw `NSError` descriptions. `TwitchCredentials` redacts its own descriptions as a safeguard.
- Store credentials only through `TokenStore`, which means the Keychain on device.

## Testing

Unit tests in `apple/PurpleRadio/PurpleRadio Watch AppTests/` use Swift Testing and run in CI on the watch simulator. They cover logic that doesn't need a device: playlist parsing and variant selection, Helix response decoding, and token expiry handling. Feature models are tested with fake services. The test target isn't main-actor by default, so mark tests of main-actor types, such as feature models, `@MainActor`. The Keychain store's test needs a signed build: unsigned builds, including CI's, lack the Keychain entitlement, so it's skipped there and runs when you test from Xcode with signing. Playback, audio routes, and background behavior, including `AudioSession`, are checked on the physical watch.

`apple/PurpleRadio/PurpleRadio Watch AppUITests/` holds a launch smoke test. CI skips it because it takes a few minutes; run the full scheme locally before merging app changes. Code that does something needs a test in the same change. Declarations such as protocols and plain data types don't.
