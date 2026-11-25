import math

import pytest


class Clock:
    def __init__(self):
        self.value = 1000.0

    def __call__(self):
        return self.value

    def advance(self, seconds):
        self.value += seconds


def frame(clock, sequence=1, **changes):
    packet = dict(
        type="HardwareFrame", version=1, seq=sequence, tick=sequence,
        sent_at_unix_ms=round(clock() * 1000), step="MASH_IN",
        enabled=True, safe_state=False, heater=0.8, pump=0.5,
        target_temp_c=66.7, pump_duty=0.5, valve_states=[1, 0, 1],
        hop_drop_hopper=None, sensor_temp_c=65.0, sensor_ok=True,
        connected=True, estop=False, hazard="none", fire_phase="idle",
    )
    packet.update(changes)
    return packet


@pytest.fixture
def bridge():
    from mash_burn_bridge.controller import BridgeController
    from mash_burn_bridge.transports import MockTransport

    clock = Clock()
    transport = MockTransport("serial")
    controller = BridgeController(transport, monotonic=clock, unix_time=clock)
    return controller, transport, clock


def arm(bridge):
    controller, _, clock = bridge
    assert controller.ingest(frame(clock))
    assert controller.arm()
    assert controller.tick()
    assert controller.outputs["heater"] > 0
    assert controller.outputs["pump"] == 0.5
    return bridge


def assert_safe(controller, transport):
    assert not controller.armed
    assert controller.outputs == controller.safe_outputs()
    assert transport.outputs == controller.safe_outputs()
    assert controller.queue == []


def test_healthy_telemetry_never_arms_automatically(bridge):
    controller, transport, clock = bridge
    assert controller.ingest(frame(clock))
    controller.tick()
    assert_safe(controller, transport)


@pytest.mark.parametrize("changes", [
    {"version": 2}, {"type": "PlayerCommand"}, {"seq": True},
    {"heater": math.nan}, {"pump": math.inf}, {"target_temp_c": -1.0},
    {"target_temp_c": 101.0}, {"pump_duty": 1.1}, {"pump_duty": 0.4},
    {"step": "UNKNOWN"}, {"valve_states": [1, 1]}, {"valve_states": [1, 9, 0]},
    {"hop_drop_hopper": 4}, {"untrusted": True}, {"sensor_temp_c": None},
    {"sensor_ok": False}, {"estop": True}, {"connected": False},
    {"sensor_temp_c": 102.0}, {"sensor_temp_c": 130.0},
    {"hazard": "fire"}, {"fire_phase": "staging"}, {"safe_state": True},
    {"enabled": False}, {"seq": 1}, {"tick": -1},
])
def test_every_fault_latches_outputs_and_discards_queue(bridge, changes):
    controller, transport, clock = arm(bridge)
    assert controller.queue_command({"kind": "hop", "hopper": 1})
    assert not controller.ingest(frame(clock, 2, **changes))
    assert_safe(controller, transport)
    assert controller.fault
    # Clearing the input fault cannot restart outputs or resurrect queued work.
    assert controller.ingest(frame(clock, 3))
    controller.tick()
    assert_safe(controller, transport)
    assert controller.arm()
    clock.advance(0.1)
    assert controller.tick()
    assert controller.outputs["pump"] == 0.5


def test_stale_future_and_missing_sensor_frames_stop_immediately(bridge):
    controller, transport, clock = arm(bridge)
    for changes in ({"sent_at_unix_ms": 999000}, {"sent_at_unix_ms": 1000500}):
        assert not controller.ingest(frame(clock, 2, **changes))
        assert_safe(controller, transport)
    packet = frame(clock, 3)
    del packet["sensor_temp_c"]
    assert not controller.ingest(packet)
    assert_safe(controller, transport)


def test_heartbeat_disconnect_estop_and_explicit_rearm(bridge):
    controller, transport, clock = arm(bridge)
    clock.advance(0.31)
    controller.tick()
    assert_safe(controller, transport)
    assert not controller.arm()
    assert controller.ingest(frame(clock, 2))
    assert controller.arm()
    controller.disconnect()
    assert_safe(controller, transport)
    assert not controller.arm()
    controller.connect()
    assert controller.ingest(frame(clock, 3))
    assert controller.arm()
    controller.emergency_stop()
    assert_safe(controller, transport)
    assert not controller.arm()
    controller.clear_estop()
    assert not controller.arm()  # Clearing an E-stop also requires a fresh frame.
    assert controller.ingest(frame(clock, 4))
    assert controller.arm()


def test_scheduler_is_10hz_and_does_not_burst_after_a_pause(bridge):
    controller, transport, clock = arm(bridge)
    count = len(transport.writes)
    for _ in range(9):
        clock.advance(0.01)
        assert not controller.tick()
    assert len(transport.writes) == count
    clock.advance(0.011)
    assert controller.tick()
    assert len(transport.writes) == count + 1
    clock.advance(0.8)
    assert controller.ingest(frame(clock, 2))
    assert controller.tick()
    assert len(transport.writes) == count + 2
    assert not controller.tick()


def test_clock_regression_and_unarmed_queue_are_safe(bridge):
    controller, transport, clock = bridge
    assert not controller.queue_command({"kind": "hop", "hopper": 0})
    arm(bridge)
    clock.advance(-1)
    controller.tick()
    assert_safe(controller, transport)


@pytest.mark.parametrize("kind", ["serial", "mqtt", "websocket"])
def test_mock_transport_round_trip(kind):
    from mash_burn_bridge.transports import MockTransport

    adapter = MockTransport(kind)
    packet = frame(Clock())
    assert adapter.decode(adapter.encode(packet)) == packet
    with pytest.raises(ValueError):
        adapter.decode(b"{malformed")


def test_real_transports_cannot_be_armed_by_configuration_flags():
    from mash_burn_bridge.controller import BridgeController
    from mash_burn_bridge.transports import PhysicalTransport

    clock = Clock()
    for kind in ("serial", "mqtt", "websocket"):
        transport = PhysicalTransport(kind)
        controller = BridgeController(transport, monotonic=clock, unix_time=clock)
        assert controller.ingest(frame(clock))
        assert not controller.arm()
        assert_safe(controller, transport)


def test_arm_planning_is_simulated_bounded_and_cleared_on_fault(bridge):
    controller, transport, clock = arm(bridge)
    points = [[0.0, 0.1, 0.2], [0.1, 0.1, 0.25]]
    assert controller.plan_waypoints(points) == points
    for invalid in ([[1.0, 0.1, 0.2]], [[math.nan, 0.1, 0.2]], points * 20):
        with pytest.raises(ValueError):
            controller.plan_waypoints(invalid)
    controller.emergency_stop()
    assert_safe(controller, transport)
    assert controller.planned_waypoints == []
