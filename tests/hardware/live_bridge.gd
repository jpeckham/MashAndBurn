extends SceneTree
## Hosted interoperability fixture, not a visible playthrough or physical hardware test.
const OUTPUT := "res://.tools/bridge-proof"
var game: Node

func _initialize() -> void:
	call_deferred("run")

func marker(name_value: String) -> void:
	var file := FileAccess.open(OUTPUT+"/"+name_value+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"phase":name_value,"utc":Time.get_datetime_string_from_system(true)}))
	file.close()

func wait_for(predicate: Callable, detail: String) -> bool:
	var deadline := Time.get_ticks_msec()+20000
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await create_timer(.05).timeout
	printerr("LIVE_BRIDGE_FAIL "+detail)
	return false

func run() -> void:
	if OS.get_environment("GITHUB_ACTIONS") != "true" or OS.get_environment("RUNNER_ENVIRONMENT") != "github-hosted": quit(2); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	if not OS.get_environment("MAB_OPERATOR_TOKEN").is_empty(): printerr("LIVE_BRIDGE_FAIL operator authority must not reach the game"); quit(1); return
	game = load("res://scenes/garage/garage.tscn").instantiate()
	root.add_child(game)
	game.session.route("set",{"field":"target_c","value":95.0})
	game.paused = false
	game.refresh()
	var bridge = game.get_node("HardwareBridge")
	if not bridge.start(): printerr("LIVE_BRIDGE_FAIL "+bridge.client.error); quit(1); return
	if not await wait_for(func(): return bridge.client.ready or not bridge.client.error.is_empty(),"companion handshake"): quit(1); return
	if not bridge.client.ready: printerr("LIVE_BRIDGE_FAIL "+bridge.client.error); quit(1); return
	marker("game-connected")
	if not await wait_for(func(): return FileAccess.file_exists(OUTPUT+"/operator-armed.json"),"independent operator exercise"): quit(1); return
	await create_timer(1).timeout
	if not game.session.route("fire"): printerr("LIVE_BRIDGE_FAIL generic fire event"); quit(1); return
	game.refresh()
	marker("game-fired")
	if not await wait_for(func(): return FileAccess.file_exists(OUTPUT+"/fire-observed.json"),"daemon fire cutoff"): quit(1); return
	game.session.new_batch()
	game.paused = false
	game.refresh()
	await create_timer(.6).timeout
	if not bridge.producer.latched: printerr("LIVE_BRIDGE_FAIL healthy batch cleared producer latch"); quit(1); return
	marker("healthy-after-fire-still-latched")
	bridge.stop()
	if not await wait_for(func(): return FileAccess.file_exists(OUTPUT+"/disconnect-observed.json"),"daemon disconnect cutoff"): quit(1); return
	print("LIVE_BRIDGE_GAME_RESULT "+JSON.stringify({"frames_sent":bridge.client.frames_sent,"operator_credential_hidden":true,"producer_latched_after_fire":bridge.producer.latched,"physical_operation":false}))
	quit(0)
