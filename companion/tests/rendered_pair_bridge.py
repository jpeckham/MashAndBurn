"""Observe two rendered game processes against separate real mock companions."""
import copy
import json
import os
import pathlib
import secrets
import socket
import subprocess
import threading
import time

import httpx
import uvicorn

from mash_burn_bridge.app import create_app
from mash_burn_bridge.config import Settings
from mash_burn_bridge.controller import BridgeController
from mash_burn_bridge.models import HardwareFrame
from mash_burn_bridge.transports import MockTransport


class RenderController(BridgeController):
    def __init__(self):
        super().__init__(MockTransport())
        self.count = 0
        self.invalid = 0
        self.initial = []
        self.first_fault = None
        self.unsafe_after_fault = 0
        self.active_output_seen = False
        self.explicit_fire = None
        self.fire_tick = None
        self.during_fire = None

    def ingest(self, packet):
        try:
            HardwareFrame.model_validate(packet)
        except ValueError:
            self.invalid += 1
        accepted = super().ingest(packet)
        self.count += 1
        if len(self.initial) < 12:
            self.initial.append(dict(at=time.time(), seq=packet.get("seq")))
        faulty = packet.get("hazard") not in (None, "none") or packet.get("fire_phase") == "staging"
        if faulty and self.first_fault is None:
            self.first_fault = dict(at=time.time(), frame=copy.deepcopy(packet), outputs=copy.deepcopy(self.outputs), armed=self.armed)
        if self.explicit_fire is None and (packet.get("hazard") == "fire" or packet.get("fire_phase") == "staging"):
            self.explicit_fire = dict(frame=copy.deepcopy(packet), outputs=copy.deepcopy(self.outputs), armed=self.armed)
        if self.during_fire is None and self.fire_tick is not None and packet.get("tick", -1) >= self.fire_tick:
            self.during_fire = dict(frame=copy.deepcopy(packet), outputs=copy.deepcopy(self.outputs), armed=self.armed)
        requested = packet.get("heater", 0) or packet.get("pump", 0) or any(packet.get("valve_states", [])) or packet.get("hop_drop_hopper") is not None
        if self.first_fault is not None and (requested or self.armed or self.outputs != self.safe_outputs()):
            self.unsafe_after_fault += 1
        if self.armed and self.outputs != self.safe_outputs():
            self.active_output_seen = True
        return accepted


