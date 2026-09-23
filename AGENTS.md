# Agent guidance

Purple Radio is a planned, standalone Apple Watch app for listening to live Twitch streams as audio. The repository is in the planning stage; there is no app implementation yet.

## Start here

- Read [the draft PRD](docs/prd.md) for intended behavior and POC boundaries.
- Read [brainstorming notes](docs/brainstorming.md) for decisions still under discussion.
- Follow [the AI policy](AI_POLICY.md) for all contributions.

## Working conventions

- Keep product requirements, feasibility findings, and implementation decisions distinct. Mark unverified platform or Twitch behavior as a question or hypothesis, and cite primary sources when recording researched facts.
- Preserve the watch-driven experience. A browser on another device may approve QR-based sign-in; the app should not require an iPhone companion for setup or playback.
- Treat the mini POC and main POC as separate validation stages. Do not promote experimental playback code into a release design without an explicit technical and distribution review.
- Build original, maintainable code. Other apps, including Frosty, can be studied as references but must not be copied into this project.
- Keep changes small and reviewable. Update the relevant document when a product or architecture decision changes, and link issues to agreed requirements or feasibility findings once issues are created.
- The current license file contains GPL v3 text. Do not change the project's license or assert an “only”/“or later” designation without an explicit project decision.
