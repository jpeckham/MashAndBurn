import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest
from fastapi.testclient import TestClient

from test_app import TELEMETRY_AUTH as AUTH, TOKEN


@pytest.fixture
def receiver():
    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            packet = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            self.server.received.append(packet)
            code = self.server.responses.pop(0) if self.server.responses else 200
            self.send_response(code)
            if code == 302:
                self.send_header("Location", "http://127.0.0.1:1/must-not-follow")
            self.end_headers()
        def log_message(self, *_args):
            pass
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.received = []
    server.responses = []
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    yield server, f"http://127.0.0.1:{server.server_port}/private-test-channel"
    server.shutdown()
    server.server_close()
    thread.join(2)


def packet(event="batch-1", **changes):
    request = dict(event_id=event, destination="friends", beer_name="Test batch", score=39.0, flaws=["Warm fermentation"])
    request.update(changes)
    return request


def client_for(url, **changes):
    from mash_burn_bridge.app import create_app
    from mash_burn_bridge.config import Destination, Settings
    options = dict(token=TOKEN, notifications_enabled=True, notification_consent=True, destinations={"friends": Destination(url=url, consent=True, private=True)}, rate_per_minute=2)
    options.update(changes)
    return TestClient(create_app(Settings(**options)), client=("127.0.0.1", 12345))


@pytest.mark.parametrize("changes", [{"notifications_enabled": False}, {"notification_consent": False}, {"destinations": {}}])
def test_disabled_or_unconsented_requests_never_leave_process(receiver, changes):
    server, url = receiver
    with client_for(url, **changes) as client:
        assert client.post("/api/v1/psyops/roast", headers=AUTH, json=packet()).status_code == 403
    assert server.received == []


def test_default_is_disabled_and_token_is_required(receiver):
    server, url = receiver
    from mash_burn_bridge.app import create_app
    from mash_burn_bridge.config import Settings
    with TestClient(create_app(Settings(token=TOKEN)), client=("127.0.0.1", 12345)) as client:
        assert client.post("/api/v1/psyops/roast", headers=AUTH, json=packet()).status_code == 403
    with client_for(url) as client:
        assert client.post("/api/v1/psyops/roast", json=packet()).status_code == 401
        assert client.post("/api/v1/psyops/roast", headers={"Authorization": "Bearer wrong"}, json=packet()).status_code == 401
    assert server.received == []


def test_destination_privacy_consent_and_exact_allowlist(receiver):
    server, url = receiver
    from mash_burn_bridge.config import Destination
    for destination in [Destination(url=url, consent=False, private=True), Destination(url=url, consent=True, private=False)]:
        with client_for(url, destinations={"friends": destination}) as client:
            assert client.post("/api/v1/psyops/roast", headers=AUTH, json=packet()).status_code == 403
    with client_for(url) as client:
        assert client.post("/api/v1/psyops/roast", headers=AUTH, json=packet(destination=url)).status_code in (403, 422)
        assert client.post("/api/v1/psyops/roast", headers=AUTH, json=packet(destination="public")).status_code == 403
    assert server.received == []


def test_fake_private_receiver_deduplication_and_rate_limit(receiver):
    server, url = receiver
    with client_for(url) as client:
        assert client.post("/api/v1/psyops/roast", headers=AUTH, json=packet()).status_code == 202
        duplicate = client.post("/api/v1/psyops/roast", headers=AUTH, json=packet())
        assert duplicate.status_code == 200 and duplicate.json()["status"] == "duplicate"
        assert client.post("/api/v1/psyops/roast", headers=AUTH, json=packet("batch-2")).status_code == 202
        assert client.post("/api/v1/psyops/roast", headers=AUTH, json=packet("batch-3")).status_code == 429
    assert len(server.received) == 2
    assert "fictional" in server.received[0]["text"].lower()
    assert TOKEN not in json.dumps(server.received)


def test_retries_are_bounded_and_redirects_never_followed(receiver):
    server, url = receiver
    server.responses[:] = [500, 502, 200]
    with client_for(url) as client:
        assert client.post("/api/v1/psyops/roast", headers=AUTH, json=packet()).status_code == 202
        assert len(server.received) == 3
        server.responses[:] = [302]
        assert client.post("/api/v1/psyops/roast", headers=AUTH, json=packet("redirect")).status_code == 502
        assert len(server.received) == 4


def test_exhausted_retries_remain_deduplicated(receiver):
    server, url = receiver
    server.responses[:] = [500] * 20
    with client_for(url) as client:
        assert client.post("/api/v1/psyops/roast", headers=AUTH, json=packet()).status_code == 502
        assert len(server.received) == 3
        response = client.post("/api/v1/psyops/roast", headers=AUTH, json=packet())
        assert response.status_code == 200 and response.json()["previous"] == "failed"
    assert len(server.received) == 3


def test_payload_bounds_prevent_outbound_request(receiver):
    server, url = receiver
    with client_for(url) as client:
        for changes in [{"beer_name": "x" * 81}, {"flaws": ["x"] * 17}, {"score": -1}, {"unexpected": "field"}]:
            assert client.post("/api/v1/psyops/roast", headers=AUTH, json=packet(**changes)).status_code == 422
    assert server.received == []
