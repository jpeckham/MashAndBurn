# Mash & Burn continuation

## Owner requirements

- Finish the existing approved Godot prototype plan, not only the vertical slice.
- Remove this project's activity from Beluga and continue in this checkout.
- Do not launch Godot, the game, its editor or tests on James's PC, or take over his desktop. Earlier runs reportedly locked up the PC.
- Deliver GitHub Releases with MSI installers. Reusable Godot release tooling belongs in `../.github` (`jpeckham/.github`).

## Recovered state (2026-11-25)

Branch: `codex/continue-mash-and-burn`. Recovered all four commits through `dc6bd8f` from the clean existing worktree, preserving history. `main` was left unchanged.

Beluga was not running when its offline state was edited. Removed the project's plan, 16 board tasks, three workspace registrations, histories, eight execution records, environment overrides and project statistics. Removed project discovery registration and added the root to the exclusion list. Other projects remain registered.

Private recovery backup: `C:/Users/james/.codex/handoffs/mash-and-burn-20261125-102647`. Contains the original metadata and a verified Git bundle of the complete recovered branch. Backups are outside Beluga. The original worktree was removed after confirming the recovered source and clean state; its historical branch remains as a recovery reference.

The complete inherited scope and acceptance criteria are preserved in [the plan](handoff/inherited-plan.json) and [task records](handoff/inherited-tasks.json). These are historical records, not an active scheduler. Historical machine-local launch instructions do not override the current no-local-execution requirement.

## Evidence and outstanding work

- Brewing/contracts, garage UI/save-load, judging and fictional feed code exists. Fresh hosted Windows validation passes **869 checks**, actual two-/eight-client ENet, full garage UI integration, export/startup and MSI install/payload-hash/uninstall.
- Normal/flawed single-player visible proof is now collected and inspected: [20 unchanged hosted X11/Mesa frames](../evidence/desktop/2026-11-25-hosted/README.md), **403 passing GUI input assertions**, walking/look/E, pause/resume, exact reload, five-category judging and feed pages1/2/32. This supersedes the old request for owner desktop access. No game ran on James's PC.
- Multiplayer code includes authoritative final judging/style/feed consumption, real garage endpoints, bounded movement/projectiles, five arsenal/three sabotages, lobby/HUD, remote brew-desk routing and reconnect. Sanitizing wands create bounded, expiring floor patches. Visible multi-window playthrough remains unproven.
- Fire/claims now includes spatial receipt/evidence/Buick-trunk props with server proximity checks and E interaction; seeded inspection exposes burn/thermal, valve and avatar-stress evidence. Hosted integration verifies E through the viewport/ENet, prop progress, floor expiry/freeing and leave cleanup. Full 45-second windows, late settlement, escape/smoke, exactly-once payouts and disarm remain covered. A visible multiplayer traversal is still required.
- Visuals: chemistry-driven SRM/haze/foam/nucleation, steam/condensation/fire, feature fallback and measured remote performance. Do not claim PS5 or hardware ray tracing parity.
- Companion: mock HAL and telemetry at 10 Hz; fault/E-stop/stale-frame/thermal/fire interlocks and explicit rearm; optional authenticated private-channel notifications disabled by default.
- Integration: combined suites, eight-client scripted and two-client visible scenarios, PRD traceability, licenses, exports, MSI install/upgrade/uninstall and GitHub Release assets.

## Execution decisions

Keep the approved Godot/GDScript stack and extension points. Use GitHub-hosted runners for Godot validation and installer checks. Do not treat headless results as proof of visual usability. Build development installer artifacts before publishing a final release.

Release tooling is implemented on `codex/godot-msi-releases` in `../.github` and pushed. The game caller pins workflow and scripts to commit `84765dd4877453dc01be8dcb33c8dc89f68b3e9d`. Hosted [run 45655665366](https://github.com/jpeckham/MashAndBurn/actions/runs/45655665366) succeeded for game commit `92ffcdbe89acd5aa697fb4646f4c8cdde91b978e`: 663 checks, Windows export, exported-game headless startup, MSI creation, installation/payload-hash verification and uninstall. Both logs and a development MSI are retained as workflow artifacts. See [evidence](../evidence/hosted-validation-2026-11-25.md).

Two setup issues were resolved from actual failed runs: decoding the official checksum file's byte response and disabling optional executable resource editing without rcedit. MSI supplies product identity. No final release has been published.

Hosted [run 45662199180](https://github.com/jpeckham/MashAndBurn/actions/runs/45662199180) succeeded for source `8644e6a7f9dd47487c6b517875808ecd87edb859`: **833 checks**, real ENet sessions with two/eight clients, import/export, exported-game startup, MSI creation/install/payload hashes/uninstall. [Detailed evidence](../evidence/multiplayer-hosted-2026-11-25.md) and [independent review/fixes](../evidence/multiplayer-review-2026-11-25.md) are recorded. The review found four Important issues; regression tests reproduced them and all now pass. No Godot, game, installer or desktop automation ran on James's PC.

Latest source `10ab1aa9a4a8adde2fb397c7355f7a535a2750eb` passed [Windows run45668069722](https://github.com/jpeckham/MashAndBurn/actions/runs/45668069722), 869 checks and the installer pipeline; [render run45668068521](https://github.com/jpeckham/MashAndBurn/actions/runs/45668068521) passed403 assertions and generated20 inspected frames. Normal score86.1, flawed score39.8. Single-player media revealed and drove a real fix for metric overflow. A test-fixture wheel focus defect was diagnosed from hit traces and official Godot source, then fixed with paired wheel releases; GUI buttons still must activate exactly once.

Independent source review of the follow-through (`2b24855..4189dc2`) found no Critical/Important issues. Follow-up artifact review inspected14frames; root inspected the other6. Both verified20PNG hashes. Minor label omissions in a few Mesa frames are recorded in the evidence index, without a claimed root cause. This is not acceptance of missing multiplayer/renderer/companion gates.

Next: execute [visible multiplayer plan](superpowers/plans/2026-11-25-visible-multiplayer.md) with actual hosted host/guest windows, GUI-driven complete recipes and spatial fire/claims; then implement advanced beer/fire visuals and the interlocked companion. Still required: final integrated demonstration/PRD traceability, license and payload inventory, MSI upgrade/downgrade verification and GitHub Release assets. Do not revive the old owner-desktop-access blocker. Final release waits for all inherited acceptance criteria and installer gates. No final release tag has been created.
