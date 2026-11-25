# Visible multiplayer proof implementation plan

> **For agentic workers:** Execute inline with superpowers:executing-plans. All engine/game activity stays on GitHub-hosted machines. This is the remaining inherited visible two-client gate, not a new product direction.

**Goal:** Record and inspect actual rendered host/guest windows completing multiplayer brewing, sabotage/fire/staging/escape/claims and authoritative tasting/feed, with source and machine provenance.

**Current foundation:** `tests/render/render_proof.gd` drives real GUI hit testing and Input events. Hosted run 45668068521 passed 403 assertions and generated 20 inspected single-player frames. `tests/client/test_client.gd` now validates actual garage/ENet endpoints, E staging and spill lifecycle; full suite passes 869 checks. Those tests are useful but do not replace this visible multiplayer session.

## Files and interfaces

- Refactor the render fixture's output destination into an instance variable and extract shared scene/watermark/profile bootstrap, preserving the existing single-player walkthrough.
- Create `tests/render/multiplayer_proof.gd`, extending the shared fixture, with `-- --role host` / `-- --role guest` command-line roles, separate output directories and per-role manifests.
- Create a hosted-only pair launcher under `tests/render/` and extend `.github/workflows/render-proof.yml` with an explicit pair option while iterating. Two actual Godot processes share a 3000×1000 Xvfb display at different window positions, each with its own 1366×740 viewport. Track process handles/exit statuses, bound runtime, retain partial logs on failure and stop remaining children if a peer fails.
- Keep test coordination files under `.tools/`; they coordinate fixture phases only. Gameplay intents still go through GUI/ENet. Never expose fixture clock control as a production RPC. Test files remain excluded from exported builds.

## Scenario

- [ ] Use actual lobby controls to set names, Host/Join, ready and start. Check model ownership through observed authoritative snapshots, not direct initial-state mutation.
- [ ] Both roles brew using existing GUI stage/settings/hop/package controls. Production server ticks remain 10 Hz and brewing speed stays 600x; no multiplayer time-skip button is used. Wait for readiness via snapshots, with bounded timers.
- [ ] Host brews a normal pale ale. Guest deliberately scorches one mash hour (target95 then restore66.7), ferments warm (initial candidate30 C; validate actual readiness/score), and overprimes1000 g. Adjust only actual GUI settings if needed to obtain an honestly observed below45 result; do not inject a JudgeResult or mutate flaws. Expect approximately six–seven minutes for the warm batch.
- [ ] Show that packaged batches wait for the server's final result rather than opening a local preliminary tasting.
- [ ] Host uses an actual wand control against the guest; capture blindness/floor feedback. Stop holding synthetic mouse buttons before another window's actions.
- [ ] Guest starts a fictional cord incident through controls and walks to receipt/evidence/Buick props using actual WASD/right-mouse input, stages with E and escapes at the exit. Read authoritative positions to steer the fixture; do not teleport the player. Capture each prop progress state, smoke/stress, escape and the resolved payout.
- [ ] Host waits at the exit and escapes any propagated incident. Record the actual outcomes and allow all 45-second windows to finish; do not truncate them at fixture boundaries.
- [ ] Once both recipes and claims have been observed, the host fixture may fast-forward its remaining fixed ticks to9000 to avoid a fifteen-minute wall-clock wait. Label that action explicitly in manifests/logs; a remote client must never request it. Brewing/claims themselves must already have occurred at production speed.
- [ ] Capture both final authoritative tasting panels and guest feed pages1,2,32 using real controls, then exact local-batch restoration after leaving. Record all actual scores/seeds/ticks and actor positions.

## Evidence and boundaries

Use bounded role watchdogs (e.g.14minutes) and a hosted job budget sufficient for both full recipes and fire windows (e.g.18minutes), not unbounded sleeps. While a job runs, root should poll that exact live run and continue independent useful work. No testing or desktop capture on James's PC.

Every frame needs exact source/run/role/window/date/machine/operator provenance and unchanged hashes. Download and inspect all claimed frames; distinguish rendered observations from runtime assertions. Preserve accepted media in the repo or durable release artifacts. The prior minor missing-label observations on Mesa remain tracked, without inventing a cause.

This proof still will not complete advanced beer/fire rendering, companion/HAL safety integration, license/payload inventory, MSI upgrade/downgrade tests or the final end-to-end Release. The final combined scenario must include those components once implemented.
