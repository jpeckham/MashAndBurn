extends Node
const Producer = preload("res://src/hardware/telemetry_producer.gd")
const Client = preload("res://src/hardware/bridge_client.gd")
var producer := Producer.new()
var client := Client.new()
var garage: Node
var network: Node
var activated := false
var remote_seen := false
var toggle_button: Button
var caption: Label

func _init() -> void:
	name = "HardwareBridge"

func setup(host: Node) -> void:
	garage = host
	network = garage.get_node("Multiplayer").network
	network.changed.connect(safety_update)
	toggle_button = garage.button("Send mock telemetry",garage.module_slot,func():
		if activated: stop()
		else: start())
	caption = garage.label("Companion off — no connection",garage.module_slot,12)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.x = 290

func source() -> Dictionary:
	var state: Dictionary = garage.session.state
	var context := {"connected":true,"paused":garage.paused,"sensor_ok":true,"estop":false,"hazard":"none","fire_phase":"idle"}
	var players: Dictionary = network.view.get("players",{})
	if players.has(network.player_id):
		remote_seen = true
		var player: Dictionary = players[network.player_id]
		state = player.batch
		context.connected = network.session_connected and player.connected
		context.paused = network.view.get("phase") != "running"
		context.fire_phase = player.fire.phase
		context.hazard = "fire" if player.fire.phase == "staging" else ("hazard" if network.view.get("hardware_safe",false) else "none")
	elif remote_seen:
		context.connected = false
	else:
		for event in garage.session.events:
			if event.get("type") == "HazardEvent" and event.get("kind") in ["hazard","fire","disconnect","overpressure"]: context.hazard = event.kind
	return {"state":state,"context":context}

func start(url: String = "", credential: String = "") -> bool:
	if url.is_empty(): url = OS.get_environment("MAB_BRIDGE_URL")
	if url.is_empty(): url = "ws://127.0.0.1:27842/api/v1/telemetry"
	# No operator credential is read, stored or transmitted by the game.
	if credential.is_empty(): credential = OS.get_environment("MAB_BRIDGE_TOKEN")
	if not client.start(url,credential):
		caption.text = client.error
		return false
	activated = true
	remote_seen = false
	producer.set_enabled(true)
	toggle_button.text = "Stop mock telemetry"
	caption.text = "Connecting to local mock companion…"
	return true

func stop() -> void:
	producer.set_enabled(false)
	if client.ready:
		var current := source()
		client.send_frame(producer.make_frame(current.state,current.context,int(Time.get_unix_time_from_system()*1000)))
	client.stop()
	activated = false
	toggle_button.text = "Send mock telemetry"
	caption.text = "Companion off — no connection"

func safety_update() -> void:
	if not activated or not client.ready: return
	var current := source()
	for frame in producer.advance(0,current.state,current.context,int(Time.get_unix_time_from_system()*1000)): client.send_frame(frame)

func on_state(_state: Dictionary) -> void:
	safety_update()

func _process(delta: float) -> void:
	if not activated: return
	client.poll()
	if not client.error.is_empty():
		producer.trip("connection-lost")
		caption.text = client.error
		return
	if not client.ready: return
	var current := source()
	for frame in producer.advance(delta,current.state,current.context,int(Time.get_unix_time_from_system()*1000)): client.send_frame(frame)
	if producer.latched: caption.text = "Requests latched off: "+producer.fault
	elif client.last_reply.get("armed",false): caption.text = "Mock outputs active — simulator only"
	else: caption.text = "Companion disarmed — separate local operator action required"

func _exit_tree() -> void:
	client.stop()
