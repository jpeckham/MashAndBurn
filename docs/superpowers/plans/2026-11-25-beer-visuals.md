# Beer and garage effects implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete the inherited MAB-6/MAB-12 rendering criteria with chemistry-driven beer and bounded garage effects.

**Architecture:** A pure optics mapper converts explicit SRM/haze/protein/IBU/CO2/temperature inputs into finite rendering parameters. An original procedural beer display and reusable thermal effect consume those parameters without changing chemistry. A garage module observes snapshots; a separate fixed-camera comparison scene supplies labeled reference samples and records the actual renderer and timings.

**Tech stack:** Godot 4.4.1 GDScript, spatial shaders, procedural meshes, hosted X11/Mesa.

**Spec:** `docs/handoff/inherited-tasks.json`, MAB-6 and MAB-12; approved Godot prototype scope in `docs/handoff/inherited-plan.json`.

## Global constraints

- No Godot, editor, game, installers or game tests on the owner's PC; all execution uses disposable GitHub-hosted runners.
- Original procedural assets; no external textures or copyrighted art.
- Read-only BatchState/HazardEvent consumption. Approximate RGB absorption, haze and foam are explicitly documented; no full spectral ray tracing or PS5 parity claim.
- Compatibility fallback uses bounded mesh particles and analytic lighting. Reflection probes are enabled only for Forward+/Mobile; no unsupported volumetric or screen-space effects on Compatibility.

## Review focus

- Nonfinite or absent chemistry values produce finite bounded parameters.
- Renderer fallback leaves visible beer, bubbles, steam and fire rather than silently omitting them.
- Scene lifetime and snapshot changes do not accumulate particles or lights.
- Mock reference samples cannot mutate a live batch or trigger gameplay hazards.
- Clear/hazy and foam/thermal comparisons use identical cameras, lighting and sample geometry.

## Tasks

### 1. Optics and effects mapping

- [x] Add `tests/visuals/test_visuals.gd` to `tests/run_all.gd`; prove missing mapper fails on a hosted run.
- [x] Implement `src/visuals/beer_optics.gd`: SRM 2–50, RGB exponential absorption, haze, foam retention from protein/IBU, CO2 bubble density, temperature steam, renderer capabilities. Reject nonfinite inputs to safe defaults.
- [x] Cover bounds, monotonic darkening, finite color/parameters, foam/CO2/thermal relationships, fallback and read-only BatchState derivation. Grain loading/scorch/flocculation estimates are labeled estimates because v1 has no malt color/protein measurement.
- [x] Run focused/combined hosted suites and commit.

### 2. Rendered displays and garage integration

- [ ] Implement `src/visuals/beer_display.gd`, `beer.gdshader`, `thermal_effect.gd`, `vapor.gdshader`; bounded original meshes, animated nucleation, foam, steam, condensation and fire/smoke.
- [ ] Register `visuals_module.gd` through the existing module extension point. Observe local or network chemistry and fire without authorizing any gameplay/physical operation. Reuse nodes and free with the garage.
- [ ] Add scene integration assertions for mesh counts, parameter propagation, fallback and cleanup.

### 3. Hosted visual evidence

- [ ] Add `tests/render/visual_comparison.gd` with fixed-camera SRM 2,10,20,45 samples, clear/hazy, weak/retained foam, cold/hot, inactive/fire comparisons. Record toolchain, adapter, renderer, frames, actual frame-time sample and source.
- [ ] Extend hosted render workflow, reject shader/runtime errors, hash and preserve unchanged frames/logs.
- [ ] Inspect every comparison image, fix concrete defects, document approximations and measured limits in `docs/visuals.md` and the evidence index.
- [ ] Independent code/artifact review and fresh integrated validation before accepting this milestone.

## Execution ledger

- Mapper red: Windows run45672602548, source386c989,870 checks/one expected missing-mapper failure. Green: source7d54329, run45673275688,922 checks, full MSI pipeline.
- Display red: Linux run45674575997, sourceb618c26,923 checks/one expected missing-display failure. Green: sourcebbe98c7, run45675152153,928 checks plus the single-player GUI walkthrough. This predates garage registration and reference comparisons.
- Upgrade and notices are independently proven: source0100534, Windows run45673590122,922 checks, exact installed hashes, install/major upgrade/obsolete removal/downgrade/uninstall; matching Godot and project notices bundled. Shared library4cb6cb2. Review found inventory generation before smoke could become stale for generic callers; moved it immediately before packaging.
- Ruling: use mesh instances and analytic vapor layers in both tiers; enable reflection probes only where supported. This makes the default fallback visible and bounded. It deliberately does not attempt a fluid solver or unsupported hardware ray tracing.
- Current comparison run45675632245 uses sourcef4540e6. Await actual outcome and inspect unchanged frames before acceptance.
