# Authoritative multiplayer gameplay implementation plan

> **For agentic workers:** Execute inline with superpowers:executing-plans and test-driven-development. Run Godot only on GitHub-hosted machines.

**Goal:** Deliver the inherited `rounds-combat` and `fire-claims` tasks without changing the approved Godot architecture or shrinking the 2–8-player scope.

**Spec:** `docs/handoff/inherited-plan.json`, multiplayer-gameplay milestone; `docs/prompts/mash_burn_prd.md` sections 3.3 and 3.5 safety interlocks.

**Architecture:** A deterministic `RefCounted` round authority owns all player/batch, movement, weapons/projectiles, sabotage, round clock and result state. ENet is an identity-bearing transport; a client submits bounded intents, never position/damage/money/state. A registered garage module supplies lobby/HUD/actions and a session adapter routes existing brew controls to the authority. Fire and insurance are fictional game rules with server-owned 45-second windows and immediate disarm latches.

**Interfaces:** `RoundAuthority.initial_state(seed, host_peer=1) -> Dictionary`; `join(state, peer, name, token, reconnect=false)`, `disconnect(state, peer)`, `begin(state, peer)`, `submit(state, peer, command)`, `advance(state, dt)` return `{ok,state,events,error}` plus join identity/token when applicable. State transitions return copies. `snapshot(state)` omits reconnect credentials and peer mapping. Network nodes share a fixed RPC path, bind sender identity from ENet, reject oversized/unknown messages, and publish only server snapshots. Each command carries protocol version, round ID, strictly consecutive sequence, and a recently observed server tick. Invalid commands cannot advance acknowledgements.

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

- [ ] Add failing tests for capacities 2–8, unsupported joins, ready/start ownership, clock boundary, replay/late/out-of-order/forged inputs, own-batch-only editing, weapons and sabotage, projectiles and disconnect/reconnect.
- [ ] Observe failure on hosted runner before implementation.
- [ ] Implement functional authority and fixed-step clock. Preserve existing protocol validation and chemistry.
- [ ] Pin fire disarm ordering, 45-second boundary, escape/lethal smoke, deterministic inspection, 150% payout and no duplicate award in tests; implement fire rules.
- [ ] Run focused/combined hosted checks; resolve failures from actual logs.

### 2. Transport and usable garage integration

Files: `src/gameplay/network/match_network.gd`, `src/gameplay/network/remote_brew_session.gd`, `src/gameplay/multiplayer_module.gd`, `project.godot`, `tests/integration/`.

- [ ] Add ENet host/join/leave, authenticated RPC identity, snapshot/ack/error delivery and reconnect lifecycle.
- [ ] Register lobby/HUD, weapon/sabotage/claims controls, rivals/projectiles/fire feedback and existing brew-desk routing.
- [ ] Add real 2-/8-client hosted sessions with refused extra join and authoritative round completion. Reject missing host, bad protocol, replayed input and server loss without local authority fallback.
- [ ] Verify exported-game startup and update instructions and evidence.

### 3. Milestone evidence

- [ ] Run the combined suite after gameplay changes and inspect remote logs.
- [ ] Document reproducible seeds, commands, game approximations, transport behavior and unresolved visual/companion proof.
- [ ] Collect actual two-client visible evidence remotely before calling this milestone accepted. Do not substitute headless tests for this gate.