def main():
    if os.environ.get("GITHUB_ACTIONS") != "true" or os.environ.get("RUNNER_ENVIRONMENT") != "github-hosted":
        raise RuntimeError("Rendered pair requires disposable GitHub-hosted runners")
    output = pathlib.Path(".tools/multiplayer-proof")
    output.mkdir(parents=True, exist_ok=True)
    game_env = os.environ.copy()
    game_env.pop("MAB_OPERATOR_TOKEN", None)
    game_env["PAIR_BRIDGE_ENABLED"] = "true"
    peers = {}
    process = None
    try:
        for role in ("host", "guest"):
            token, operator = secrets.token_hex(32), secrets.token_hex(32)
            print(f"::add-mask::{token}", flush=True)
            print(f"::add-mask::{operator}", flush=True)
            controller = RenderController()
            app = create_app(Settings(token=token, operator_token=operator), controller=controller)
            listener = socket.socket()
            listener.bind(("127.0.0.1", 0))
            listener.listen(128)
            port = listener.getsockname()[1]
            server = uvicorn.Server(uvicorn.Config(app, host="127.0.0.1", port=port, ws_max_size=4096, log_level="warning", access_log=False))
            thread = threading.Thread(target=server.run, kwargs={"sockets": [listener]}, daemon=True)
            thread.start()
            peers[role] = dict(controller=controller, server=server, thread=thread, port=port, operator=operator, armed=False)
            game_env[f"PAIR_{role.upper()}_BRIDGE_TOKEN"] = token
            game_env[f"PAIR_{role.upper()}_BRIDGE_URL"] = f"ws://127.0.0.1:{port}/api/v1/telemetry"
        deadline = time.monotonic() + 10
        while not all(peer["server"].started for peer in peers.values()):
            assert time.monotonic() < deadline, "Mock companions did not start"
            time.sleep(0.02)
        process = subprocess.Popen(["bash", "tests/render/run_pair.sh"], env=game_env)
        arm_deadline = time.monotonic() + 90
        with httpx.Client(timeout=2, trust_env=False) as http:
            while process.poll() is None:
                fire_marker = output / "guest-fire-started.json"
                if fire_marker.exists():
                    fire_tick = json.loads(fire_marker.read_text())["tick"]
                    for peer in peers.values():
                        peer["controller"].fire_tick = fire_tick
                for role, peer in peers.items():
                    controller = peer["controller"]
                    if not peer["armed"] and controller.count >= 12 and controller.healthy:
                        response = http.post(f"http://127.0.0.1:{peer['port']}/api/v1/arm", headers={"Authorization": "Bearer " + peer["operator"]}, json={"confirm": True})
                        assert response.status_code == 200, (role, response.status_code)
                        peer["armed"] = True
                        (output / f"bridge-{role}-armed.json").write_text(json.dumps(dict(role=role, independent_operator=True)))
                    if not peer["armed"]:
                        assert time.monotonic() < arm_deadline, f"No healthy rendered {role} telemetry"
                time.sleep(0.05)
        assert process.returncode == 0, process.returncode
        guest_fire = peers["guest"]["controller"].explicit_fire
        assert guest_fire is not None, "No explicit guest fire/staging telemetry"
        smoke = game_env.get("PAIR_FIRE_SMOKE") == "true"
        report = dict(source_commit=os.environ.get("GITHUB_SHA"), run_id=os.environ.get("GITHUB_RUN_ID"), physical_operation=False, operator_credentials_hidden_from_games=True, peers={})
        for role, peer in peers.items():
            controller = peer["controller"]
            assert peer["armed"] and controller.active_output_seen, f"{role}: mock output never active"
            assert controller.invalid == 0, (role, controller.invalid)
            assert controller.first_fault is not None, f"{role}: no actual network hazard cutoff"
            assert controller.during_fire is not None, f"{role}: no telemetry during the actual GUI fire"
            assert controller.during_fire["frame"]["safe_state"] and not controller.during_fire["armed"]
            assert controller.during_fire["outputs"] == controller.safe_outputs(), role
            if smoke:
                assert abs(controller.first_fault["frame"]["tick"] - guest_fire["frame"]["tick"]) <= 2, f"{role}: smoke latched before actual fire"
                assert peers["guest"]["controller"].first_fault["frame"]["fire_phase"] == "staging", "Smoke cutoff was not caused by fire"
            assert controller.unsafe_after_fault == 0, (role, controller.unsafe_after_fault)
            rate = (len(controller.initial) - 1) / (controller.initial[-1]["at"] - controller.initial[0]["at"])
            assert 8 <= rate <= 12, (role, rate)
            report["peers"][role] = dict(telemetry_frames=controller.count, initial_rate_hz=rate, schema_errors=controller.invalid, independent_operator_armed=peer["armed"], active_mock_output_seen=controller.active_output_seen, first_fault=controller.first_fault, explicit_fire=controller.explicit_fire, safe_during_actual_fire=controller.during_fire, unsafe_frames_after_fault=controller.unsafe_after_fault, fire_caused_initial_cutoff=smoke)
        (output / "rendered-bridge-proof.json").write_text(json.dumps(report, indent=2))
        print("RENDERED_PAIR_BRIDGE_RESULT " + json.dumps(report), flush=True)
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
        for peer in peers.values():
            peer["server"].should_exit = True
        for peer in peers.values():
            peer["thread"].join(timeout=5)


if __name__ == "__main__":
    main()
