# Optional local mock companion

This Python3.12 service mirrors simulated telemetry into a mock HAL. It does not
operate physical devices. Serial/MQTT/WebSocket mock framing and a bounded
simulated waypoint cursor are implemented; `physical-*` configurations always
refuse arming. Independent firmware cutoff, calibration and physical validation
are prerequisites for future real drivers.

The game and daemon work independently. Installing the game MSI starts no daemon
and makes no companion or notification connection by default.

## Start and stop

In the extracted companion directory, create a Python3.12 virtual environment
and install `requirements.txt`. Its constraints lock the validated dependencies.

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

In a daemon-only terminal, set `MAB_BRIDGE_TOKEN` to a locally generated32–256
character printable ASCII secret. Set `MAB_OPERATOR_TOKEN` to a **different**
secret if operator controls are wanted, then run:

```powershell
.\.venv\Scripts\python.exe -m mash_burn_bridge --host 127.0.0.1 --port 27842
```

The service binds only loopback. It never reads `.env` files. Missing operator
configuration disables operator actions. Keep the operator secret out of the
game process. Launch the game from a separate terminal with **only** the matching
`MAB_BRIDGE_TOKEN` and optional `MAB_BRIDGE_URL` set. The default game endpoint is
`ws://127.0.0.1:27842/api/v1/telemetry`. Resume a local batch or start a multiplayer
round, then click **Send mock telemetry** in the brew desk.

Operator actions require the operator bearer token, loopback caller and explicit
confirmation. For example, in a separate operator terminal:

```powershell
$operatorHeaders = @{ Authorization = 'Bearer <distinct-operator-secret>' }
Invoke-RestMethod http://127.0.0.1:27842/api/v1/arm -Method Post -Headers $operatorHeaders -ContentType application/json -Body '{"confirm":true}'
```

`POST /api/v1/estop` stops and latches. `POST /api/v1/estop/clear` with
`{"confirm":true}` leaves outputs off; a new healthy frame and another explicit
arm action are required. `POST /api/v1/disarm`, **Stop mock telemetry**, closing
the game, or Ctrl+C in the daemon all stop outputs. Telemetry credentials cannot
arm, clear E-stop or plan motion. Read-only `GET /api/v1/status` accepts either
credential and exposes mock outputs and simulated position, never secrets.

## Interlocks and protocol

Game frames target10Hz of real time, independently of600× brewing time. They
extend the common v1 `HardwareFrame` with bounded step/temperature/pump/three
valves/hopper, UTC milliseconds, sensor/connection/E-stop/hazard fields.
`mash_burn_bridge.models.HardwareFrame` is the canonical strict schema; release
archives include its generated JSON Schema. Pump aliases must agree. Disabled
or safe-state frames must request zero heater/pump, closed valves and no hopper.

The daemon and producer latch off on malformed/nonfinite/replayed/stale frames,
missed heartbeat, disconnection, missing/error sensors, E-stop, fire/staging,
or measured temperature>=102C. Heartbeat maximum is300ms; future timestamps
over100ms are rejected. An expired old heartbeat is checked before a fresh frame
can replace it. Queued work is discarded; healthy frames never rearm outputs.
Only one authenticated telemetry socket owns a stream. A new socket starts
disarmed with a fresh sequence scope. The sensor is simulated game data, not
independent physical sensor proof. Heating uses a demonstration proportional
limiter, not a calibrated physical PID.

`POST /api/v1/arm/plan` is operator-only and requires a healthy armed mock.
`{"points":[[0.02,0.0,0.2]]}` schedules at most16 finite3D waypoints inside
x/y±0.3m and z0.1–0.5m. The simulated cursor moves at most0.1m/s and freezes on
fault. This is not six-axis inverse kinematics or a calibrated collision model.

## Optional private alerts

All outbound alerts default off. The daemon requires
`MAB_NOTIFICATIONS_ENABLED=true`, `MAB_NOTIFICATION_CONSENT=true`, and an exact
private destination allowlist in `MAB_PRIVATE_CHANNELS_JSON`, for example:

```json
{"friends":{"url":"https://private.example.invalid/webhook","consent":true,"private":true}}
```

The game separately requires `MAB_PRIVATE_ALERTS=true` and
`MAB_PRIVATE_DESTINATION=friends`, plus its telemetry credential/loopback URL.
Only below45 scores or severe butter/green-apple flaws enqueue an alert after
authoritative tasting. The512-persona game feed remains local. No public bot or
account API is implemented. Only recipe/tasting information is sent to the
configured consenting private receiver; credentials are not forwarded.

The service requires HTTPS except for loopback receivers, follows no redirects,
deduplicates events for one hour, defaults to5logical deliveries/channel/minute
and caps global deliveries at20/minute. Retries are bounded to3attempts; failed
events remain deduplicated. Game requests are bounded and do not retry. Delivery
is best effort; configuration alone dispatches nothing.

## Validation and distribution

GitHub-hosted Linux/Windows jobs run the safety/API/private receiver tests. A
separate job runs an actual headless Godot garage against a real local daemon
and fake private receiver, recording10Hz telemetry, independent operator
arm/E-stop/rearm, game fire/disconnect, persistent latch and one private alert.
Its controlled judging fixture is not a complete brewing playthrough or
physical hardware evidence. Visible brewing has a separate hosted proof.

The source ZIP contains only tracked source, schemas, a source hash inventory
and public installed-dependency notices. It excludes `.env`, caches and runtime
evidence; it does not vendor Python or dependency implementations. Engine
notices installed by the game MSI are separate. No new license is assigned to
this project's original work.
