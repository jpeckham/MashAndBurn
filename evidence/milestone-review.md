# Milestone 1 validation — 2026-11-24

Machine: james's Windows PC. Branch: `beluga/mab-1-playable-brewing-vertical`. No PR, push or merge.

## Verified

- Godot reports `4.4.1.stable.mono.official.49a5bc7b6`, installed at `C:/Program Files/Godot/Godot_v4.4.1-stable_mono_win64_console.exe`.
- Python reports 3.11.9 at `C:/Users/james/AppData/Local/Programs/Python/Python311/python.exe`. No Python packages required.
- Desktop engine startup reported OpenGL 3.3.0 NVIDIA 621.14, compatibility renderer, NVIDIA GeForce RTX 3080 Ti. The engine executable launched the project into a running desktop process. Its window was enumerated as `Mash & Burn (DEBUG)`; visual appearance and control usability were not observed.
- MAB-1 began with expected red deterministic/formula tests (evidence/mab1-red.txt). Focused chemistry originally passed 42 checks; contracts passed 24.
- MAB-2 began with a failing routing/save test. Focused presentation originally passed 22 checks. JSON integer-counter restoration fixed save/hash continuation. Final presentation has 24 passing checks.
- MAB-3 began with a failing feed-boundary test. Focused social has 567 passing checks, including all 512 unique personas and integration of the tasting UI/module, 16-row replacement, and paging bounds.
- Integration regressions were observed failing then passing for new batch identity and combined sensible/latent heat conservation.
- **Whole milestone suite was run once, after integration: 663 checks, zero failures, exit 0.** See milestone-headless.txt. Includes complete batch through every stage to judging, invalid numeric/dt input, formula fixtures, fixed-tick identical hashes, malformed contracts/saves, deterministic reload continuation, boundary triggers, severe flaws and procedural reproduction.
- Godot headless editor static scan passed without GDScript errors (mab3-static.txt). A headless launch of the main scene also exited successfully.

## Desktop smoke limitation — milestone not passed

The required observed full-batch desktop smoke demonstration and screenshots **were not completed**. Windows Computer Use listed the actual running Godot window, then rejected access: `Computer Use was not approved to use 1-stable_mono_win64`. A user card asked to enable Godot computer-use access, with Done / Done elsewhere / Not now choices. No affirmative answer was received during implementation. No alternative automation route was used to bypass that restriction. The test desktop process was stopped.

The full-batch headless trace is evidence of simulation completion, not a substitute for the desktop smoke requirement. No screenshots or video are claimed. In the original implementation session, `ffmpeg` was not found on PATH; the MAB-14 tool check below supersedes that availability result. No export templates, packaged executable export, physical hardware, multiplayer, ray tracing or external dispatch were tested or claimed. Godot launches project.godot using the documented installed executable.

## Reproduce the remaining desktop check

1. Enable Godot desktop computer-use access, then launch the README command.
2. Observe garage geometry and onscreen metrics; hold right mouse and WASD to move, use E and station visit buttons.
3. Mash +1h; save and load; Next. At boil add 30g hops; +1h; Next.
4. At cooling +1h; Next. Fermentation +4h twelve times; Next. Package & judge.
5. Record category scores/feedback and screenshots. Repeat a deliberately flawed batch (hot mash, warm fermentation or excess priming) to inspect the sandbox feed and page navigation. There are no network dispatch controls.

## Known model/product limits

Approximations and fixtures are documented in docs/architecture.md. All randomness takes explicit seed/tick. Determinism targets matching Godot/platform and identical tick/command sequences, not cross-platform floating-point identity. Fermentation and packaging are accelerated game approximations; bottle conditioning is instantaneous. Feed deduplication is per running app session; it resets on app restart. The UI uses original primitive geometry and a built-in font. Visual QA remains pending the access above.

## MAB-14 proof reconciliation — 2026-11-24

Product revision checked: `4acdd863ff687016052f1ebb2ecfe7df510f16cb`, branch `beluga/mab-1-playable-brewing-vertical`, james's Windows PC. Collection was prepared around 20:04 America/Chicago. No product code changed, no suite was rerun, and all previous logs were preserved.

Fresh tool checks confirm Godot `4.4.1.stable.mono.official.49a5bc7b6`, Python 3.11.9, and FFmpeg `8.1.1-essentials_build-www.gyan.dev`. FFmpeg exists at `C:/ffmpeg/bin/ffmpeg.exe` and the current PATH lookup resolves there. See the [desktop proof collection index and tool logs](desktop/README.md). Renderer details above remain prior startup output; they were not newly visually verified. There is no Mac app or npm e2e to run.

The supported owner-access prerequisite remains unresolved. An owner question requests Godot access enabled through the supported permission flow or an owner recording for inspection. No alternate capture/automation route has been used. No new desktop media has been collected or inspected; the collection index is a procedure, not proof of completion.

Live MAB-1/2/3 briefs were read. MAB-1's implementation/headless checks remain separate from desktop proof. MAB-2's deferred desktop walkthrough remains an unmet requirement and does not waive milestone criteria 1 or 4. MAB-3's 663-check proof remains valid automated evidence; its desktop completion criterion remains unmet. MAB-14 cannot supply a complete proof package for independent milestone recheck until authorized or owner-recorded media is inspected. The milestone remains **not passed**.
