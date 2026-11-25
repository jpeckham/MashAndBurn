"""Hardware-free framing adapters. Physical backends never perform I/O here."""
import copy
import json


def safe_outputs():
    return dict(heater=0.0, pump=0.0, valve_states=[0, 0, 0], hop_drop_hopper=None)


class MockTransport:
    is_mock = True

    def __init__(self, kind="serial"):
        if kind not in ("serial", "mqtt", "websocket"):
            raise ValueError("Unsupported mock transport")
        self.kind = kind
        self.outputs = safe_outputs()
        self.writes = []

    def encode(self, packet):
        envelope = dict(topic="mash-burn/mock/commands", payload=packet) if self.kind == "mqtt" else packet
        wire = json.dumps(envelope, allow_nan=False, separators=(",", ":")).encode()
        if len(wire) > 65536:
            raise ValueError("Oversized mock frame")
        return wire + (b"\n" if self.kind == "serial" else b"")

    def decode(self, wire):
        if len(wire) > 65537:
            raise ValueError("Oversized mock frame")
        def reject_constant(_value):
            raise ValueError("Nonfinite JSON")
        packet = json.loads(wire, parse_constant=reject_constant)
        if self.kind == "mqtt":
            if not isinstance(packet, dict) or set(packet) != {"topic", "payload"} or packet["topic"] != "mash-burn/mock/commands":
                raise ValueError("Unexpected mock MQTT envelope")
            packet = packet["payload"]
        if not isinstance(packet, dict):
            raise ValueError("Expected object")
        return packet

    def write(self, outputs):
        self.outputs = self.decode(self.encode(outputs))
        self.writes.append(copy.deepcopy(self.outputs))
        del self.writes[:-1024]

    def stop(self):
        self.write(safe_outputs())


class PhysicalTransport:
    """Configuration boundary only: no device access or self-attested safeguards.

    A separately verified firmware cutoff and calibrated driver are prerequisites
    for a future physical implementation. This prototype cannot arm one.
    """
    is_mock = False

    def __init__(self, kind):
        if kind not in ("serial", "mqtt", "websocket"):
            raise ValueError("Unsupported physical transport")
        self.kind = kind
        self.outputs = safe_outputs()

    def write(self, _outputs):
        raise RuntimeError("Physical actuation unavailable: safeguards are unverified")

    def stop(self):
        self.outputs = safe_outputs()
