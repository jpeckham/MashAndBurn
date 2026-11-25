# Hosted beer and thermal comparisons

[Successful run45676372839](https://github.com/jpeckham/MashAndBurn/actions/runs/45676372839)
uses source `7afa72b5a8cd8ea56bd2dce91181c7ab529de3d7`, official Godot4.4.1,
Ubuntu24.04 X11/Xvfb and Mesa llvmpipe CPU rendering. No game, engine, installer
or desktop automation ran on the owner's PC.

The ten unchanged PNGs, per-tier manifests, hashes and renamed raw render logs
are preserved here. Root inspected all five Compatibility frames and verified
their hashes. Independent review inspected all five Forward+ frames and verified
their hashes. Root also inspected the Forward+ SRM frame. Both renderers were
actually used: OpenGL Compatibility and Vulkan Forward+, with no fallback.

| Reference | Compatibility | Forward+ |
| --- | --- | --- |
| SRM2/10/20/45 | [Frame](gl_compatibility/01-srm-2-10-20-45.png) | [Frame](forward_plus/01-srm-2-10-20-45.png) |
| Clear/hazy | [Frame](gl_compatibility/02-haze-scattering.png) | [Frame](forward_plus/02-haze-scattering.png) |
| Foam/nucleation | [Frame](gl_compatibility/03-foam-nucleation.png) | [Frame](forward_plus/03-foam-nucleation.png) |
| Cold/hot/condensate | [Frame](gl_compatibility/04-steam-condensation.png) | [Frame](forward_plus/04-steam-condensation.png) |
| Fire/smoke | [Frame](gl_compatibility/05-fire-smoke.png) | [Frame](forward_plus/05-fire-smoke.png) |

Visible observations: increasing SRM darkens the samples; haze obscures the
striped background; the flat samples lack heads/bubbles while the protein/IBU/CO2
sample has a thicker head and more nucleation. Hot samples have vapor and
droplets against a visible cooler pane. Incident samples add flame, smoke and
lighting; Forward+ adds visible raster floor reflections. Headings, sample labels
and provenance footers fit. No Important artifact blocker was found.

| Actual comparison scene | FPS | Median interval | p95 interval | Draw calls |
| --- | ---: | ---: | ---: | ---: |
| Compatibility / OpenGL3 |24.74 |40.689ms |42.309ms |54 |
| Forward+ / Vulkan |11.61 |86.722ms |89.436ms |57 |

These are120-frame interval samples of the **four-sample fire comparison scene**,
not an integrated eight-player garage or a gaming-PC/GPU benchmark. This CPU
runner does not establish console performance or hardware ray tracing.

Limits: empirical RGB absorption/transparency, artistic haze, mesh foam/bubbles,
static droplet proxy and analytical vapor layers. Hues, especially Forward+'s
desaturated pink/mauve samples, are not validated SRM colorimetry. The frames
prove visible parameter differentiation, not calibrated optics or physical fluid
realism. See [model and renderer limits](../../../docs/visuals.md).

An earlier run failed because Forward+ lacked a Vulkan surface extension and
fell back to OpenGL. The runner now installs/selects Mesa's software Vulkan ICD,
and the fixture refuses a requested/actual renderer mismatch before saving media.
Initial images also drove fixes for overlapping labels, dark-beer contrast,
steam contrast and the missing visible condensate pane.
