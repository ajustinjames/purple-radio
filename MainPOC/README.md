# Main POC

Watch-only SwiftUI app for watchOS 27 that will demonstrate the [main POC listening loop](../docs/prd.md#main-poc-complete-listening-loop). It has no iPhone companion app (PR-1). POC code is experimental: it establishes feasibility, not the release architecture or a distribution decision.

This is a new project, not an extension of the mini POC. The mini POC code is kept on the `mini-poc-code` branch for reference only.

## Layout

- `PurpleRadio/` holds the app's Swift sources. It's a synchronized folder, so Xcode adds new files to the target automatically.
- `Config/Config.xcconfig` holds the shared build settings. `Config/Info.plist` holds the app's Info.plist.
- `Config/Local.xcconfig` is optional, ignored by Git, and holds your signing settings.

## Run on the watch

1. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`, then set `DEVELOPMENT_TEAM`. Also set `PRODUCT_BUNDLE_IDENTIFIER` if your team needs a unique one. You can choose a team in Xcode instead, but don't commit the resulting project change.
2. Open `PurpleRadio.xcodeproj`, choose the paired watch as the run destination, and press **Run**.

To build without signing:

```sh
xcodebuild -project MainPOC/PurpleRadio.xcodeproj -scheme PurpleRadio \
  -destination 'generic/platform=watchOS' CODE_SIGNING_ALLOWED=NO build
```

## Lessons carried over from the mini POC

- Background audio is declared under `UIBackgroundModes` → `audio` in `Config/Info.plist`. `WKBackgroundModes` doesn't enable it: with that key, playback paused when the app left the screen.
- `AudioSession.activateForPlayback()` uses the `.playback` category with the `.longFormAudio` policy. This worked on the Series 10 speaker and AirPods without a route prompt.
- Never log tokens, signed URLs, or raw `NSError` descriptions, because they can embed signed URLs. Log errors with `Log.redacted(_:)`, which keeps only the domain and code.
- Signing settings stay out of the project file and shared config. `DEVELOPMENT_TEAM` belongs in `Local.xcconfig`.

The app has no images or icons. Follow the [AI policy](../AI_POLICY.md) when adding assets.
