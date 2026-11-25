extends RefCounted

func run(t) -> void:
	if not FileAccess.file_exists("res://src/contracts/protocol.gd"):
		t.check(false, "protocol v1 implemented")
		return
	var p = load("res://src/contracts/protocol.gd").new()
	var examples = JSON.parse_string(FileAccess.get_file_as_string("res://src/contracts/examples.json"))
	for example in examples:
		t.check(p.validate(example).is_empty(), "valid example " + example.type)
		t.check(p.decode(JSON.stringify(example)).ok, "JSON round trip " + example.type)
		example.version = 99
		t.check(not p.decode(JSON.stringify(example)).ok, "unsupported version")
	for bad in ["{", "null", "[]", "1", '{"version":1,"type":"Unknown"}']:
		t.check(not p.decode(bad).ok, "malformed message rejected")
	var cmd := {"type":"PlayerCommand", "version":1, "seq":0, "tick":0, "action":"set", "field":"grain_kg", "value":-1.0}
	t.check(not p.validate(cmd).is_empty(), "negative setting rejected")
	cmd.value = NAN
	t.check(not p.validate(cmd).is_empty(), "nonfinite setting rejected")
	cmd.value = 5.0
	cmd.action = "explode"
	t.check(not p.validate(cmd).is_empty(), "unsupported action rejected")
	var frame := {"type":"HardwareFrame", "version":1, "seq":0, "tick":0, "enabled":true, "safe_state":true, "heater":1.0, "pump":0.0}
	t.check(not p.validate(frame).is_empty(), "hardware safe-state rejects energized output")
