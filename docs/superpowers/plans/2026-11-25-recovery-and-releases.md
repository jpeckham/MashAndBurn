# Recovery and reusable Godot MSI releases

> **For agentic workers:** Use superpowers:executing-plans to implement this plan inline. Preserve the inherited product plan as the full remaining scope.

**Goal:** Recover development from Beluga and provide reusable, remotely verified Windows MSI release infrastructure.

**Architecture:** Preserve existing Godot source/history. A caller in MashAndBurn invokes a reusable workflow in `jpeckham/.github`, pinned to a commit. GitHub-hosted Windows runners install the official checksum-verified engine/templates, run headless checks, export Windows x64, build MSI, and verify installation/removal. Only version tags publish Releases.

**Tech stack:** Godot 4.4.1 standard GDScript build, PowerShell, WiX CLI, GitHub Actions.

**Spec:** `docs/AI-GOAL-PROGRESS.md`, `docs/handoff/inherited-plan.json`, and the owner's MSI requirement.

## Constraints and review focus

No Godot or installer execution on James's PC. No GUI takeover. Pin shared workflow revisions. Release only successful tested artifacts; a workflow artifact is not a final shipped release. Stable per-product upgrade codes; MSI versions must fit Windows Installer limits. Logs must survive failures. Installer must include all exported files and a launch shortcut; remote install/uninstall must preserve user saves.

### Task 1: Recover and detach

- [x] Recover clean source/history to `codex/continue-mash-and-burn`.
- [x] Back up source and metadata outside Beluga; export full scope into `docs/handoff/`.
- [x] Remove project scheduling, workspaces, histories and execution records from Beluga's offline state; verify unrelated records remain.
- [ ] Finish original worktree cleanup after confirming source recovery.

### Task 2: Remote baseline and reusable installer workflow

Files: `../.github/.github/workflows/godot-windows-msi.yml`, `../.github/scripts/godot/`, `.github/workflows/build.yml`, `export_presets.cfg`.

- [ ] Add configurable official Godot engine/template download with SHA512 verification.
- [ ] Add bounded import/test/export steps with retained logs and explicit failure detection.
- [ ] Generate MSI with a stable upgrade code, recursive payload, shortcut and major upgrade policy.
- [ ] On hosted Windows, install silently, verify payload hashes, uninstall, and verify removal. Add explicit exported-game smoke validation there.
- [ ] Add development artifacts and version-tag-only GitHub Releases with checksum assets.
- [ ] Push feature branches, observe remote runs, fix failures, and record actual evidence.
- [ ] Document how another Godot project supplies its preset, tests, product name, executable, upgrade code and version.

### Task 3: Continue product scope

Execute every remaining milestone and criterion in `docs/handoff/inherited-plan.json`; break each subsystem into concrete implementation tasks before editing it. The unverified vertical-slice visual evidence must remain outstanding while independent multiplayer, rendering and companion implementation proceeds. Final release waits for integrated product and installer evidence, not merely a passing build pipeline.
