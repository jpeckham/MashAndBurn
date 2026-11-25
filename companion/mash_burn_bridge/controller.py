"""Latched mock HAL interlocks independent of the game and HTTP framework."""
import copy
import math
import time

from pydantic import ValidationError

from .models import HardwareFrame
from .transports import safe_outputs


class BridgeController:
    INTERVAL = 0.1
    HEARTBEAT = 0.3

    def __init__(self, transport, *, monotonic=time.monotonic, unix_time=time.time):
        self.transport = transport
        self.monotonic = monotonic
        self.unix_time = unix_time
        self.armed = False
        self.fault = "startup"
        self.outputs = safe_outputs()
        self.queue = []
        self.planned_waypoints = []
        self.trace = []
        self.frame = None
        self.last_seq = -1
        self.last_sent_ms = -1
        self.last_receive = None
        self.last_tick = monotonic()
        self.next_tick = self.last_tick
        self.healthy = False
        self.connected = True
        self.local_estop = False
        self.last_hopper = None
        self.transport.stop()

    @staticmethod
    def safe_outputs():
        return safe_outputs()

    def trip(self, reason):
        self.armed = False
        self.healthy = False
        self.fault = reason
        self.outputs = safe_outputs()
        self.queue.clear()
        self.planned_waypoints.clear()
        self.last_hopper = None
        self.transport.stop()
        self.trace.append(dict(event="disarm", reason=reason, at=self.monotonic()))
        del self.trace[:-1024]
        return False

    def ingest(self, packet):
        # Check the OLD heartbeat before a fresh frame can replace its timestamp.
        # A scheduler pause must latch stop even when the next input looks healthy.
        if self.armed and not self.fresh():
            self.trip("heartbeat-lost-before-frame")
        try:
            candidate = HardwareFrame.model_validate(packet)
        except (ValidationError, TypeError, ValueError):
            return self.trip("malformed-frame")
        age = self.unix_time() - candidate.sent_at_unix_ms / 1000
        if not math.isfinite(age) or age > self.HEARTBEAT or age < -0.1:
            return self.trip("stale-or-future-frame")
        if candidate.seq <= self.last_seq or candidate.sent_at_unix_ms < self.last_sent_ms:
            return self.trip("replayed-or-reordered-frame")
        self.last_seq = candidate.seq
        self.last_sent_ms = candidate.sent_at_unix_ms
        self.frame = candidate
        self.last_receive = self.monotonic()
        reason = self.frame_fault()
        if reason:
            return self.trip(reason)
        self.healthy = True
        hopper = candidate.hop_drop_hopper
        if self.armed and hopper is not None and hopper != self.last_hopper:
            if not self.queue_command(dict(kind="hop", hopper=hopper)):
                return self.trip("command-queue-full")
        self.last_hopper = hopper
        return True

    def frame_fault(self):
        frame = self.frame
        if frame is None:
            return "missing-frame"
        if not self.connected or not frame.connected:
            return "disconnect"
        if self.local_estop or frame.estop:
            return "e-stop"
        if not frame.sensor_ok or frame.sensor_temp_c is None:
            return "sensor-error"
        if frame.sensor_temp_c >= 102:
            return "thermal-cutoff"
        if frame.hazard != "none" or frame.fire_phase == "staging" or frame.safe_state:
            return "hazard"
        if not frame.enabled:
            return "disabled"
        return ""

    def fresh(self):
        if self.last_receive is None:
            return False
        elapsed = self.monotonic() - self.last_receive
        age = self.unix_time() - self.frame.sent_at_unix_ms / 1000
        return 0 <= elapsed <= self.HEARTBEAT and -0.1 <= age <= self.HEARTBEAT

    def arm(self):
        if not self.transport.is_mock:
            return self.trip("physical-safeguards-unverified")
        if not self.healthy or not self.fresh() or self.frame_fault():
            return False
        self.armed = True
        self.fault = ""
        self.trace.append(dict(event="explicit-local-arm", at=self.monotonic()))
        del self.trace[:-1024]
        return True

    def tick(self):
        now = self.monotonic()
        if now < self.last_tick:
            return self.trip("clock-regression")
        self.last_tick = now
        if self.armed and (not self.healthy or not self.fresh() or self.frame_fault()):
            return self.trip(self.frame_fault() or "heartbeat-or-interlock-lost")
        if now + 0.000000001 < self.next_tick:
            return False
        self.next_tick = now + self.INTERVAL  # Skip missed slots; never burst stale work.
        if not self.armed:
            return False
        frame = self.frame
        # Demonstration proportional limiter, not a calibrated physical PID.
        heating = min(frame.heater, max(0.0, (frame.target_temp_c - frame.sensor_temp_c) / 5))
        self.outputs = dict(heater=heating, pump=frame.pump, valve_states=list(frame.valve_states), hop_drop_hopper=None)
        if self.queue:
            command = self.queue.pop(0)
            if command["kind"] == "hop":
                self.outputs["hop_drop_hopper"] = command["hopper"]
        self.transport.write(self.outputs)
        return True

    def queue_command(self, command):
        if not self.armed or not self.healthy or not self.fresh() or len(self.queue) >= 16:
            return False
        if not isinstance(command, dict) or set(command) != {"kind", "hopper"} or command["kind"] != "hop" or type(command["hopper"]) is not int or not 0 <= command["hopper"] <= 3:
            return False
        self.queue.append(copy.deepcopy(command))
        return True

    def plan_waypoints(self, points):
        if not self.armed or not self.transport.is_mock or not self.fresh():
            raise ValueError("Simulated planning requires a healthy armed mock")
        if not isinstance(points, list) or not 1 <= len(points) <= 16:
            raise ValueError("One to sixteen simulated waypoints required")
        for point in points:
            if not isinstance(point, list) or len(point) != 3 or any(type(v) not in (float, int) or not math.isfinite(v) for v in point):
                raise ValueError("Invalid simulated waypoint")
            if not (-0.3 <= point[0] <= 0.3 and -0.3 <= point[1] <= 0.3 and 0.1 <= point[2] <= 0.5):
                raise ValueError("Outside simulated workspace")
        self.planned_waypoints = copy.deepcopy(points)
        return copy.deepcopy(points)

    def disconnect(self):
        self.connected = False
        self.trip("disconnect")

    def connect(self):
        self.connected = True
        self.trip("new-connection")
        # A new authenticated, exclusive socket is a new stream. It starts
        # disarmed and must supply fresh telemetry before a local arm action.
        self.last_seq = -1
        self.last_sent_ms = -1
        self.frame = None
        self.last_receive = None

    def emergency_stop(self):
        self.local_estop = True
        self.trip("e-stop")

    def clear_estop(self):
        self.local_estop = False
        self.trip("e-stop-cleared")  # Also safe if called during armed operation.
