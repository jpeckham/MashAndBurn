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

- Brewing/contracts, garage UI/save-load, judging and fictional feed code exists. Historical logs report 663 checks; these are inherited results, not a fresh run here.
- Visible full-batch controls/save-load/feed proof remains unverified. No new desktop evidence exists.
- Multiplayer: authoritative ENet 2–8 player 15-minute rounds; five arsenal and three sabotage categories; invalid/replayed commands, reconnect/disconnect, capacity checks.
- Fire/claims: abstract fire/smoke, 45-second staging, escape, inspection, exactly-once 150% payout or penalties, immediate latched hardware disarm.
- Visuals: chemistry-driven SRM/haze/foam/nucleation, steam/condensation/fire, feature fallback and measured remote performance. Do not claim PS5 or hardware ray tracing parity.
- Companion: mock HAL and telemetry at 10 Hz; fault/E-stop/stale-frame/thermal/fire interlocks and explicit rearm; optional authenticated private-channel notifications disabled by default.
- Integration: combined suites, eight-client scripted and two-client visible scenarios, PRD traceability, licenses, exports, MSI install/upgrade/uninstall and GitHub Release assets.

## Execution decisions

Keep the approved Godot/GDScript stack and extension points. Use GitHub-hosted runners for Godot validation and installer checks. Do not treat headless results as proof of visual usability. Build development installer artifacts before publishing a final release.

Release tooling is implemented on `codex/godot-msi-releases` in `../.github` and pushed. The game caller pins workflow and scripts to the same commit. Run `45655340031` freshly passed all 663 checks on hosted Windows with standard Godot 4.4.1. Export then failed because the preset requested missing rcedit. Resource editing is now disabled for the prototype executable; product identity is supplied by MSI metadata. The first run's checksum-byte handling failure is fixed. No passing end-to-end installer run is claimed yet.

Next: inspect the latest hosted run, resolve failures, add MSI upgrade validation, and record actual evidence. Then continue all remaining product milestones above. No final release tag has been created.
