import json
import time

import pytest
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from test_controller import Clock, frame

TOKEN = "hosted-test-token-with-no-real-account-credentials"
AUTH = {"Authorization": "Bearer " + TOKEN}


@pytest.fixture
def service():
    from mash_burn_bridge.app import create_app
    from mash_burn_bridge.config import Settings
    from mash_burn_bridge.controller import BridgeController
    from mash_burn_bridge.transports import MockTransport

    clock = Clock()
    controller = BridgeController(MockTransport(), monotonic=clock, unix_time=clock)
    app = create_app(Settings(token=TOKEN), controller=controller)
    with TestClient(app, client=("127.0.0.1", 12345)) as client:
        yield client, controller, clock


def status(client):
    response = client.get("/api/v1/status", headers=AUTH)
    assert response.status_code == 200
    assert TOKEN not in response.text
    return response.json()


def wait_output(client):
    for _ in range(60):
        current = status(client)
        if current["outputs"]["heater"] > 0:
            return current
        time.sleep(0.01)
    pytest.fail("10 Hz watchdog never applied healthy mock output")


def test_auth_required_and_no_fresh_frame_cannot_arm(service):
    client, _, _ = service
    assert client.get("/api/v1/status").status_code == 401
    assert client.post("/api/v1/arm", headers={"Authorization": "Bearer wrong"}, json={"confirm": True}).status_code == 401
    assert client.post("/api/v1/arm", headers=AUTH, json={"confirm": True}).status_code == 409
    assert client.post("/api/v1/arm", headers=AUTH, json={"confirm": False}).status_code == 400
    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect("/api/v1/telemetry"):
            pass


def test_real_websocket_fault_latch_rearm_and_disconnect(service):
    client, controller, clock = service
    with client.websocket_connect("/api/v1/telemetry", headers=AUTH) as socket:
        assert socket.receive_json()["transport"].startswith("mock-")
        socket.send_json(frame(clock))
        assert socket.receive_json()["ok"]
        assert not status(client)["armed"]
        assert client.post("/api/v1/arm", headers=AUTH, json={"confirm": True}).status_code == 200
        clock.advance(0.11)
        socket.send_json(frame(clock, 2))
        assert socket.receive_json()["ok"]
        assert wait_output(client)["outputs"]["pump"] == 0.5
        socket.send_text("{malformed")
        assert not socket.receive_json()["ok"]
        assert not status(client)["armed"]
        assert controller.outputs == controller.safe_outputs()
        socket.send_json(frame(clock, 3))
        assert socket.receive_json()["ok"]
        assert not status(client)["armed"]
        assert client.post("/api/v1/arm", headers=AUTH, json={"confirm": True}).status_code == 200
    assert not status(client)["armed"]
    assert controller.outputs == controller.safe_outputs()


def test_duplicate_socket_cannot_disarm_or_replace_active_owner(service):
    client, _, clock = service
    with client.websocket_connect("/api/v1/telemetry", headers=AUTH) as first:
        first.receive_json()
        first.send_json(frame(clock))
        assert first.receive_json()["ok"]
        assert client.post("/api/v1/arm", headers=AUTH, json={"confirm": True}).status_code == 200
        with pytest.raises(WebSocketDisconnect):
            with client.websocket_connect("/api/v1/telemetry", headers=AUTH):
                pass
        assert status(client)["armed"]


def test_heartbeat_estop_and_fresh_local_rearm(service):
    client, controller, clock = service
    with client.websocket_connect("/api/v1/telemetry", headers=AUTH) as socket:
        socket.receive_json()
        socket.send_json(frame(clock))
        socket.receive_json()
        assert client.post("/api/v1/arm", headers=AUTH, json={"confirm": True}).status_code == 200
        clock.advance(0.31)
        for _ in range(50):
            if not status(client)["armed"]:
                break
            time.sleep(0.01)
        assert not status(client)["armed"]
        assert controller.outputs == controller.safe_outputs()
        socket.send_json(frame(clock, 2))
        socket.receive_json()
        assert client.post("/api/v1/arm", headers=AUTH, json={"confirm": True}).status_code == 200
        assert client.post("/api/v1/estop", headers=AUTH).status_code == 200
        assert not status(client)["armed"]
        assert client.post("/api/v1/estop/clear", headers=AUTH, json={"confirm": True}).status_code == 200
        assert client.post("/api/v1/arm", headers=AUTH, json={"confirm": True}).status_code == 409
        socket.send_json(frame(clock, 3))
        socket.receive_json()
        assert client.post("/api/v1/arm", headers=AUTH, json={"confirm": True}).status_code == 200
    from pathlib import Path
    folder = Path(".tools/evidence")
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "mock-interlocks.json").write_text(json.dumps({"trace": controller.trace, "outputs": controller.outputs, "physical_operation": False}, indent=2))


def test_oversized_frame_fails_safe(service):
    client, controller, clock = service
    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect("/api/v1/telemetry", headers=AUTH) as socket:
            socket.receive_json()
            socket.send_json(frame(clock))
            socket.receive_json()
            client.post("/api/v1/arm", headers=AUTH, json={"confirm": True})
            socket.send_text("x" * 4097)
            socket.receive_json()
    assert not controller.armed
    assert controller.outputs == controller.safe_outputs()


def test_remote_peer_cannot_arm_with_even_a_valid_token():
    from mash_burn_bridge.app import create_app
    from mash_burn_bridge.config import Settings
    with TestClient(create_app(Settings(token=TOKEN)), client=("192.0.2.55", 12345)) as remote:
        assert remote.post("/api/v1/arm", headers=AUTH, json={"confirm": True}).status_code == 403


def test_service_refuses_missing_auth_configuration():
    from mash_burn_bridge.config import Settings
    with pytest.raises(ValueError):
        Settings(token="")
