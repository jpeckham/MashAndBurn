# Authoritative multiplayer gameplay implementation plan

> **For agentic workers:** Execute inline with superpowers:executing-plans and test-driven-development. Run Godot only on GitHub-hosted machines.

**Goal:** Deliver the inherited `rounds-combat` and `fire-claims` tasks without changing the approved Godot architecture or shrinking the 2–8-player scope.

**Spec:** `docs/handoff/inherited-plan.json`, multiplayer-gameplay milestone; `docs/prompts/mash_burn_prd.md` sections 3.3 and 3.5 safety interlocks.

**Architecture:** A deterministic `RefCounted` round authority owns all player/batch, movement, weapons/projectiles, sabotage, round clock and result state. ENet is an identity-bearing transport; a client submits bounded intents, never position/damage/money/state. A registered garage module supplies lobby/HUD/actions and a session adapter routes existing brew controls to the authority. Fire and insurance are fictional game rules with server-owned 45-second windows and immediate disarm latches.

**Interfaces:** `RoundAuthority.initial_state(seed, host_peer=1) -> Dictionary`; `join(state, peer, name, token, reconnect=false)`, `disconnect_peer(state, peer)`, `begin(state, peer)`, `submit(state, peer, command)`, `advance(state, dt)` return `{ok,state,events,error}` plus join identity/token when applicable. State transitions return copies. `snapshot(state)` omits reconnect credentials and peer mapping. Network nodes share a fixed RPC path, bind sender identity from ENet, reject oversized/unknown messages, and publish only server snapshots. Each command carries protocol version, round ID, strictly consecutive sequence, and a recently observed server tick. Invalid commands cannot advance acknowledgements.

Ruling: name the domain transition `disconnect_peer`, because Godot Object already defines the incompatible signal method `disconnect`; observed hosted parse failure in run 45658259324. Behavior and tests are unchanged.

## Constraints and rulings

- Production clock: fixed 0.1-second ticks; round ends at 900 seconds. Server simulation advances brewing by 60 simulated seconds per tick (600x), allowing a complete batch within a round. Client speed controls cannot change this.
- Host chooses pale ale/lager/stout judging target. Missing final packaging receives an explicit incomplete-batch penalty.
- Five arsenal categories: wand blindness/slip, ladle scald, hydrometer melee, moving keg projectile, moving bottle projectile. Three sabotage categories: chiller loss, contamination, burner redline. Effects/cooldowns/ranges/health are bounded game constants.
- Disconnected players retain a reserved identity during an active round; reconnect needs a server-issued private token and preserves ordering/cooldowns/hazards. Lobby disconnect frees its slot. No remote action can lift a hazard latch.
- Fire models abstract heat/fuel/smoke and neighboring bays, not real ignition instructions. Abstract boil-over/cord/dust categories enter a 45-second staging period; smoke can kill, and escape requires reaching the exit. Receipts/equipment/evidence are fictional objects. Server inspection applies one 1.5x replacement payout or penalty; no client-supplied verdict/value.
- Round/module registration is deterministic. Local single-player remains available when disconnected. Multiplayer saves and local time skips are disabled through the session adapter.
- Runtime network smoke uses actual ENet clients on a hosted runner; accelerated test time is documented and cannot be selected by a remote client. Visible playthrough proof remains a separate gate.

## Tasks

### 1. Authority and game rules

Files: `src/gameplay/rounds/round_authority.gd`, `src/gameplay/fire/fire_claims.gd`, `tests/gameplay/test_gameplay.gd`, `tests/run_all.gd`.

- [x] Add failing tests for capacities 2–8, unsupported joins, ready/start ownership, clock boundary, replay/late/out-of-order/forged inputs, own-batch-only editing, weapons and sabotage, projectiles and disconnect/reconnect.
- [x] Observe failure on hosted runner before implementation (665 checks, two intended missing-module failures in run 45657368683).
- [x] Implement functional authority and fixed-step clock. Preserve existing protocol validation and chemistry; separate command application from integration after review.
- [x] Pin fire disarm ordering, 45-second boundary, escape/lethal smoke, deterministic inspection, 150% payout and no duplicate award in tests; implement logical fire rules.
- [x] Run combined hosted checks; resolve failures from actual logs. Final run 45662199180: 833 checks pass.

### 2. Transport and usable garage integration

Files: `src/gameplay/network/match_network.gd`, `src/gameplay/network/remote_brew_session.gd`, `src/gameplay/multiplayer_module.gd`, `project.godot`, `tests/integration/`.

- [x] Add ENet host/join/leave, authenticated RPC identity, snapshot/ack/error delivery and reconnect lifecycle.
- [x] Register lobby/HUD, weapon/sabotage/claims controls, placeholder rivals/projectiles/fire feedback and existing brew-desk routing (visible usability still unverified).
- [x] Add real 2-/8-client hosted sessions with refused extra join and authoritative round completion. Reject bad protocol/replayed input; disconnect/server loss never enables local authority.
- [x] Verify exported-game startup and update instructions and evidence.
- [x] Exercise full garage UIs as the actual network endpoints and consume authoritative final judging/feed results (hosted869-check run; visible two-window proof remains separate).
- [x] Complete spatial staging objects and richer inspection feedback from PRD scope, including proximity/E, avatar stress, burn/valve evidence and observed transient-visual lifecycle in hosted integration tests.

### 3. Milestone evidence

- [x] Run the combined suite after gameplay changes and inspect remote logs.
- [x] Document commands, game approximations, transport behavior and unresolved visual/companion proof in docs/gameplay.md and evidence/multiplayer-hosted-2026-11-25.md. Domain fixtures use seed 812; ENet fixture logs name participant count and server clock.
- [ ] Collect actual two-client visible evidence remotely before calling this milestone accepted. Do not substitute headless tests for this gate.

## Client integration and spatial gameplay follow-through

The previous 833-check run validated raw transport endpoints and local widgets,
but not complete garage scenes sharing final results over ENet. Remaining PRD
scope includes the actual staging props/old Buick trunk and character-tell feedback.

- [x] Add a hosted `client` suite with full garage scenes under separate SceneMultiplayer roots; exercise the actual Set widget, authoritative stout judging, bounded feed pages and exact local-batch restoration. Lobby methods are not yet tested through rendered input.
- [x] Observe failures before implementation: run45663969698 reported nine intended failures. Fixtures that jump the server clock or fabricate a packaged batch are not full brewing playthrough proof.
- [x] RemoteBrewSession exposes an immutable final judging context only after finished results; tasting uses exact server categories/feedback/style.
- [x] Create receipt/evidence/Buick-trunk props at shared world points and enforce1.25m server proximity; verify E and progress over actual garage ENet endpoints.
- [x] Seeded inspection records burn/thermal trace, valve and avatar stress; escaping lets stress settle. No real biometric data is read.
- [x] Wands leave bounded, expiring floor patches; verify client rendering, expiry/freeing and leave cleanup.
- [x] Combined hosted checks pass869; independent source review found no Critical/Important issue. Single-player render403checks/20frames is inspected; visible two-client proof remains the next task.
