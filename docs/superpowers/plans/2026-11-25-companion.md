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

## Execution ledger

- Safety first red: run45678098795, source4993c4a, missing controller/transports. First implementation619fb88 passed36 tests in45678460105.
- Additional version/hopper regressions: run45678646961, source9a33c94,3failed36passed. Fixed integer version validation and edge-triggering inc89af32;39passed in45679084010.
- API/private-channel red: run45679786367, source380cb90, missing app/config. Implementation5fc597c passed55 tests in45680366418. All outbound delivery tests use only a local fake receiver.
- Independent review found3Important issues: fresh input could hide an expired old heartbeat and preserve queued hops; clearing E-stop while armed left outputs active; the game token could also authorize arming. Tests reproduced all3 in45680989831, source14ea5c2 (3failed54passed).
- Fixed in8962ed5: check old heartbeat before replacing it, clear outputs/queue on E-stop clear, and require a distinct optional `MAB_OPERATOR_TOKEN` for operator actions. Telemetry/consenting notifications use `MAB_BRIDGE_TOKEN`; status is read-only with either. Missing operator configuration disables arming. The game never reads operator credentials. Read-only review confirmed all3 fixes; run45681412838 passed57 tests. State mutations run on one asyncio event loop.
- Physical serial/MQTT/WebSocket configurations are boundary stubs and cannot arm. Only the three mock framing adapters produce simulated outputs. No firmware cutoff/calibration/physical operation is claimed.
- Game producer red: Linux45681854800, source1253c53,945checks/one missing-producer failure. Sourcee196e73 implemented read-only10Hz scheduling, monotonic counters, bounded controls, one-shot hopper requests and immediate latched fault frames. Combined source1aa1f23 passed1001checks in45683168581, with403single-player GUI assertions and both renderer comparisons.
- Game transport red: Linux45683697223, source50bd2aa,1002checks/one missing-client failure. Sourcef49ba43 adds the opt-in loopback-only WebSocket client/module; default startup performs no I/O. It reads only telemetry credentials. A real Godot→FastAPI interoperability fixture is added in513ccc7; await its actual hosted execution before acceptance.
- Interoperability fixture: actual loopback ASGI/WebSocket server plus headless Godot garage, sanitized child environment with no operator credential, measured initial telemetry rate, telemetry-token arming rejection, separate operator arm/E-stop/clear/rearm, game fire, persistent latch after new batch, actual disconnect and trace/log artifacts. It is not a visible playthrough or physical hardware test.
- Still required: prove/fix actual interoperability, document/schema/dependency inventory and release packaging, optional game-side private alert consumption, final integrated demonstration and release gates.

### Continuation checkpoint

The preceding checklist/ledger is historical. Core controller, API, mock
transports, bounded simulated waypoint cursor, private notifications, game
producer/client, configuration documentation, generated schema and source/notices
packaging are implemented. Run45700200483 passes59pytest cases on Linux and
Windows, actual Godot/daemon E-stop/rearm/fire/disconnect and a single real
game-generated alert to a loopback fake. See [preserved trace](../../../evidence/companion/2026-11-25-hosted/README.md).

Run45701992650 additionally passes a single rendered host/guest fire session
against two actual mock companion endpoints: both independently armed, active
mock output observed, explicit guest fire/shared host latch and no unsafe frame
after cutoff. [Inspected artifacts](../../../evidence/multiplayer/2026-11-25-hosted/README.md)
include ten PNGs and the same-session bridge report. The full recipe/final-round
version of this combined session and final Release assets remain pending.

The full-session harness distinguishes a prior packaging-overpressure latch
from a fire-caused transition. Its short smoke requires the initial cutoff to
match explicit fire; the full scenario also requires safe telemetry during the
actual accepted GUI fire, even when packaging already latched the output off.
