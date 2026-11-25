extends RefCounted

func run(t) -> void:
	var path := "res://src/hardware/telemetry_producer.gd"
	if not FileAccess.file_exists(path):
		t.check(false,"read-only 10Hz hardware telemetry producer exists")
		return
	var script = load(path)
	var producer = script.new()
	var sim = load("res://src/chemistry/brewing_simulation.gd").new()
	var protocol = load("res://src/contracts/protocol.gd").new()
	var state: Dictionary = sim.initial_state(42)
	state.target_c = 70.0
	var hash_before: String = sim.state_hash(state)
	var packet: Dictionary = producer.make_frame(state,{},1000000)
	t.check(not packet.enabled and packet.heater == 0 and packet.pump == 0,"telemetry is disabled by default")
	t.check(protocol.validate(packet).is_empty(),"extended bridge frame satisfies common v1 contract")
	producer.set_enabled(true)
	var frames: Array = []
	for i in range(50): frames.append_array(producer.advance(.02,state,{},1000020+i*20))
	t.check(frames.size() == 10,"wall-clock producer emits ten frames per second")
	for i in range(frames.size()):
		t.check(protocol.validate(frames[i]).is_empty(),"scheduled frame satisfies protocol")
		if i > 0: t.check(frames[i].seq == frames[i-1].seq+1 and frames[i].sent_at_unix_ms > frames[i-1].sent_at_unix_ms,"stream ordering is monotonic")
	t.check(frames[-1].heater > 0 and frames[-1].pump_duty == frames[-1].pump,"healthy mock controls mirror bounded target and pump duty")
	t.check(sim.state_hash(state) == hash_before,"telemetry never advances or mutates chemistry")
	for context in [{"connected":false},{"estop":true},{"sensor_ok":false},{"sensor_temp_c":null},{"sensor_temp_c":102.0},{"fire_phase":"staging"},{"hazard":"fire"}]:
		var isolated = script.new()
		isolated.set_enabled(true)
		var stopped: Array = isolated.advance(.01,state,context,1000000)
		t.check(stopped.size() == 1,"fault emits an immediate frame without waiting for its 10Hz slot")
		if stopped.is_empty(): continue
		t.check(stopped[0].safe_state and stopped[0].heater == 0 and stopped[0].pump == 0 and stopped[0].hop_drop_hopper == null,"every fault sends safe actuator requests")
		var healthy: Dictionary = isolated.make_frame(state,{},1000100)
		t.check(healthy.safe_state and healthy.heater == 0,"healthy snapshots cannot automatically clear producer latch")
	var delayed = script.new()
	delayed.set_enabled(true)
	delayed.advance(.1,state,{},1000000)
	var missed: Array = delayed.advance(.8,state,{},1000800)
	t.check(missed.size() == 1 and missed[0].safe_state,"missed process heartbeat sends one safe frame, never a catch-up burst")
	var invalid = script.new()
	invalid.set_enabled(true)
	var corrupt: Dictionary = state.duplicate(true)
	corrupt.temp_c = NAN
	packet = invalid.make_frame(corrupt,{},1000000)
	t.check(packet.safe_state and packet.heater == 0 and is_finite(packet.target_temp_c),"malformed/nonfinite chemistry cannot request active hardware")
	var hops = script.new()
	hops.set_enabled(true)
	state.stage = "boil"
	hops.make_frame(state,{},1000000)
	state.hops.append({"grams":30.0,"alpha":.05,"minutes":0.0})
	packet = hops.make_frame(state,{},1000100)
	t.check(packet.hop_drop_hopper == 0,"new hop event requests one bounded hopper")
	t.check(hops.make_frame(state,{},1000200).hop_drop_hopper == null,"held chemistry state cannot repeatedly drop hops")
