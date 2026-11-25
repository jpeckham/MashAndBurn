# Rendered multiplayer evidence

Operator: Codex. Machine: disposable GitHub-hosted Ubuntu/Xvfb/Mesa, Godot 4.4.1
Compatibility, two real processes, 1366×740 each at a30 FPS cap. Manifests record
renderer, source, clocks, inputs and batch hashes. Images are unchanged; each
role's `SHA256SUMS.txt` verifies the PNGs. No private credentials are present.

| Evidence | Exact source | Hosted run | Result |
| --- | --- | --- | --- |
| `full-host/`, `full-guest/` | `8962ed57b9a7e457061725a3e57e72e7b58022b5` | [45681440614](https://github.com/jpeckham/MashAndBurn/actions/runs/45681440614) | Host107checks/10frames; guest 261checks/17frames; no failures |
| `fixed-host/`, `fixed-guest/` | `600ab2a19c3b2ebe7c267463dcee9188ff2b83ed` | [45686613031](https://github.com/jpeckham/MashAndBurn/actions/runs/45686613031) | Host 49checks/2frames; guest 73checks/7frames; no failures |

The full session uses actual lobby/recipe/package controls and production10 Hz,
600× brewing, then actual wand/fire controls, WASD/E receipt/evidence/trunk
staging, escape, complete45-second claim windows, final tasting and guest feed
pages1,2,32. Host score84.5; guest40.5; guest claim 1500/capital 2500. Both leave
and restore their exact local batch. Only after recipes and claim windows does
the host fixture advance4923→9000; this is not a15-minute wall-clock recording.

All27full-session PNGs were inspected and hashes verified: root reviewed the
host and an independent reviewer the guest. The older full-session images
revealed oversized nearby3Dprop labels and unclear escape/awaiting-result text;
subsequent fixes have regression tests and the nine inspected short-run images.
The short run proves fire interaction/UI changes; it does not repeat brewing
or final tasting. The old host `wand-floor` framing is not clear visual proof
of the floor patch; runtime assertions verify its creation/lifecycle.

Apparent missing glyphs were rechecked on2026-11-25. Raw PNG pixel masks for
equipment/escape/claim text are identical, and disputed host temperature digits
are present. The prior glyph-dropout report was a viewing/presentation artifact,
not a demonstrated product defect. Its precise presentation cause is unknown.

The final release gate reruns the full rendered pair with two actual loopback
mock companions; its `rendered-bridge-proof.json` records arming, telemetry rate
and safe outputs from the same session. These earlier folders predate that gate.

## Same-session mock companion fire smoke

Source `11d249a878ef004f27ba08c496f2b2effba37e92`,
[run 45701992650](https://github.com/jpeckham/MashAndBurn/actions/runs/45701992650):
`integrated-smoke-host/` (58 checks/3 frames), `integrated-smoke-guest/`
(76 checks/7 frames), zero failures. Root inspected/hash-verified all three host
images and an independent reviewer all seven guest images. The new host camera
clearly shows the cyan wand floor patch and a separate active flame overview.
Staging/escape/claim text remains readable and props no longer cover the HUD.

`integrated-smoke-bridge.json` records two actual daemon endpoints, independent
operator arming, active mock outputs, and first faults at actual fire tick127.
The guest first reports explicit staging/fire; the host first reports the shared
hazard latch and later its own spread fire. Initial rates were9.82/8.68Hz;
939/592 telemetry frames, no schema errors and zero unsafe frames after cutoff.
Operator credentials were absent from both games. No physical operation or
external notification service was involved. This smoke does not prove recipes
or the final round clock; the full combined session remains a separate gate.
