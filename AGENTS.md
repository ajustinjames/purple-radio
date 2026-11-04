# Agent guidance

Purple Radio is a standalone Apple Watch app for listening to live Twitch streams as audio. The MVP, the first draft of the app, is in progress in [`apple/`](apple/README.md).

## Start here

- Read [the draft PRD](docs/prd.md) for intended behavior and build stages.
- Read [the architecture note](docs/architecture.md) before changing the app's structure.
- Read [brainstorming notes](docs/brainstorming.md) for decisions still under discussion.
- Follow [the AI policy](AI_POLICY.md) for all contributions.

## Working conventions

- Keep each app self-contained in its own top-level platform directory (currently `apple/`), with its own build, README and `.gitignore`. Product and design docs live in `docs/`.
- Keep product requirements, feasibility findings, and implementation decisions distinct. Mark unverified platform or Twitch behavior as a question or hypothesis, and cite primary sources when recording researched facts.
- Preserve the watch-driven experience. A browser on another device may approve QR-based sign-in; the app should not require an iPhone companion for setup or playback.
- The MVP is the app's real codebase, not a proof of concept. The mini POC was a separate experiment; its code stays on the `mini-poc-code` branch for reference and isn't merged.
- MVP playback relies on undocumented Twitch behavior. A working MVP doesn't settle distribution: a public release needs the separate distribution review ([#16](https://github.com/ajustinjames/purple-radio/issues/16)).
- Build original, maintainable code. Other apps, including Frosty, can be studied as references but must not be copied into this project.
- Keep changes small and reviewable. Update the relevant document when a product or architecture decision changes, and link issues to agreed requirements or feasibility findings once issues are created.
- The current license file contains GPL v3 text. Do not change the project's license or assert an “only”/“or later” designation without an explicit project decision.
