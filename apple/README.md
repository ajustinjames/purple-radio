# Purple Radio for Apple Watch

Watch-only SwiftUI app for watchOS 27, with no iPhone companion app.

## Layout

- `PurpleRadio/` holds the app's Swift sources, grouped by feature as described in the [architecture note](../docs/architecture.md). It's a synchronized folder, so Xcode adds new files to the target automatically.
- `PurpleRadioTests/` holds unit tests, which use Swift Testing and run in the app on the watch simulator.
- `Config/Config.xcconfig` holds settings shared by both targets, including `APP_BUNDLE_IDENTIFIER` and `TWITCH_CLIENT_ID`. `Config/App.xcconfig` and `Config/Tests.xcconfig` add the per-target settings. `Config/Info.plist` holds the app's Info.plist.
- `Config/Local.xcconfig` is optional, ignored by Git, and holds your signing settings.

## Run on the watch

1. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`, then set `DEVELOPMENT_TEAM`. Also set `APP_BUNDLE_IDENTIFIER` if your team needs a unique one; the test bundle uses it with a `.tests` suffix. You can choose a team in Xcode instead, but don't commit the resulting project change.
2. Open `PurpleRadio.xcodeproj`, choose the paired watch as the run destination, and press **Run**.

To build without signing and run the unit tests, from the repository root:

```sh
xcodebuild build -project apple/PurpleRadio.xcodeproj -scheme PurpleRadio \
  -destination 'generic/platform=watchOS' CODE_SIGNING_ALLOWED=NO
xcodebuild test -project apple/PurpleRadio.xcodeproj -scheme PurpleRadio \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 12 (46mm)' \
  CODE_SIGNING_ALLOWED=NO
```

CI runs both on pull requests that change `apple/` ([workflow](../.github/workflows/apple.yml)). It uses GitHub's `xcode-27` runner image, which is still a preview.

## Lessons carried over from the mini POC

- Background audio is declared under `UIBackgroundModes` → `audio` in `Config/Info.plist`. `WKBackgroundModes` doesn't enable it: with that key, playback paused when the app left the screen.
- `AudioSession.activateForPlayback()` uses the `.playback` category with the `.longFormAudio` policy. This worked on the Series 10 speaker and AirPods without a route prompt.
- Never log tokens, signed URLs, or raw `NSError` descriptions, because they can embed signed URLs. Log errors with `Log.redacted(_:)`, which keeps only the domain and code.
- Signing settings stay out of the project file and shared config. `DEVELOPMENT_TEAM` belongs in `Local.xcconfig`.

The mini POC code is kept on the `mini-poc-code` branch for reference only. The app has no images or icons yet; follow the [AI policy](../AI_POLICY.md) when adding assets.
