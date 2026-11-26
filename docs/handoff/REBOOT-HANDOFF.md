# Reboot handoff — 2026-11-25

Read this before resuming work. The task is **not complete** and no final release
has been published. James is rebooting after reporting whole-PC lockups during
local testing.

## Immediate constraints

- **Do not launch the game, Godot editor, headless tests, installers, GPU probes,
  or desktop automation on James's PC.** Continue execution only on disposable
  GitHub-hosted runners. A reboot does not grant permission to retry locally.
- Local file/git work and reading hosted results remain appropriate. Do not
  change drivers, Windows settings, or unrelated processes as a speculative fix.
- No matching MashAndBurn diagnostic Godot process remained at the scoped check.
  The Node computer-use session was reset. No installer ran locally.
- Whole-PC instability is unresolved. Do not call this build stable or publish
  a stable release until it is understood. Hosted success does not prove this
  machine is stable. No final version tag has been created.
- An unanswered diagnostic question asked whether a restart was required,
  whether the desktop merely became slow, or whether only the game froze.
  James now says he needs to reboot; do not assume the precise failure mode.

## Goal and repositories

Finish the inherited Godot PC prototype after removing this project's Beluga
activity, then deliver GitHub Releases with MSI installers and companion source.
Reusable Godot release tooling belongs in adjacent `../.github` for other games.

- Game: `C:/Users/james/source/repos/MashAndBurn`, remote
  `jpeckham/MashAndBurn`, branch `codex/continue-mash-and-burn`.
- Last committed game HEAD before this handoff:
  `c82086df2ce01103ae3766aaa7800ea9d0499f9a`.
- Shared library: `C:/Users/james/source/repos/.github`, remote
  `jpeckham/.github`, branch `codex/godot-msi-releases`, HEAD
  `1d42dcf38f6b675d824a259125bad546df5bbaeb`.
- Both references in the game's build caller pin that shared-library commit.
- Game repository's GitHub default branch currently reports
  `codex/continue-mash-and-burn`; shared repo default is `main`. Local `main`
  exists. No PR was created or merge performed during this continuation.
- Historical scope: `docs/handoff/inherited-plan.json` and
  `inherited-tasks.json`. These are preserved historical records, not current
  permission or active scheduler state. Current ledger is
  `docs/AI-GOAL-PROGRESS.md`; its newest checkpoint supersedes old chronology.

## Beluga recovery — already completed

Recovered four commits through `dc6bd8f`, preserving history. Removed this
project's plan,16 tasks,3 workspace registrations/histories,8 execution records,
overrides/statistics/discovery; excluded root from rediscovery. Other projects
were preserved. Original worktree removed after verification; historical branch
retained. Private backup and verified full Git bundle are outside Beluga at
`C:/Users/james/.codex/handoffs/mash-and-burn-20261125-102647`.

## Verified implementation

- Deterministic brewing/contracts, garage controls, exact save/reload, normal
  and flawed recipes, five-category tasting and bounded fictional feed.
- Authoritative 2–8 player ENet, round clock, weapons/sabotage, bounded movement
  and projectiles, reconnect, spatial receipt/evidence/Buick-trunk staging,
  45-second claims, smoke/escape, seeded inspection and exactly-once payouts.
- Artistic chemistry-driven beer RGB absorption/haze/foam/bubbles, steam,
  condensate, flame/smoke and supported reflection probes. No calibrated optics,
  physical fluid solver, PS5 or ray-tracing parity claim.
- Strict loopback mock companion, 10 Hz telemetry, latched faults, stale/sensor/
  thermal/E-stop/fire/disconnect interlocks, separate operator credentials,
  mock serial/MQTT/WebSocket adapters, bounded simulated waypoint cursor.
  Physical transport stubs cannot arm; no physical robot IK or hardware tested.
- Optional private notifications default off; independent game/service/target
  consent, exact allowlist, bounds, dedupe/rate/retry limits and no redirects.
  Actual integration sends only to a loopback fake receiver.
- Source ZIP packaging includes tracked companion source, generated schema,
  hashes and installed dependency notices/metadata. No interpreter/dependency
  implementation or credentials vendored. Python3.12 dependencies locked.
- Reusable MSI workflow verifies official engine/templates, import/tests/export,
  exported startup, installed payload hashes, major upgrade from0.0.0, obsolete
  file removal, downgrade rejection and uninstall. MSI is unsigned/per-machine
  admin; interrupted-install rollback is not established.

## Evidence and passing runs

- Game suite: **1,022 checks, zero failures**. Latest local authorized run was
  before the new prohibition; do not repeat locally. Multiple hosted Windows
  builds also pass, including `45702719529` for diagnostic source `f8a82ee`.
- Single-player:20 inspected/hash-verified PNGs,403 GUI assertions in
  `evidence/desktop/2026-11-25-hosted/`.
- Full multiplayer: run `45681440614`, source
  `8962ed57b9a7e457061725a3e57e72e7b58022b5`; host107 checks/10 PNGs,
  guest261 checks/17 PNGs, scores84.5/40.5, guest payout1500/capital2500,
  final feed pages1/2/32 and exact local restoration. Preserved under
  `evidence/multiplayer/2026-11-25-hosted/full-{host,guest}/`.
  Recipes and claims ran at production speed; host explicitly advanced the
  remaining final clock4923→9000 afterward. Not a15-minute wall-clock proof.
- Subsequent fixed-UI smoke `45686613031` has9 inspected PNGs in `fixed-*`.
  Close-prop labels and escape/await-result text were corrected.
- Visuals:10 inspected/hash-verified Compatibility/Forward+ comparison PNGs in
  `evidence/visuals/2026-11-25-hosted/`; software comparison-scene timing only.
