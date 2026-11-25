# Beer optics and garage effects

`src/visuals/beer_optics.gd` maps read-only snapshots to bounded rendering inputs.
The garage's sample glass responds to estimated color, flocculation/haze, CO2,
temperature and hop bitterness. **Inspect beer & effects** moves the camera to
the sample; station controls return to their usual views. The fire renderer
observes authoritative incidents and never starts or changes an incident.

These are prototype approximations:

- SRM 2–50 uses three exponential RGB absorption bands and an angle-dependent
  path-length estimate. Transparency and empirical scattering approximate
  transmission; there is no spectral integration, caustic solver or ray tracing.
- Protocol v1 has no malt color or protein measurement. In gameplay, grain
  loading estimates base color/protein; astringency from overheated mash darkens
  the sample. Flocculation estimates clarity. Labels explicitly say **estimate**.
- Foam thickness combines bounded protein, IBU and carbonation factors.
  Nucleation uses at most32 rising mesh instances per glass, not fluid bubbles.
- Thermal activity drives analytical camera-facing steam layers. Up to24 mesh
  droplets represent condensate on an implied cooler pane behind the vessel;
  this is an artistic proxy, not a humidity/dew-point calculation.
- Fire/smoke uses layered moving opacity and bounded lighting, driven by the
  abstract game heat/smoke fields. It is not a physical combustion model.
  Multiplayer effects end with the authoritative staging window. A local generic
  fire event remains visibly latched until a new batch, matching its safe-state latch.
- All meshes, shaders and effects are original procedural assets. No external
  textures, models or particle sheets are required.

The default Compatibility renderer retains glass, foam, nucleation, steam,
condensate and flame. It does not enable reflection probes or volumetric fog.
Forward+/Mobile enable one bounded reflection probe for raster reflections.
The reference fixture requests Compatibility and Forward+ separately and rejects
an unavailable tier before saving media. It does
not imply equivalent hardware support or performance on every machine.

These choices follow the official [spatial shader transparency limitations](https://docs.godotengine.org/en/4.4/tutorials/shaders/shader_reference/spatial_shader.html)
and [ReflectionProbe renderer support](https://docs.godotengine.org/en/4.4/classes/class_reflectionprobe.html).
Transparent layers can exhibit sorting artifacts. Mesh particles and analytic
vapor provide a lower-feature fallback without compute particles or screen-texture
dependencies. The pure mapper rejects nonfinite values and clamps every scalar.

`tests/render/visual_comparison.gd` uses the same camera, lighting and geometry
for explicit SRM2/10/20/45, clear/hazy, retained/absent foam, cold/hot and
inactive/fire conditions. Hosted artifacts preserve inputs, effective parameters,
engine/driver/adapter, source/run, unchanged PNGs and SHA256 hashes. A120-frame
interval sample reports measured FPS and p50/p95 intervals for that scene; these
are software-runner observations, not GPU-only timings or a gaming-PC benchmark.
Evidence will be linked here after the images have been inspected.
