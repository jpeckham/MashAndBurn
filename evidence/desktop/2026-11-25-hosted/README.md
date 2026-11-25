# Inspected hosted garage walkthrough

Source: `10ab1aa9a4a8adde2fb397c7355f7a535a2750eb`, branch `codex/continue-mash-and-burn`.
Run: https://github.com/jpeckham/MashAndBurn/actions/runs/45668068521
Date: 2026-11-25, 17:45–17:46 UTC. Machine: `GitHub Actions 1000001559`, Ubuntu 24.04 runner.
Operator: GitHub Actions / Godot `Input.parse_input_event` automation.

This is an actual Godot X11 window under Xvfb/Mesa, not the headless/dummy renderer.
The fixture uses GUI hit testing and keyboard/mouse events, not button-signal
emission or direct batch mutation. Each button must activate exactly once.
All 20 frames were inspected: root inspected six key frames, and the independent
`review_client_integration` reviewer inspected the remaining fourteen and their
provenance. All original PNG SHA256 hashes were checked by both. Files here are
unchanged copies from the successful run, preserved so artifact expiry cannot
erase the evidence. `walkthrough.txt` is the unmodified run log renamed from `.log`.

## What was observed

| Frames | Observation |
| --- | --- |
| [Garage](00-garage.png), [controls/readiness](01-controls-and-readiness.png) | Original 3D garage, station controls, readable instructions and readiness feedback. Runtime assertions additionally record actual mouse-look, walking and E input routing. |
| [Rear garage](02-buick-trunk-and-exit.png) | Procedural old sedan, trunk marker and green exit area. This does not establish a full multiplayer traversal. |
| [Mash](normal-01-mash.png), [reload](normal-02-reloaded.png), [metrics](normal-02b-metrics.png) | Normal mash progress and restored mid-batch state, with bounded scrollable metrics. Exact save/load hash restoration and pause/resume are behavioral assertions in the manifest/log, not claims inferred from pixels alone. |
| [Boil](normal-03-boil.png), [cooling](normal-04-cooling.png), [fermentation](normal-05-fermentation.png), [packaging](normal-06-packaging.png) | Recipe advances through every brewing stage using GUI controls; temperatures, hop/IBU, yeast and packaging settings are visible. |
| [Normal judging](normal-07-judging-page-1.png) | Seed 42 scores 86.1/100; five categories and cause feedback are readable; no local swarm triggers. |
| [Flawed mash](flawed-01-mash.png), [boil](flawed-03-boil.png), [cooling](flawed-04-cooling.png), [fermentation](flawed-05-fermentation.png), [packaging](flawed-06-packaging.png) | Seed 43 is deliberately scorched, fermented warm and overprimed using the same GUI; no developer console or state injection is used. |
| [Feed page 1](flawed-07-judging-page-1.png), [page 2](flawed-08-feed-page-2.png), [page 32](flawed-09-feed-page-32.png) | Flawed batch scores 39.8/100 and displays different fictional persona rows on requested pages. Runtime checks and the regular suite establish the 16-row bound; screenshots alone do not prove memory bounds. |
| [Flaws and latch](flawed-10-defects-and-latch.png) | All normalized flaws can be read by scrolling; the overpressure shutdown message is visible and the metrics no longer overlap station controls. |

## Runtime/provenance evidence

[manifest.json](manifest.json) records commit, run, machine, operator, exact engine
arguments, UTC frame times, seeds, ticks, chemistry metrics, hashes and all **403
passing assertions**. [walkthrough.txt](walkthrough.txt) records captures, actual
GUI hit targets, activation counts and final success. [SHA256SUMS.txt](SHA256SUMS.txt)
identifies the unchanged PNGs. The exact launcher is in
`.github/workflows/render-proof.yml`: official Godot 4.4.1, X11, OpenGL3 compatibility,
Dummy audio, 1366×740, and a bounded hosted-only walkthrough under Xvfb.

The renderer was Mesa llvmpipe LLVM 20.1.2. A 30-frame sample measured 29.82 FPS /
33.53 ms on this software renderer; this is not a gaming-PC benchmark, advanced
renderer validation or a ray-tracing claim. No Godot, installer or game ran on
James's PC and no desktop control was taken.

The independent artifact review found no Critical/Important visual defect.
Minor frame inconsistencies remain recorded: Prime/Regulator labels appear absent
in the two cooling frames and the Brew Desk heading appears absent in one
fermentation frame, while surrounding controls and required settings remain
readable in adjacent frames. No unverified root cause is asserted. These should
be tracked during subsequent renderer validation.

This supplies the previously missing normal/flawed single-player visible
walkthrough evidence. It does **not** accept the full game: visible two-client
combat/staging/claims, advanced beer/fire visuals, the interlocked companion,
integrated demonstration, MSI upgrades and final Release remain separate gates.
