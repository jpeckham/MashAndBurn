# Hosted gameplay, ENet and installer validation

Run: https://github.com/jpeckham/MashAndBurn/actions/runs/45662199180

Source: `8644e6a7f9dd47487c6b517875808ecd87edb859`.
Shared workflow/scripts: `jpeckham/.github@84765dd4877453dc01be8dcb33c8dc89f68b3e9d`.
Platform: disposable GitHub-hosted `windows-2022`, standard Godot 4.4.1,
WiX 4.0.6. Operator: GitHub Actions automation, 2026-11-25 UTC.
Nothing executed on James's PC except source/metadata/git/CLI work.

The completed successful run and actual log were inspected. At 17:13:21 UTC:

```text
ENET_SMOKE clients=2 elapsed=900.0 results=2 server_tick=9000
ENET_SMOKE clients=8 elapsed=900.0 results=8 server_tick=9000
RESULT: 833 checks, 0 failures
```

The actual ENet fixture uses separate SceneMultiplayer roots and real loopback
peers, including a dedicated host, two/eight participants, refused overflow,
ready/start, own-batch setting, refused money injection, disconnect, private-token
reconnect, state/ordering preservation, server loss and synchronized results.
It fast-forwards 9,000 server ticks inside test code; it does not wait fifteen
wall-clock minutes or expose clock control to a client. These clients finish a
round with incomplete batches; this is not proof of a complete brewing playthrough.

Domain checks additionally cover all five arsenal categories, projectile impacts,
range/cooldowns, all three sabotages, malformed/stale/replayed/forged commands,
snapshot isolation/credential exclusion, fire's disarm ordering, 45-second
boundaries, late-fire settlement, escape/smoke, bankruptcy and exactly-once payouts.
Review regressions prove that command frequency cannot accelerate chemistry,
measured temperature cannot be remotely set, equipment faults cannot be bypassed,
and unsent arrow/value and typed-text edits survive repeated GUI refreshes.
The earlier chemistry, contract, local save/load and fictional-feed cases still pass.

Import, Windows x64 export and a ten-frame headless exported-game startup also
passed. At 17:14:07 UTC the log reports:

```text
MSI payload hashes and uninstall verified.
```

Retained artifacts:

- `godot-validation-logs`, ID `15045023083`, 21,343 bytes.
- `mash-and-burn-windows-msi`, ID `15044579850`, 27,354,664 bytes.

No final Release was published: the tag-only release job skipped as intended.
This does not prove visible UI layout, normal/flawed full batches in the GUI,
two visible clients, spatial staging props, advanced renderer fidelity/performance,
companion safety/transport integration, physical actuation, or MSI upgrades.
Those remain incomplete gates in `docs/AI-GOAL-PROGRESS.md`.
