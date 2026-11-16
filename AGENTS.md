<!-- pico-cli:plugin-context:pico-spatial-agentic-tools:start -->
## Plugin Context

Also read `./PICO-SPATIAL-AGENTIC-TOOLS.AGENTS.md` for PICO Spatial plugin guidance.
<!-- pico-cli:plugin-context:pico-spatial-agentic-tools:end -->

<!-- pico-cli:plugin-context:pico-general-agentic-tools:start -->
## Plugin Context

Also read `./PICO-GENERAL-AGENTIC-TOOLS.AGENTS.md` for PICO Spatial plugin guidance.
<!-- pico-cli:plugin-context:pico-general-agentic-tools:end -->

## Project scope and architecture

- Godot 4.4.1 + GDScript + OpenXR, PICO 4 standalone APK. PICO CLI is auxiliary; do not route into Kotlin Spatial/SpatialUI app generation.
- Current architecture is 0.4.0. Entry: `scenes/game/game.tscn`. Read `docs/architecture.md`, `docs/extending.md`, and `docs/performance.md` before adding gameplay features.
- `src/core` and `GameSession` are independent of scene nodes, XR and persistence. `SnakeGame` is the composition root. Input adapters, XR lifecycle, presentation, tutorial and profile storage have explicit owners and interfaces.
- Add level / skin / tutorial resources under `content/` and register them in `content/catalog.tres`. Add composable mechanics via `SnakeRule`; do not accumulate mode branches in the root frame loop. Validate data before loading; never mutate authored resources during play.
- User-approved behavior: player INSIDE the room; view-relative horizontal right stick; left stick forward/back = up/down with vertical priority. HOLD-TO-MOVE across all gameplay modes: neutral/release freezes simulation clock and visual interpolation immediately. Invalid reverse also stops. Resume/restart requires neutral before re-engaging. Future IMU/gesture/sound sources must follow the same state contract.
- Turns remain on grid boundaries; mid-cell frozen interpolation resumes from that progress. Walls kill only when the next head cell leaves the grid. Preserve wall-impact heading and visual contact feedback.
- Keep `scenes/diagnostics/input_lab.tscn` independent. Hardware diagnostics were verified previously; formal IMU/gesture/speech gameplay modes are not implemented yet.
- Preserve the existing hardware verification history in `docs/device-setup.md`. Do not reuse a previous version's user feedback as proof of a new build. 0.4.0 desktop checks, clean-checkout tests and APK build pass. PICO 4 installation, OpenXR startup and bilateral 26-joint tracking logs are verified; the user deferred gameplay/visual retesting until later.
- Use `tools/dev.sh` for editor, preview, lint, check, benchmark, export and deploy. GDScript formatting/lint uses pinned `requirements-dev.txt`; runtime binary dependencies come from verified `dependencies.lock.json` via `tools/bootstrap.py`.
- No Mesh/Material/node allocation or persistence in frame loops. Use renderer batches, bounded capacity, change-only HUD updates; preserve structural performance checks. CPU headless benchmarks are not headset FPS evidence.
- Git remote: `git@github.com:Alyxs-Treehouse/3D-Snake.git`. Use `codex/` feature branches, keep main buildable, and do not force-push existing history. Never commit builds, caches, downloaded vendor binaries, signatures or secrets. User is arranging SSH write access; do not claim a push succeeded without remote confirmation.
