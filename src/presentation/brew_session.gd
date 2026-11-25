extends RefCounted
const Simulation = preload("res://src/chemistry/brewing_simulation.gd")
const Protocol = preload("res://src/contracts/protocol.gd")
var sim := Simulation.new()
var state: Dictionary = sim.initial_state(42)
var events: Array = []
var message := "Welcome. Mash at 66.7 C for an hour, then move to the kettle."

func route(action: String, values: Dictionary = {}) -> bool:
	var command := values.duplicate(true)
	command.action = action
	var result := sim.advance(state, command, 60.0)
	if not result.ok:
		message = result.error
		return false
	state = result.state
	events = result.events
	message = "Applied %s. %s" % [action, instructions()]
	return true

func step(ticks: int) -> void:
	for i in range(clampi(ticks,0,240)):
		if state.stage == "judging" or state.safe_state: break
		var result := sim.advance(state, {}, 60.0)
		if not result.ok:
			message = result.error
			break
		state = result.state
		events = result.events

func instructions() -> String:
	match state.stage:
		"mash": return "Mash 60+ min; conversion must reach 60%. Target 64–72 C and pH 5.2–5.6."
		"boil": return "Heat to 95+ C, add hops, and hold a 60+ min boil."
		"cooling": return "Run the chiller until wort is at or below 25 C."
		"fermentation": return "Ferment 48+ hours and reach 95% yeast progress. Hold 20 C for ale."
		"packaging": return "Set priming sugar (120 g default) or regulator pressure, then package and judge."
		"judging": return "Batch complete. See the tasting panel. New batch starts another recipe."
	return ""

func encode_save() -> String:
	return JSON.stringify({"save_version":1,"state":state}, "\t", true, true)

func decode_save(raw: String) -> bool:
	if raw.length() > 1000000:
		message = "Save exceeds 1 MB limit."
		return false
	var parser := JSON.new()
	if parser.parse(raw) != OK or not parser.data is Dictionary:
		message = "Corrupted save: expected a JSON object."
		return false
	var data: Dictionary = parser.data
	if data.get("save_version") != 1:
		message = "Unsupported save version; expected version 1."
		return false
	var err := Protocol.new().validate(data.get("state"))
	if not err.is_empty() or data.get("state",{}).get("type") != "BatchState":
		message = "Invalid saved batch: " + err
		return false
	state = data.state.duplicate(true)
	# JSON numbers are parsed as floats; restore the protocol's integer counters.
	for key in ["seed","seq","tick","version"]: state[key] = int(state[key])
	events = []
	message = "Batch loaded. " + instructions()
	return true

func save_to(path: String = "user://batch-v1.json") -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		message = "Could not write save (error %d)." % FileAccess.get_open_error()
		return false
	file.store_string(encode_save())
	message = "Saved complete batch locally."
	return true

func load_from(path: String = "user://batch-v1.json") -> bool:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		message = "No readable saved batch. Save a batch first."
		return false
	return decode_save(file.get_as_text())
