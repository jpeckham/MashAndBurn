#!/usr/bin/env bash
set -euo pipefail
if [[ ${GITHUB_ACTIONS:-} != true || ${RUNNER_ENVIRONMENT:-} != github-hosted ]]; then
  echo 'This launcher is restricted to disposable GitHub-hosted runners.' >&2
  exit 2
fi
mkdir -p .tools/multiplayer-proof/host .tools/multiplayer-proof/guest
common=(--path . --display-driver x11 --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy --max-fps 30 --script tests/render/multiplayer_proof.gd)
timeout 900s "$GODOT" "${common[@]}" --position 0,0 -- --role host > .tools/multiplayer-proof/host/process.log 2>&1 &
host_pid=$!
timeout 900s "$GODOT" "${common[@]}" --position 1400,0 -- --role guest > .tools/multiplayer-proof/guest/process.log 2>&1 &
guest_pid=$!
cleanup() {
  kill "$host_pid" "$guest_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM
set +e
wait -n -p completed_pid "$host_pid" "$guest_pid"
first_status=$?
set -e
if (( first_status != 0 )); then
  echo "Pair process $completed_pid failed with $first_status" >&2
  tail -n 35 .tools/multiplayer-proof/{host,guest}/process.log
  exit "$first_status"
fi
if [[ $completed_pid == "$host_pid" ]]; then remaining=$guest_pid; else remaining=$host_pid; fi
set +e
wait "$remaining"
second_status=$?
set -e
cat .tools/multiplayer-proof/{host,guest}/process.log
if (( second_status != 0 )); then exit "$second_status"; fi
python3 - <<'PY'
import json, pathlib
for role in ('host', 'guest'):
    folder = pathlib.Path('.tools/multiplayer-proof') / role
    report = json.loads((folder / 'manifest.json').read_text())
    assert report['exit_code'] == 0 and report['failures'] == 0, (role, report)
    assert len(report['captures']) >= 10, role
    assert 'SCRIPT ERROR:' not in (folder/'process.log').read_text(), role
    print('PAIR_VERIFIED', role, report['checks'], len(report['captures']))
PY
for role in host guest; do (cd ".tools/multiplayer-proof/$role" && sha256sum *.png > SHA256SUMS.txt); done
