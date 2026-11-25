# Mash & Burn — playable prototype

Godot4.4.1 PC prototype with deterministic brewing, authoritative2–8player matches,
fire/claims, beer visuals, fictional tasting/feed and an optional mock companion.
See [current validation](docs/AI-GOAL-PROGRESS.md), [installer delivery](docs/releases.md)
and [companion setup](companion/README.md). MSI installers are published through
[GitHub Releases](https://github.com/jpeckham/MashAndBurn/releases).

Godot 4.4.1 Mono is installed at `C:\Program Files\Godot\Godot_v4.4.1-stable_mono_win64_console.exe` (reported `4.4.1.stable.mono.official.49a5bc7b6`). GDScript requires no .NET SDK. Python 3.11.9 is available at `C:\Users\james\AppData\Local\Programs\Python\Python311\python.exe`; it is optional and not the simulation runtime. No packages or setup install is required.

FFmpeg is optional for recording and is not a game dependency. Actual inspected
rendered evidence is preserved for [single-player](evidence/desktop/2026-11-25-hosted/README.md),
[multiplayer](evidence/multiplayer/2026-11-25-hosted/README.md) and
[visual comparisons](evidence/visuals/2026-11-25-hosted/README.md).

PowerShell commands (replace the executable path if installed elsewhere):

```powershell
& 'C:/Program Files/Godot/Godot_v4.4.1-stable_mono_win64_console.exe' --path .
& 'C:/Program Files/Godot/Godot_v4.4.1-stable_mono_win64_console.exe' --headless --path . --script tests/run_all.gd -- --suite chemistry
& 'C:/Program Files/Godot/Godot_v4.4.1-stable_mono_win64_console.exe' --headless --path . --script tests/run_all.gd -- --suite contracts
```

See [architecture and approximation limits](docs/architecture.md) and [protocol](src/contracts/README.md). The engine normally writes logs to its local application-data folder; restricted environments must allow that folder or supply `--log-file` pointing to a writable file.

## Play a batch

Launch the project with the first command. Hold right mouse and WASD to look/walk; E interacts with the active nearby station. Numbered station buttons visit stations. The Brew Desk stays usable with the mouse released. Simulation starts paused.

1. Default recipe: 20 L water, 5 kg grain, 66.7 C target. Click **+ 1 hour** at mash; conversion and elapsed time unlock **Next stage**.
2. At boil, **Add (5% AA)** adds the displayed hop grams. Click **+ 1 hour**, which heats and boils; Next unlocks when hot and at least an hour has elapsed.
3. At cooling, flow defaults to 1. Click **+ 1 hour**, then Next when at or below 25 C.
4. At fermentation, use **+ 4 hours** twelve times (48 simulated hours); Next unlocks at 95% yeast progress. Or Resume at 86,400x and Pause when ready.
5. At packaging use 120 g priming sugar (or set a regulator pressure), then **Package & judge**. Excess priming latches a local overpressure hazard.

**Save batch / Load batch** uses `user://batch-v1.json` in Godot's app data folder. Invalid/corrupted/version-mismatched saves leave the current batch intact. The first batch uses seed 42; **New batch** increments the seed and batch ID. Each setting's **Set** validates it; recipe quantities lock when mash begins. UI shows simulation state and approximate brewing metrics. Local brewing contacts no external services or hardware. [Multiplayer](docs/gameplay.md) starts only when explicitly hosted/joined; the server then owns batch time and state.

Focused UI checks: append `-- --suite presentation` to the headless harness command. Static parsing: `--headless --editor --path . --quit`. Later render/gameplay modules can add Node scripts via project setting `mash_burn/modules`; each receives `setup(garage)` then `on_state(state)`, and may attach UI under `garage.module_slot` or scene nodes without owning the garage implementation.

## Judging and validation

Packaging opens the tasting room with five 20-point categories and cause-based feedback. Scores below 45 or severe diacetyl/acetaldehyde open a fictional local feed: 512 unique procedural personas, 16 posts per page, no network calls or external accounts. See [sandbox details](docs/social.md).

The combined game suite currently passes **1,022 checks**, including actual two-/eight-client ENet sessions and garage integration. Hosted Windows checks also exercise export/startup, MSI install/payload hashes, major upgrade, downgrade rejection and uninstall. Companion validation passes59pytest cases on Linux and Windows plus actual game/daemon/private-fake interoperability.

The inspected single-player walkthrough preserves20X11/Mesa frames and403GUI assertions: normal/flawed recipes, walking/look/E, pause/resume, exact save/reload and feed pages1,2,32. The multiplayer session adds27inspected frames, and renderer comparisons add10. See [PRD traceability and limitations](docs/prototype-traceability.md) for precisely what this prototype demonstrates.
