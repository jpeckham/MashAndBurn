# Multiplayer brewery rounds

Current execution constraint: do not launch Godot or the game on James's PC.
The workflow runs all engine and ENet checks on disposable GitHub-hosted Windows.
The instructions here describe the implemented game controls for a permitted
test machine; they are not a request for a local test.

Open **Lobby / combat / claims** in the garage. One player hosts a UDP port
(27841 by default); other players enter that host's IP and the same port and
join. `127.0.0.1` is for multiple instances on one test machine. This prototype
uses Godot ENet on a trusted local/LAN network, without public matchmaking.
Host and clients use the same build. Each brewer sets their recipe and toggles
ready; the host chooses pale ale, lager or stout and starts after 2–8 players
are ready. A ninth participant receives a full-lobby rejection.

The host owns a fixed 10 Hz match clock and 600x brewing simulation. The match's
competitive clock ends at 15 minutes. Existing Brew Desk settings and station
progression become server intents. Local time skips, new-batch and save/load
cannot replace the authoritative batch. Leave restores the previous local batch.
Incomplete packaging receives a 75% score reduction; incapacitation scores zero.
Final tasting is ranked by score, with player ID breaking exact ties.

Close the panel, hold right mouse and WASD to move. Select a rival in match
controls, approach within range and use a weapon or sabotage. Positions,
cooldowns, damage and target validity are computed by the host. The wand adds
blindness and a movement slow; the ladle and hydrometer are short-range attacks;
kegs and bottles travel as server-integrated gravity projectiles with bounded
radial impacts. These are deliberately simplified game collision shapes.
Chiller sabotage removes active cooling, contamination reaches the chemistry
state, and burner redline can trigger an abstract boil-over fire.

The fictional fire control selects boil-over, cord or grain-dust incident
categories. Fires evolve abstract heat/fuel/smoke fields and can reach adjacent
brewer bays. Disarm is emitted before the fire event and latches immediately.
During the server's 45-second staging window, players may stage three fictional
objects, then reach the green garage exit and select Escape. Smoke can kill
players who stay indoors. The seeded fictional adjuster inspects the staged
record, escape, burn category and valve state. Acceptance awards exactly 150%
of replacement value once; failure applies a penalty and possible bankruptcy.
No client selects the verdict or award. These are fictional rules, not physical
fire behavior or real insurance advice.

A fire started near the round deadline retains its full staging window.
Competition and brewing stop at 900 seconds and every bay disarms; only movement,
staging and escape remain while pending incidents settle. Results are finalized
after these windows resolve. Disconnects preserve reserved round identities,
sequence numbers and hazard latches. Reconnect uses the client's in-memory private
credential; reconnecting does not rearm a bay. Server loss never transfers authority
to a client. A lobby disconnect releases its slot.

## Reproducible hosted checks

The combined SceneTree suite includes `gameplay` (deterministic rules) and
`network` (actual ENet) suites. On a permitted runner, the commands are:

```text
godot --headless --path . --script tests/run_all.gd -- --suite gameplay
godot --headless --path . --script tests/run_all.gd -- --suite network
```

The network fixture creates separate SceneMultiplayer roots and real ENet peers
for two and eight clients over loopback. It checks capacity, server identities,
ready/start, valid brewing, rejected money injection, disconnect/reconnect,
server loss and final synchronized results. It advances the host's 9,000 fixed
ticks directly to make the 900-second round test fast; this acceleration is test
code, not a client-callable RPC. Logs identify client count, elapsed time and tick.
This is actual transport evidence, but not a visible multi-window playthrough.

The integration follows [Godot's high-level multiplayer API](https://docs.godotengine.org/en/4.4/tutorials/networking/high_level_multiplayer.html).
Only the authenticated ENet sender identity reaches the authority. Public snapshots
omit credential and peer mapping dictionaries. Sequence, round and tick checks,
bounded input queues, message sizes and per-peer request budgets reject malformed
or replayed intents. Phase transitions and results travel reliably.

Advanced fire/beer shaders, companion consumption, rendered playthrough proof and
final release acceptance remain separate milestones. Do not infer them from these
tests or from placeholder rival/projectile/fire meshes.
