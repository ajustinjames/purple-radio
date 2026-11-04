# Purple Radio

A standalone Apple Watch app for listening to live Twitch streams as audio. See the [draft PRD](docs/prd.md) for requirements; the [MVP milestone](https://github.com/ajustinjames/purple-radio/milestone/1) tracks the current build.

## Repository layout

| Path | Contents |
| --- | --- |
| [`apple/`](apple/README.md) | Apple Watch app (Xcode project, watchOS 27) |
| [`docs/`](docs) | Product requirements, architecture, feasibility findings, and design notes |

Each platform directory is a self-contained build with its own README and `.gitignore`. Another platform's app would go in a sibling directory.