- Companion: run `45700200483`, source `5d0cbf2`,59 pytest cases on each Linux
  and Windows job, actual Godot→daemon37 frames at10.001967Hz, distinct operator
  arm/E-stop/clear/rearm, actual fire latch/new-batch persistence/disconnect and
  one real game-generated alert to a local fake. Alert grading is a deliberate
  fixture, not brewing evidence. Preserved in `evidence/companion/2026-11-25-hosted/`.
- Packaged companion artifact from that run downloaded and SHA256 verified:
  `.tools/companion-release-45700200483/`;68 ZIP entries,18 source files,
  24 dependency metadata packages. Forbidden path check passes. Notice collector
  previously mistook Python `packaging/licenses` for legal notices; corrected
  to distribution metadata only.
- **Same-session two-visible-client/two-companion fire smoke passes**:
  run `45701992650`, source `11d249a878ef004f27ba08c496f2b2effba37e92`.
  Host58 checks/3 PNGs, guest76 checks/7 PNGs; all inspected/hashes verified.
  Preserved as `integrated-smoke-*` plus `integrated-smoke-bridge.json` under
  multiplayer evidence. Both independently armed and produced mock output;
  first cutoff at actual fire tick127; zero unsafe frames afterward. Guest first
  reports explicit fire/staging; host shared hazard latch, later spread fire.
  Rates9.82/8.68Hz,939/592 frames, no schema errors, no operator secret in games.
  New host framing clearly shows the cyan floor patch and active flame.
  This smoke does not establish full recipes/final clock with companions.

## Important corrections

The apparent missing UI glyphs were **not absent from the raw PNG files**.
Independent raw foreground-pixel masks and direct Godot renders show intact
text; the viewing/presentation path caused the misleading observation. Prior
glyph-dropout finding was retracted. Experimental font isolation was removed
in `e4a09a3`. Do not resume speculative font fixes.

Native testing used existing Godot4.4.1 Mono, Compatibility, NVIDIA RTX3080Ti,
30FPS and actual mash/boil clicks. Capture eventually failed (`FrameArrived`,
then `activate_window` timeout during recovery). A responsive process flag and
the cap did not prove whole-PC stability. Existing System logs had no matching
display/driver/hardware-reset event in the preceding hour; that does not rule
out a stall. No cause or fix is established. Local diagnostics in `.tools/`
are historical artifacts, **not instructions to execute them**.

## Immediate next work — hosted only

1. Inspect failed full combined run
   [45702748129](https://github.com/jpeckham/MashAndBurn/actions/runs/45702748129).
   It was newly confirmed **failure** while preparing this handoff; its actual
   failed logs have **not yet been inspected**. Source `f8a82ee` adds diagnostics
   specifically for the previous failure below. Do not blindly rerun.
2. Earlier full combined run `45702001228` (source `11d249a`) failed after the
   guest's actual Next-stage click activated once, but authoritative batch stayed
   in boil and did not enter cooling within5 seconds. Host reached fermentation.
   Saved partial evidence: `.tools/integrated-full-failed-45702001228/`.
   No root cause or product fix has yet been established.
3. New diagnostic commit `f8a82ee` adds `PAIR_STAGE_FAILURE` details (batch,
   pending/queued/in-flight/reply count/tick), and test-opt-in `PAIR_BREW_SEND`
   / `PAIR_BREW_REPLY` transport logs. Inspect them in the newly failed run.
   Do not call a retry success a fix without explaining the prior failure.
4. Final harness files: `companion/tests/rendered_pair_bridge.py`,
   `tests/render/run_pair.sh`, `multiplayer_proof.gd`, render workflow. Two real
   daemon endpoints wrap the actual two-process GUI fixture. Game opt-in is
   explicit in the fixture, operator secrets stripped from game environment,
   parent uses separate HTTP operator authority after healthy telemetry.
5. Review caught an evidence gap: any earlier hazard could masquerade as fire
   cutoff. Fixed in `11d249a`: actual GUI fire marker/tick, explicit guest fire
   frame, each peer safe during actual fire; short smoke requires initial fault
   within2 ticks of explicit fire and guest first fault staging. Full scenario
   distinguishes earlier packaging-overpressure latch from fire cause.
6. Resolve the full combined-session failure, inspect all new full-session
   frames/hashes/report and preserve final evidence. Do not retry PC execution.
7. Whole-PC lockup is a separate unresolved material issue. Stable release is
   on hold; hosted functional passes alone cannot close that report.

## Release wiring and remaining delivery

`.github/workflows/build.yml` calls companion and full rendered reusable
workflows on numeric version tags, with Windows MSI publication dependent on
their success. Shared library accepts optional `additional_release_artifact`;
tag caller names `mash-and-burn-companion-release`. Intended assets: MSI,
`SHA256SUMS.txt`, `PAYLOAD-SHA256SUMS.txt`, companion ZIP and
`COMPANION-SHA256SUMS.txt`. No final release tag exists. Do not trigger automatic
stable publication while lockups and full combined test failure are unresolved.

`docs/releases.md`, `docs/prototype-traceability.md`, README and progress ledger
describe implementation and limits. Historical plan checklists retain old open
items; appended continuation ledgers/current checkpoint supersede them. Reconcile
final status only after actual acceptance evidence and release asset verification.

Read-only reviewers available in the old session: `/root/review_multiplayer`
and `/root/review_client_integration`; they may not survive reboot/session reset.
Earlier product/library reviews have no outstanding Critical/Important issues.
Client reviewer verified all7 strict-smoke guest frames; root all3 host frames.
The newest full-session failure still requires diagnosis and review.

Do not restart completed Beluga recovery, speculative font work, or unchanged
test suites. Poll existing hosted work and use its actual failure evidence.
