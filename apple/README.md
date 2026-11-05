# Purple Radio for Apple Watch

Watch-only SwiftUI app for watchOS 27, with no iPhone companion app. The project was created from Xcode 27's Watch-only App template.

## Layout

Everything is in `PurpleRadio/`:

- `PurpleRadio.xcodeproj` uses Xcode 27's text project format (`project.xcproj`). Edit it in Xcode or with Xcode's `xcodeproj` command-line tool rather than by hand. The shared `PurpleRadio Watch App` scheme builds the app and runs both test targets.
- `PurpleRadio Watch App/` holds the app's Swift sources, grouped by feature as described in the [architecture note](../docs/architecture.md). It's a synchronized folder, so Xcode adds new files to the target automatically.
- `PurpleRadio Watch AppTests/` holds unit tests, which use Swift Testing and run in the app on the watch simulator.
- `PurpleRadio Watch AppUITests/` holds the template's UI tests, which use XCTest.
- `Config/Config.xcconfig` is the base configuration for every target. It holds `BUNDLE_ID_PREFIX` and `TWITCH_CLIENT_ID`. `Config/Info.plist` adds the keys Xcode doesn't generate: `UIBackgroundModes` and `TwitchClientID`.
- `Config/Local.xcconfig` is optional, ignored by Git, and holds your signing settings.

The `PurpleRadio` target is the template's empty iOS container that a watch-only app ships in; it has no code.

## Run on the watch

1. Copy `PurpleRadio/Config/Local.xcconfig.example` to `PurpleRadio/Config/Local.xcconfig`, then set `DEVELOPMENT_TEAM`. If the bundle IDs are taken for your team, also set `BUNDLE_ID_PREFIX`. Don't choose a team in Xcode's Signing & Capabilities tab: that writes it into the project file.
2. Open `PurpleRadio/PurpleRadio.xcodeproj`, choose the paired watch as the run destination, and press **Run**.

To build without signing and run the unit tests, from the repository root:

```sh
xcodebuild build -project apple/PurpleRadio/PurpleRadio.xcodeproj \
  -scheme 'PurpleRadio Watch App' -destination 'generic/platform=watchOS' \
  CODE_SIGNING_ALLOWED=NO
xcodebuild test -project apple/PurpleRadio/PurpleRadio.xcodeproj \
  -scheme 'PurpleRadio Watch App' \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 12 (46mm)' \
  -only-testing:'PurpleRadio Watch AppTests' CODE_SIGNING_ALLOWED=NO
```

Drop `-only-testing` to run the UI tests too; they take a few minutes.

CI runs the build and the unit tests on pull requests that change `apple/` ([workflow](../.github/workflows/apple.yml)). It uses GitHub's `xcode-27` runner image, which is still a preview: the workflow waits for its watchOS simulator runtime to mount and creates its own watch simulator. Output goes through `xcbeautify`, and the test result bundle is uploaded when the tests fail.

## Lessons carried over from the mini POC

- Background audio is declared under `UIBackgroundModes` → `audio` in `Config/Info.plist`. `WKBackgroundModes` doesn't enable it: with that key, playback paused when the app left the screen.
- `AudioSession.activateForPlayback()` uses the `.playback` category with the `.longFormAudio` policy. This worked on the Series 10 speaker and AirPods without a route prompt.
- Never log tokens, signed URLs, or raw `NSError` descriptions, because they can embed signed URLs. Log errors with `Log.redacted(_:)`, which keeps only the domain and code.
- Signing settings stay out of the project file and shared config. `DEVELOPMENT_TEAM` belongs in `Local.xcconfig`.

The mini POC code is kept on the `mini-poc-code` branch for reference only. The app has no images or icons yet; follow the [AI policy](../AI_POLICY.md) when adding assets.
