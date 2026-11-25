# MAB-14 desktop proof collection

Status: **awaiting owner-enabled Godot computer-use access or an owner recording**. This directory currently contains tool-availability evidence and a collection checklist, not a completed desktop demonstration.

Prepared on james's Windows PC, 2026-11-24 (America/Chicago), for branch `beluga/mab-1-playable-brewing-vertical`, reviewed product commit `4acdd863ff687016052f1ebb2ecfe7df510f16cb`. Documentation commits made for collection do not change that product revision. Identify the exact revision again when recording.

## Access and attribution

The earlier Computer Use attempt was rejected: `Computer Use was not approved to use 1-stable_mono_win64`. Owner-enabled access through the supported permission flow is required before agent desktop observation or automation. Do not use FFmpeg capture, alternate automation, engine-injected controls, or another helper to bypass that denial.

Alternatively, the owner may record the following walkthrough and provide its local path for inspection. Identify the operator as james, the machine, recording date/time, branch and commit, and the launch command. Keep the game window readable and exclude unrelated personal windows. The agent must inspect supplied media before marking any acceptance criterion met. A recording plan or owner statement alone is not proof.

## Launch

From the worktree root in PowerShell:

```powershell
& 'C:/Program Files/Godot/Godot_v4.4.1-stable_mono_win64_console.exe' --path .
```

## Ordered capture checklist

Use continuous video or ordered screenshots with annotations describing the action and visible result. For movement/look, video is preferable; a before/after screenshot pair must make the camera change clear.

1. **Identity and launch:** show or record machine/date, branch/commit and command. Capture the initial garage with geometry, station signs and readable metrics. Show initial stage-readiness guidance/disabled Next control.
2. **Controls:** hold right mouse and use W/A/S/D; show position changes. Hold right mouse and move the mouse to demonstrate look. Release it to use the desk. Visit a numbered station; use E nearby and show readiness feedback. Show Resume/Pause or a speed selection and the resulting time change; pause again.
3. **Mash:** use the default 20 L / 5 kg / 66.7 C recipe. Click +1 hour. Capture elapsed time, conversion, pH, ions and enabled Next.
4. **Save/reload:** save mid-batch and capture the success notice and metrics. Change target temperature with Set, then Load. Capture the restored stage, target, temperature, tick/time, gravity and other metrics. The before-save and after-load values must match visibly.
5. **Boil:** Next, add 30 g hops at 5% AA, +1 hour. Capture temperature, gravity, IBU and stage readiness; Next.
6. **Cooling:** flow 1, +1 hour. Capture cooled temperature <=25 C and infection risk; Next.
7. **Fermentation:** +4 hours twelve times, or use the displayed speed controls until at least 48 hours and 95% yeast progress. Capture temperature, fermentation/flocculation, gravity and readiness; Next.
8. **Packaging/judging:** default 120 g priming, Package & judge. Capture carbonation, five category scores, total score and cause-based feedback. Close/open the tasting panel to verify navigation.
9. **Deliberately flawed batch:** start New batch and record its new seed/id. Suggested stress recipe: hot mash at 90 C for an hour, then return to 66.7 C until mash readiness; boil and cool normally; ferment warm at 35 C until ready; use excessive priming (500 g) before packaging. This is a proposed test procedure, not an observed result. Verify the actual resulting score/trigger; if it does not trigger, document that result instead of claiming a feed demonstration.
10. **Fictional feed:** capture the triggering score/flaws, simulated labels, readable posts and page 1. Navigate to page 2, then page 32. Capture replacement of the displayed page rather than a growing list, scroll the last page, and record responsiveness. Confirm no outbound-dispatch action is used. Visual evidence cannot by itself prove absence of network activity; retain the existing code/test evidence separately.

## Artifact index to complete after inspection

No desktop media has been collected or inspected for MAB-14 yet. Once available, add each file, capture time or video timestamp, operator/source, observed actions and limitations here. Hash original media with SHA-256 and retain it unchanged; annotations should reference it rather than replace it. Attach the inspected artifacts to MAB-14 and milestone MAB-10 for independent recheck. Do not mark the milestone passed yourself.

## Tools verified during MAB-14

- [Godot version](godot-version.txt): `4.4.1.stable.mono.official.49a5bc7b6` at the launch path above.
- [FFmpeg version](ffmpeg-version.txt): `8.1.1-essentials_build-www.gyan.dev` at `C:/ffmpeg/bin/ffmpeg.exe`.
- [Current FFmpeg PATH lookup](ffmpeg-path.txt): resolves to that executable. The older absent-from-PATH result is historical, not a current absence claim.
- [Python version](python-version.txt): 3.11.9 at `C:/Users/james/AppData/Local/Programs/Python/Python311/python.exe`.
- Prior renderer startup evidence: OpenGL 3.3.0 NVIDIA 621.14, compatibility renderer, RTX 3080 Ti. This is historical engine output, not a new desktop observation. Capture current startup output when authorized observation occurs.
- No Mac app or npm e2e exists for this project. Neither is a desktop-proof prerequisite.
- Existing 663-check headless and static evidence is preserved. No suite was rerun for this collection task.
