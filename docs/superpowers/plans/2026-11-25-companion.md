# Safe mock companion implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Finish the inherited companion/HAL and opt-in private notification requirements without requiring physical hardware.

**Architecture:** A decoupled Python FastAPI daemon accepts authenticated v1 telemetry over a loopback WebSocket. A pure interlock controller validates frames, clocks and sensors before any mock outputs; all fault paths latch disarm and clear queued work. The game emits read-only 10 Hz frames through an opt-in module. Private notifications use an authenticated disabled-by-default endpoint and a strict configured destination allowlist with explicit consent.

**Tech stack:** Python 3.12, FastAPI/Pydantic, pytest, Godot 4.4.1 WebSocketPeer. Pin versions after verifying official package metadata.

**Spec:** `docs/handoff/inherited-tasks.json`, mock HAL/private notification task and MAB-12; `src/contracts/` protocol v1; approved inherited plan.

## Global constraints

- All daemon, game and installer execution/tests use disposable GitHub-hosted runners. No desktop takeover or game execution on James's PC.
- Mock mode works without physical devices. No physical actuation claim; firmware cutoff, calibration and verified hardware safeguards are prerequisites for real actuation.
- Never read `.env` or disclose tokens. Document configuration names; notifications disabled by default and use only explicitly consenting private configured destinations.
- No automatic rearm. Fire/staging, E-stop, malformed/stale/disconnected/missing-sensor/thermal-cutoff frames stop outputs and clear commands.
- The existing v1 HardwareFrame's common fields remain compatible. The bridge requires additional bounded telemetry/interlock fields; its stricter safety boundary does not relax the common protocol.

## Review focus

- Authenticated but malformed frames must latch disarm, not merely return validation errors while outputs continue.
- A healthy frame after a fault cannot resume outputs without a fresh explicit local arm action.
- Wall-clock skew, replay, scheduler catch-up and connection replacement must not retain stale commands.
- Real transport configuration or a client-supplied flag cannot bypass firmware/calibration verification.
- Notification retries, deduplication and allowlist checks must apply to redirects and failures as well as first attempts.

## Tasks

### 1. Controller and frame contract

- [ ] Write hosted failing pytest for a strict frame model, finite bounds/version, timestamps, sequence, rate scheduling and all safety interlocks.
- [ ] Add `companion/mash_burn_bridge/models.py`, `controller.py`, `transports.py`: safe mock serial/MQTT/WebSocket round-trips, bounded Tier1 outputs and simulated Tier2 waypoint planning. Physical adapters remain incapable of arming without independently verified safeguards; no client-controlled attestation.
- [ ] Explicit arm requires a fresh healthy frame, healthy sensors, cleared E-stop and a local action. Faults reset outputs and queues; test recovery from every cause.
- [ ] Pin dependencies in companion requirements and run hosted unit tests; preserve machine-readable disconnect/E-stop trace.

### 2. Daemon and private notifications

- [ ] Write endpoint/WebSocket tests first, including auth, malformed input while armed, stale heartbeat and duplicate connections.
- [ ] Implement `app.py` and CLI: loopback bind by default, bearer token, bounded frames, separate explicit local arm/disarm endpoints, 10 Hz controller watchdog, clean safe shutdown.
- [ ] Implement `notifications.py`: disabled default, global and destination consent, exact configured private destination IDs, constant-time token auth, bounded payload, event dedupe, per-channel rate limits and bounded retries with redirects disabled.
- [ ] Test against a local fake HTTP receiver, including invalid token/consent/allowlist, duplicates, rate limit and exhausted retries. No public service calls.

### 3. Game telemetry and integrated proof

- [ ] Write GDScript hardware tests for 10 Hz scheduling, v1 validation, finite outputs, strict ordering and immediate safe frames on fire/disconnect. Game cannot authorize daemon arm.
- [ ] Implement a telemetry producer and optional module using existing read-only batch/hazard hooks. Sending is off by default; enable only for configured loopback mock companion and keep tokens out of logs/media.
- [ ] Hosted integration runs actual daemon and two game endpoints, records normal 10 Hz frames followed by disconnect/E-stop/fire cutoff and explicit rearm behavior. Run combined suites once and preserve actual evidence.
- [ ] Document launch/stop, configuration names, safety limits, mocked/real boundaries, dependency notices and companion release packaging. Include companion source archive and hashes in final GitHub Release alongside the game MSI.
