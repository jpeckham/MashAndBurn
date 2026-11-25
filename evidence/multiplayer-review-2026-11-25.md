# Independent multiplayer code review and fixes

Read-only reviewer: `review_multiplayer`, requested through the Superpowers
requesting-code-review skill. Range: `46556c1..02ae932`. No tests or apps ran on
James's PC; the reviewer inspected code only and did not edit the checkout.

Original verdict: not ready to merge. No Critical findings; four Important findings:

1. Accepted brew commands called `advance(...,60)`, adding time outside server ticks.
2. Generic `temp_c` setters let clients bypass thermal simulation.
3. Sabotage constraints were restored after an input had already integrated a forbidden setting.
4. Frequent snapshots overwrote pending SpinBox edits before Set.

All four were verified against actual source. Hosted run
[45660948879](https://github.com/jpeckham/MashAndBurn/actions/runs/45660948879)
then reported nine corresponding failed regression checks, 831 total. The same
run exercised the earlier model, fire and ENet tests without new failures.

Fix `37e8631` separates `apply_command` from time integration, narrows multiplayer
setters, rejects persistent equipment overrides and preserves pending widget edits.
Run `45661584258` reduced failures to one: Set could undo an arrow/value edit by
reapplying stale SpinBox text. Fix `8644e6a` distinguishes typed drafts from
already-committed Range values and adds explicit typed-text coverage. Fresh final
[hosted verification](multiplayer-hosted-2026-11-25.md) passed 833 checks and the
export/installer pipeline. This resolves the four code findings through reproduced
regressions and verified fixes; it does not claim an independent second review or
acceptance of missing visible evidence.

Reviewer declined to judge rendered usability, exported startup, companion
consumption and visible two-client acceptance because read-only source review
cannot establish them. Those remain explicit evidence gates. Advanced rendering
and companion implementation are still separate product milestones.
