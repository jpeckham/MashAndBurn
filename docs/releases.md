# Windows installer delivery

The [build workflow](../.github/workflows/build.yml) calls the reusable Godot MSI
workflow in `jpeckham/.github` at a pinned commit. Source for the shared tooling is
in the adjacent `../.github` checkout on `codex/godot-msi-releases`.

Development branch and pull-request builds validate the project and produce
Windows x64 MSI workflow artifacts. The package embeds the Godot export and
adds a Start menu shortcut. It installs for all users with administrator rights.
The stable upgrade code identifies this game across versions. User saves live
in Godot's app-data folder and are not installed or removed with the game.

When product verification is complete, a tag matching `vMAJOR.MINOR.PATCH`
triggers the same checks before a GitHub Release is created with the MSI,
`SHA256SUMS.txt` and `PAYLOAD-SHA256SUMS.txt`. No release is created on a failed build. No final release tag
has been created during recovery. Current MSI packages are unsigned.

All engine, exported-game and installer checks run on disposable GitHub-hosted
Windows runners. Nothing in the release workflow asks James to launch the game
on his PC. A headless startup check does not establish visual usability or
complete the outstanding visible playthrough criteria.

Hosted source `00203a8` passed [run45672343099](https://github.com/jpeckham/MashAndBurn/actions/runs/45672343099):
869 checks, exported startup, clean install/hash/uninstall, and a real 0.0.0
fixture major upgrade, obsolete-file removal, downgrade rejection and clean
uninstall. The shared library now also bundles matching Godot engine/dependency
notices and project notices; see [distribution inventory](licenses.md).
Interrupted-install rollback and code signing are not covered by these checks.

For another project, use the shared repo's README example with its own executable,
export preset, test script, product name and unique stable upgrade GUID. Pin the
workflow reference and `library_ref` to the same verified shared-library commit.
