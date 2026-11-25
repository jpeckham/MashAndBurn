# Prototype traceability

This is the inherited Godot PC prototype route, with the approved fictional
feed/private opt-in notification and mock hardware scope. The original
[PRD](prompts/mash_burn_prd.md) and [historical tasks](handoff/inherited-tasks.json)
remain unchanged. This report records the implemented prototype boundaries.

| Requirement | Implementation and verification |
| --- | --- |
| MAB-1: chemistry/contracts | Seeded fixed-tick mash, ions/pH, Tinseth bitterness, cooling/infection, fermentation, carbonation/hazards and bounded v1 schemas; formula fixtures/deterministic hashes in combined suite |
| MAB-2,14–16: garage/actual observation | WASD/right-mouse/E, station controls, readiness/speeds, exact save/reload; [20 inspected frames/403 GUI assertions](../evidence/desktop/2026-11-25-hosted/README.md) plus authorized native Windows control check |
| MAB-3: tasting/feed | Five categories, causal feedback, score/severe-flaw thresholds,512 fictional personas,16 rows/page; normal/flawed completion and pages1/2/32, bounded replacement |
| MAB-4: multiplayer | Server-owned2–8player lobby/round, command authorization, bounded movement/projectiles, five weapons/three sabotages, reconnect/final judging; actual two-/eight-client ENet and [rendered pair](../evidence/multiplayer/2026-11-25-hosted/README.md) |
| MAB-5: fire/claims | Spatial receipt/evidence/Buick trunk,45-second claims, smoke/escape, evidence/stress inspection,150% payout/penalties and disarm; actual rendered traversal/settlement plus late-fire/replay tests |
| MAB-6: visual chemistry | Artistic SRM2–50 RGB absorption/haze/foam, bounded bubbles/steam/condensate/fire/smoke and supported probes; [ten inspected comparison frames/timings](../evidence/visuals/2026-11-25-hosted/README.md) and finite/fallback tests |
| MAB-7: mock HAL/private alerts | Strict10Hz safety envelope, fault latch, separate operator authority, mock transports, simulated waypoints and opt-in allowlisted alerts;59 pytest cases on Linux/Windows and [actual game/daemon/fake receiver proof](../evidence/companion/2026-11-25-hosted/README.md) |
| MAB-8,13: combined package | Combined suites, eight clients, rendered pair with mock companions, export/MSI lifecycle and licenses/source inventory; final same-session and release gates tracked in [current progress](AI-GOAL-PROGRESS.md) |
| Owner: reusable MSI releases | Pinned Godot/WiX workflow/scripts in adjacent `../.github`; project-specific caller, stable upgrade GUID and tag gates; [delivery](releases.md) |

Brewing is a bounded game approximation. Visuals are artistic RGB effects, not
calibrated spectral optics, ray-traced fluids or a PS5 port. Forward+ sample hues
differ from Compatibility. Software timings apply to the comparison scene.

Tier1 output is mocked; no physical relays, probes or dosing rig were tested.
Tier2 is a bounded simulated Cartesian waypoint cursor, not six-axis joint IK,
collision avoidance, lifting or physical cobot control. Real adapters refuse
arming and the game has no operator authority. Notifications default off and
require independent game/service/destination consent; tests use loopback fakes.

The rendered pair runs real recipes and claim windows before an explicitly
logged host-fixture final clock advance. It is not an uninterrupted15-minute
recording. MSI is unsigned; interrupted-install rollback and physical safety
calibration remain outside demonstrated capabilities.
