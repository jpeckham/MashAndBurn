# Hosted baseline and MSI evidence

Run: https://github.com/jpeckham/MashAndBurn/actions/runs/45655665366

Source commit: `92ffcdbe89acd5aa697fb4646f4c8cdde91b978e`.
Shared workflow/scripts: `jpeckham/.github@84765dd4877453dc01be8dcb33c8dc89f68b3e9d`.
Platform: GitHub-hosted `windows-2022`, standard Godot `4.4.1.stable.official.49a5bc7b6`, WiX `4.0.6`.
Operator: GitHub Actions automation, 2026-11-25 UTC. No game, Godot or MSI ran on James's PC.

The run's completed status and conclusion were inspected via GitHub API/CLI.
The actual run log reports `RESULT: 663 checks, 0 failures` at 16:37:12 UTC
and `MSI payload hashes and uninstall verified.` at 16:38:53 UTC.
Import, tests, export and ten-frame headless startup of the exported game all
passed with no detected engine errors. MSI installation and removal returned
successful Windows Installer exit codes; installed files matched export hashes.

Retained artifacts:

- `godot-validation-logs`, artifact ID `15043131218`, 21,077 bytes.
- `mash-and-burn-windows-msi`, artifact ID `15042641554`, 27,318,042 bytes;
  contains the development MSI and its SHA256 checksum file.

The release job correctly skipped because the source was a branch, not a
version tag. No GitHub Release or final shipping claim follows from this run.
This evidence does not establish visual usability, multiplayer, advanced
rendering, hardware operation, MSI upgrades/downgrades or code signing. Those
remain explicit work items in the continuation record.
