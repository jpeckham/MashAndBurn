# Milestone 1 design and execution

The supplied plan is executed inline, one commit per MAB task. Godot 4 GDScript avoids a .NET build dependency; a SceneTree harness needs no addons. The alternative of a C# chemistry library adds tooling with no benefit for this slice. The existing PRD is unchanged.

- MAB-1: write failing replay/formula tests, implement protocol validation and pure `advance(state, command, dt_seconds)`, run chemistry/contracts independently.
- MAB-2: write routing/save tests, build original primitive 3D garage and onscreen controls, verify parsing and focused presentation tests.
- MAB-3: write boundary/deduplication/seed tests, implement judging and lazy local feed, run focused social tests and one whole milestone suite; demonstrate desktop batch.

Review focus: malformed saves, numeric nonfinite input, wrong tick/sequence, stage readiness, rendering bound. These have dedicated tests in their owning task.

## Determinism and boundaries

Simulation owns no nodes, clock, files, globals, network or hardware. Calls deep-copy state and return `{ok,state,events,error}`. Fixed 60 s ticks are used by the presentation; arbitrary finite dt in (0,60] is accepted but replay requires identical dt/command sequence, engine and platform. Hash is SHA-256 of sorted, full-precision JSON. Seed and tick explicitly determine infection draw. No cross-platform floating point bit-identity claim.

Presentation consumes protocol v1. Later modules attach through presentation registration hooks rather than owning chemistry or garage scripts. Save payloads contain the entire state, including hop charges and seed. HardwareFrame reserves an interlock contract only; no devices are driven.

## Visible approximations and fixture provenance

This is a game model, not laboratory-grade brewing advice. Constants are directly visible in `src/chemistry/brewing_simulation.gd`. Water pH is a linear calcium/magnesium/bicarbonate heuristic, without malt buffering titration. Ion balance reports the tracked equivalent charge imbalance, not electroneutrality (sodium and other ions are omitted). Gaussian alpha/beta curves, 80% potential extract, exponential conversion and first-order yeast activity are tunable approximations. Energy is capped at 3 kW / (litres * 4.186 kJ/kg/K); evaporation uses 2257 kJ/kg latent heat with no ambient loss. At boiling, this model assigns burner energy to evaporation rather than further sensible heating.

Tinseth source: https://www.realbeer.com/hops/research.html (Glenn Tinseth, utilization formula). U = 1.65 * 0.000125^(SG-1) * (1-exp(-0.04*minutes))/4.15. The test fixture U(1.050,60)=0.230664077 and 30g at 5% AA in 20 L gives 17.2998058 IBU. Vigor is a game multiplier [0,1]; hop oils decay with 1800 s time constant. Reference chart: https://www.brewersfriend.com/force-carbonation-chart/ . Pressure is an empirical F/volume polynomial, inverted by bisection for regulator mode. Priming uses 4 g/L per added CO2 volume plus 0.85 residual volumes, with instantaneous conditioning in the slice. Safety thresholds are game rules (3.5 volumes/60 psi), never bottle ratings. Yeast ale/lager attenuation and flocculation are fictional generic presets. Fermentation takes at least 48 simulated hours; cooling exposure uses cumulative hazard and a single seeded infection draw. Infection organisms are represented by one flag, not individual cultures. Scorch/DMS/phenolic, ester/fusel and cleanup values are normalized [0,1] abstractions. No physical fire, robotics, ray tracing or multiplayer in milestone 1.

Fixtures are formula-derived, not measured brewing data. Reproduce with ordinary double-precision exp/pow and the equation above; temperature fixtures use C=(F-32)/1.8 and seconds=minutes*60. Tests pin numeric tolerance, monotonicity, input/mass/energy limits and replay invariants.
