# Purple Radio

Smartwatch apps for listening to live Twitch streams as audio, standalone on the watch. The first app is for Apple Watch. See the [draft PRD](docs/prd.md) for requirements; the [MVP milestone](https://github.com/ajustinjames/purple-radio/milestone/1) tracks the current build.

## Repository layout

| Path | Contents |
| --- | --- |
| [`apple/`](apple/README.md) | Apple Watch app (Xcode project, watchOS 27) |
| [`docs/`](docs) | Product requirements, feasibility findings, and design notes shared by all platforms |

Each platform directory is a self-contained build with its own README and `.gitignore`. A future Wear OS app would go in `android/` as its own Gradle project.
