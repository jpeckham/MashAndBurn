# Protocol v1

`protocol.gd` is the executable schema and rejection authority. `schema.json` provides JSON Schema tooling definitions; `examples.json` contains all five message kinds. JSON objects have version=1, type, nonnegative integer seq and tick counters <= 2147483647. Unknown types, versions, actions, missing fields, bad types and out-of-bound/nonfinite values are rejected. Extra object fields are reserved for additive compatibility; they do not authorize new actions. Dispatch rejects stale/future tick and any command seq other than last accepted seq+1. Empty command advances without incrementing seq. Events share the originating tick/sequence; array order is emission order.

All clocks are simulation seconds, never wall-clock; tick counts accepted advances. `apply_command` applies a control/stage intent without advancing tick or time; it increments seq. Time acceleration repeats fixed ticks, not a larger dt. Units: temperatures C (UI can display F); water litres; grain/sugar kg; hops/priming grams; hop alpha fraction; ions mg/L; IBU mg/L equivalent; gravity SG; pressure gauge psi; carbonation CO2 volumes. Fractions/flaws [0,1]. Batch units/bounds and generic command-editable fields are in BOUNDS; the multiplayer boundary separately rejects measured-state setters such as temp_c. Ions 0–2000 mg/L, hops <=32 charges of 0–500g, alpha 0–0.3. Sugar cannot exceed 80% of grain mass; fermented mass cannot exceed sugar. dt finite (0,60] seconds. Seed nonnegative <=2147483647. Stage readiness belongs to simulation, not transport.

HazardEvent reserves hazard, fire, disconnect and overpressure. Each latches safe_state; simulation stops chemistry updates while maintaining tick/time. HardwareFrame is inactive by default and must have heater=pump=0 whenever disabled or safe. No physical actuator implementation exists. Future companions must supply independent physical interlocks; the protocol alone cannot provide physical safety. JudgeResult contains five 0–20 categories summing to score 0–100, feedback and severe_flaws arrays.
# Optional companion envelope

The companion requires the common v1 HardwareFrame fields plus UTC milliseconds,
step, target temperature, matching pump aliases, three binary valves, optional
hopper, sensor/connection/E-stop and hazard/fire state. The executable strict
schema is `companion/mash_burn_bridge/models.py`; release archives include its
generated JSON Schema. Legacy minimal frames remain valid common protocol
examples but cannot authorize companion output without the safety envelope.
See `companion/README.md` for units, timing, interlocks and separate operator
authority. The game never receives operator credentials or authorizes arming.

