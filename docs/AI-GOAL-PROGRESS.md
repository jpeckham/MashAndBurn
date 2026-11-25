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

- Brewing/contracts, garage UI/save-load, judging and fictional feed code exists. Fresh hosted validation now passes 833 checks, including the existing chemistry/contracts and the new gameplay/network cases; see the evidence below.
- Visible full-batch controls/save-load/feed proof remains unverified. No new desktop evidence exists.
- Multiplayer code is implemented: authoritative ENet 2–8 player rounds, five arsenal/three sabotage categories, bounded movement/projectiles, lobby/HUD, remote brew-desk routing and disconnect/reconnect. Actual hosted two-/eight-client tests finish the server's 900-second clock and reject overflow/money injection. Visible multi-window usability is not yet proven.
- Logical fire/claims code is implemented and tested: abstract heat/fuel/smoke/spread, a full 45-second staging window (including late incidents), escape/lethal smoke, seeded inspection, exactly-once 150% payout/penalty and immediate disarm. Spatial receipt/equipment/trunk/evidence props and richer burn-pattern/character-tell feedback still need PRD coverage/visible proof before milestone acceptance.
- Visuals: chemistry-driven SRM/haze/foam/nucleation, steam/condensation/fire, feature fallback and measured remote performance. Do not claim PS5 or hardware ray tracing parity.
- Companion: mock HAL and telemetry at 10 Hz; fault/E-stop/stale-frame/thermal/fire interlocks and explicit rearm; optional authenticated private-channel notifications disabled by default.
- Integration: combined suites, eight-client scripted and two-client visible scenarios, PRD traceability, licenses, exports, MSI install/upgrade/uninstall and GitHub Release assets.

## Execution decisions

Keep the approved Godot/GDScript stack and extension points. Use GitHub-hosted runners for Godot validation and installer checks. Do not treat headless results as proof of visual usability. Build development installer artifacts before publishing a final release.

Release tooling is implemented on `codex/godot-msi-releases` in `../.github` and pushed. The game caller pins workflow and scripts to commit `84765dd4877453dc01be8dcb33c8dc89f68b3e9d`. Hosted [run 45655665366](https://github.com/jpeckham/MashAndBurn/actions/runs/45655665366) succeeded for game commit `92ffcdbe89acd5aa697fb4646f4c8cdde91b978e`: 663 checks, Windows export, exported-game headless startup, MSI creation, installation/payload-hash verification and uninstall. Both logs and a development MSI are retained as workflow artifacts. See [evidence](../evidence/hosted-validation-2026-11-25.md).

Two setup issues were resolved from actual failed runs: decoding the official checksum file's byte response and disabling optional executable resource editing without rcedit. MSI supplies product identity. No final release has been published.

Hosted [run 45662199180](https://github.com/jpeckham/MashAndBurn/actions/runs/45662199180) succeeded for source `8644e6a7f9dd47487c6b517875808ecd87edb859`: **833 checks**, real ENet sessions with two/eight clients, import/export, exported-game startup, MSI creation/install/payload hashes/uninstall. [Detailed evidence](../evidence/multiplayer-hosted-2026-11-25.md) and [independent review/fixes](../evidence/multiplayer-review-2026-11-25.md) are recorded. The review found four Important issues; regression tests reproduced them and all now pass. No Godot, game, installer or desktop automation ran on James's PC.

Next: exercise full garage UIs as actual ENet endpoints, connect final authoritative judging/style/results to the fictional feed (current tasting module still judges the local mirrored batch), finish spatial staging props/inspection feedback, and collect actual remote rendered normal/flawed/two-client evidence. Then implement advanced beer/fire visuals and the interlocked companion; add MSI upgrade/downgrade validation and finish the combined PRD coverage/release gates. Do not let the old desktop-access prerequisite stall independent product work. Final release waits for all inherited acceptance criteria and installer gates. No final release tag has been created.
