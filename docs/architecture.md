# Milestone 1 design and execution

The supplied plan is executed inline, one commit per MAB task. Godot 4 GDScript avoids a .NET build dependency; a SceneTree harness needs no addons. The alternative of a C# chemistry library adds tooling with no benefit for this slice. The existing PRD is unchanged.

- MAB-1: write failing replay/formula tests, implement protocol validation and pure `advance(state, command, dt_seconds)`, run chemistry/contracts independently.
- MAB-2: write routing/save tests, build original primitive 3D garage and onscreen controls, verify parsing and focused presentation tests.
- MAB-3: write boundary/deduplication/seed tests, implement judging and lazy local feed, run focused social tests and one whole milestone suite; demonstrate desktop batch.

Review focus: malformed saves, numeric nonfinite input, wrong tick/sequence, stage readiness, rendering bound. These have dedicated tests in their owning task.

## Determinism and boundaries

Simulation owns no nodes, clock, files, globals, network or hardware. Calls deep-copy state and return `{ok,state,events,error}`. Fixed 60 s ticks are used by the presentation; arbitrary finite dt in (0,60] is accepted but replay requires identical dt/command sequence, engine and platform. Hash is SHA-256 of sorted, full-precision JSON. Seed and tick explicitly determine infection draw. No cross-platform floating point bit-identity claim.

Presentation consumes protocol v1. Later modules attach through presentation registration hooks rather than owning chemistry or garage scripts. Save payloads contain the entire state, including hop charges and seed. HardwareFrame reserves an interlock contract only; no devices are driven.

## Control/time boundary added during multiplayer integration

`apply_command(state, command)` returns the same result envelope as `advance` but
does not integrate heat, conversion, fermentation or elapsed time. It validates
and applies settings, hop charges and stage transitions, increments input `seq`,
and can immediately emit packaging/hazard interlocks. Both local BrewSession and
the multiplayer authority use it for controls. `advance` remains the sole time
integrator and retains its combined-command compatibility interface for existing
fixtures. Input frequency therefore cannot accelerate a batch.

The multiplayer authority narrows the generic protocol's setters to player
controls: measured `temp_c` is not a remotely editable control. Persistent
equipment faults are enforced before accepting settings. At 10 server ticks per
second, each tick advances brewing by 60 simulated seconds. The competitive
clock stops at 900 seconds, while any already-active fire/claims window finishes
its full 45 seconds with brewing/combat stopped and every bay disarmed.

Garage setting widgets preserve unsent arrow/value edits and typed drafts across
state refreshes. Set commits a draft explicitly; snapshots do not replace it.
See [multiplayer controls and approximations](gameplay.md).

## Visible approximations and fixture provenance

This is a game model, not laboratory-grade brewing advice. Constants are directly visible in `src/chemistry/brewing_simulation.gd`. Water pH is a linear calcium/magnesium/bicarbonate heuristic, without malt buffering titration. Ion balance reports the tracked equivalent charge imbalance, not electroneutrality (sodium and other ions are omitted). Gaussian alpha/beta curves, 80% potential extract, exponential conversion and first-order yeast activity are tunable approximations. Energy is capped at 3 kW / (litres * 4.186 kJ/kg/K); evaporation uses 2257 kJ/kg latent heat with no ambient loss. At boiling, this model assigns burner energy to evaporation rather than further sensible heating.

Tinseth source: https://www.realbeer.com/hops/research.html (Glenn Tinseth, utilization formula). U = 1.65 * 0.000125^(SG-1) * (1-exp(-0.04*minutes))/4.15. The test fixture U(1.050,60)=0.230664077 and 30g at 5% AA in 20 L gives 17.2998058 IBU. Vigor is a game multiplier [0,1]; hop oils decay with 1800 s time constant. Reference chart: https://www.brewersfriend.com/force-carbonation-chart/ . Pressure is an empirical F/volume polynomial, inverted by bisection for regulator mode. Priming uses 4 g/L per added CO2 volume plus 0.85 residual volumes, with instantaneous conditioning in the slice. Safety thresholds are game rules (3.5 volumes/60 psi), never bottle ratings. Yeast ale/lager attenuation and flocculation are fictional generic presets. Fermentation takes at least 48 simulated hours; cooling exposure uses cumulative hazard and a single seeded infection draw. Infection organisms are represented by one flag, not individual cultures. Scorch/DMS/phenolic, ester/fusel and cleanup values are normalized [0,1] abstractions. No physical fire, robotics, ray tracing or multiplayer in milestone 1.

Fixtures are formula-derived, not measured brewing data. Reproduce with ordinary double-precision exp/pow and the equation above; temperature fixtures use C=(F-32)/1.8 and seconds=minutes*60. Tests pin numeric tolerance, monotonicity, input/mass/energy limits and replay invariants. Integration review added a sensible-plus-latent heat regression: boil warmup consumes the shared 3 kW budget before evaporation can use the remainder at 100 C.

## Execution ledger

- MAB-1: committed ca6fa5e; red tests observed, chemistry 42 and contracts 24 checks passed. Pressure safety was corrected to apply to sealed packages only.
- MAB-2: committed e26b601; presentation 22 checks passed and static editor scan passed. JSON parsing turns integer counters into floats; restoring declared integer fields preserves hash continuation.
- MAB-3 integration: new-batch seed/id regression observed failing then passing; sensible-plus-latent energy regression observed failing then passing. Social UI integration verifies module registration, severe-flaw panel opening, 16-row bound and paging replacement. Desktop app access was rejected by computer use; user approval requested. Do not claim a desktop smoke demonstration without observing it.
- Ruling: execute supplied design/tasks directly and inline as explicitly requested. No design approval loop, subagents, PR, merge or push. Self-review replaces an independent agent review because the user requested one agent do the work itself.
