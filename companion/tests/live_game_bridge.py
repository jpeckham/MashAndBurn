"""Runs the real Godot client against a real loopback ASGI/WebSocket server on CI."""
import copy
import json
import os
import pathlib
import secrets
import socket
import statistics
import subprocess
import sys
import threading
import time

import httpx
import uvicorn

from mash_burn_bridge.app import create_app
from mash_burn_bridge.config import Settings
from mash_burn_bridge.controller import BridgeController
from mash_burn_bridge.models import HardwareFrame
from mash_burn_bridge.transports import MockTransport


class RecordingController(BridgeController):
    def __init__(self):
        super().__init__(MockTransport())
        self.received = []

    def ingest(self, packet):
        valid = True
        try:
            HardwareFrame.model_validate(packet)
        except ValueError:
            valid = False
        accepted = super().ingest(packet)
        self.received.append(dict(at=time.time(), schema_valid=valid, accepted=accepted, frame=copy.deepcopy(packet), armed=self.armed, outputs=copy.deepcopy(self.outputs)))
        return accepted


def main():
    if os.environ.get("GITHUB_ACTIONS") != "true" or os.environ.get("RUNNER_ENVIRONMENT") != "github-hosted":
        raise RuntimeError("Live interoperability requires a disposable GitHub-hosted runner")
    project = pathlib.Path(__file__).resolve().parents[2]
    output = project / ".tools/bridge-proof"
    output.mkdir(parents=True, exist_ok=True)
    token, operator = secrets.token_hex(32), secrets.token_hex(32)
    print(f"::add-mask::{token}", flush=True)
    print(f"::add-mask::{operator}", flush=True)
    controller = RecordingController()
    app = create_app(Settings(token=token, operator_token=operator), controller=controller)
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    listener.listen(128)
    port = listener.getsockname()[1]
    server = uvicorn.Server(uvicorn.Config(app, host="127.0.0.1", port=port, ws_max_size=4096, log_level="warning", access_log=False))
    thread = threading.Thread(target=server.run, kwargs={"sockets": [listener]}, daemon=True)
    thread.start()
    process = None
    events = []

    def wait_for(predicate, detail, seconds=20):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if predicate():
                return
            if process is not None and process.poll() is not None:
                raise AssertionError("Game exited before " + detail)
            time.sleep(0.02)
        raise AssertionError("Timed out: " + detail)

    def marker(name):
        (output / f"{name}.json").write_text(json.dumps(dict(phase=name, at=time.time())))

    def record(name):
        events.append(dict(event=name, at=time.time(), armed=controller.armed, outputs=copy.deepcopy(controller.outputs), fault=controller.fault))

    try:
        wait_for(lambda: server.started, "ASGI startup")
        game_env = os.environ.copy()
        game_env.pop("MAB_OPERATOR_TOKEN", None)
        game_env["MAB_BRIDGE_TOKEN"] = token
        game_env["MAB_BRIDGE_URL"] = f"ws://127.0.0.1:{port}/api/v1/telemetry"
        with (output / "game.log").open("w") as log:
            process = subprocess.Popen([os.environ["GODOT"], "--headless", "--path", str(project), "--rendering-method", "gl_compatibility", "--max-fps", "60", "--script", "tests/hardware/live_bridge.gd"], env=game_env, stdout=log, stderr=subprocess.STDOUT)
            wait_for(lambda: len(controller.received) >= 12, "actual game telemetry")
            initial = list(controller.received)
            assert all(row["schema_valid"] for row in initial)
            rate = (len(initial) - 1) / (initial[-1]["at"] - initial[0]["at"])
            assert 8 <= rate <= 12, rate
            assert not controller.armed and controller.outputs == controller.safe_outputs()
            with httpx.Client(base_url=f"http://127.0.0.1:{port}", timeout=2, trust_env=False) as http:
                tele_headers = {"Authorization": "Bearer " + token}
                op_headers = {"Authorization": "Bearer " + operator}
                assert http.post("/api/v1/arm", headers=tele_headers, json={"confirm": True}).status_code == 401
                assert http.post("/api/v1/arm", headers=op_headers, json={"confirm": True}).status_code == 200
                wait_for(lambda: controller.outputs["heater"] > 0, "armed mock output")
                record("independent-operator-armed")
                assert http.post("/api/v1/estop", headers=op_headers).status_code == 200
                record("operator-estop")
                assert not controller.armed and controller.outputs == controller.safe_outputs()
                count = len(controller.received)
                wait_for(lambda: len(controller.received) >= count + 4, "fresh frames after E-stop")
                assert not controller.armed and controller.outputs == controller.safe_outputs()
                assert http.post("/api/v1/estop/clear", headers=op_headers, json={"confirm": True}).status_code == 200
                wait_for(lambda: controller.healthy, "fresh sensor frame after clear")
                assert not controller.armed
                assert http.post("/api/v1/arm", headers=op_headers, json={"confirm": True}).status_code == 200
                wait_for(lambda: controller.outputs["heater"] > 0, "explicit mock rearm")
                record("explicit-local-rearm")
                marker("operator-armed")
                wait_for(lambda: (output / "game-fired.json").exists() and any(row["frame"].get("hazard") == "fire" for row in controller.received), "actual game fire telemetry")
                assert not controller.armed and controller.outputs == controller.safe_outputs()
                record("game-fire-cutoff")
                marker("fire-observed")
                wait_for(lambda: (output / "healthy-after-fire-still-latched.json").exists() and not controller.connected, "actual game disconnect")
                assert not controller.armed and controller.outputs == controller.safe_outputs()
                record("game-disconnect")
                marker("disconnect-observed")
                process.wait(timeout=10)
                assert process.returncode == 0
        text = (output / "game.log").read_text()
        assert "SCRIPT ERROR:" not in text and "ERROR:" not in text, text
        assert all(row["schema_valid"] for row in controller.received)
        intervals = [b["at"] - a["at"] for a, b in zip(initial, initial[1:])]
        report = dict(source_commit=os.environ.get("GITHUB_SHA"), run_id=os.environ.get("GITHUB_RUN_ID"), python=sys.version, telemetry_frames=len(controller.received), initial_rate_hz=rate, median_interval_ms=statistics.median(intervals) * 1000, events=events, received=controller.received, controller_trace=controller.trace, operator_credential_hidden_from_game=True, physical_operation=False)
        (output / "bridge-proof.json").write_text(json.dumps(report, indent=2))
        print("LIVE_BRIDGE_RESULT " + json.dumps({key: report[key] for key in ("telemetry_frames", "initial_rate_hz", "median_interval_ms", "operator_credential_hidden_from_game", "physical_operation")}))
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
        server.should_exit = True
        thread.join(5)
        listener.close()
        controller.disconnect()


if __name__ == "__main__":
    main()
