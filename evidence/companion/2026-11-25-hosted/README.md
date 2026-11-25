# Actual game and companion proof

[Hosted run45700200483](https://github.com/jpeckham/MashAndBurn/actions/runs/45700200483),
source`5d0cbf2267b01212db7b69ab8a4f2491edd4b26b`, Godot4.4.1/Python3.12.16,
disposable Ubuntu runner, Codex operator. Separate Windows2022 and Ubuntu24.04
jobs each passed59pytest cases. The same workflow packaged the tracked companion
source ZIP, schema, dependency notices and checksums successfully.

`bridge-proof.json` is the unchanged actual loopback Godot→Uvicorn/WebSocket
trace:37frames, initial10.001967Hz, median99.987745ms. The telemetry credential
cannot arm; a separate operator arms, E-stops, clears and explicitly rearms the
mock controller. Actual game fire immediately stops outputs and latches the
producer; starting a healthy new batch does not clear it. Actual disconnect
also leaves outputs safe. Operator credentials are absent from the game.

One actual game-side private alert reaches only a local fake HTTP receiver,
without an Authorization header; repeated judging refreshes do not send again.
That alert uses a deliberately injected judging fixture, not a brewing proof.
Notifications remain disabled by default outside this explicit test setup.

No physical hardware, public webhook, robot or external messaging service was
used. `game.log` records the real client result. The final rendered pair gate
additionally connects two visible game endpoints to separate mock companions.
