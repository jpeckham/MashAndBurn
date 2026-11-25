extends "res://tests/render/render_proof.gd"
## Two real GUI processes. Coordination files synchronize fixtures, never gameplay state.
const SHARED := "res://.tools/multiplayer-proof"
var role := "unknown"
var ui: Node
var network: Node
var connected_once := false
var original_hash := ""
var walking_keys: Dictionary = {}
var input_lock_depth := 0

func acquire_input() -> void:
	if input_lock_depth == 0:
		while DirAccess.make_dir_absolute(ProjectSettings.globalize_path(SHARED+"/input-lock")) != OK:
			await create_timer(.05).timeout
	input_lock_depth += 1

func release_input() -> void:
	input_lock_depth -= 1
	if input_lock_depth == 0: DirAccess.remove_absolute(ProjectSettings.globalize_path(SHARED+"/input-lock"))

func click_control(control: Control) -> bool:
	await acquire_input()
	var accepted := await super.click_control(control)
	release_input()
	return accepted

func enter_text(editor: LineEdit, value: String) -> bool:
	await acquire_input()
	var accepted := await super.enter_text(editor,value)
	if accepted: accepted = check(editor.text == value,"keyboard draft matches requested text: "+value)
	release_input()
	return accepted

func player() -> Dictionary:
	return network.view.get("players",{}).get(network.player_id,{})

func wait_until(predicate: Callable, seconds: float, detail: String) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return check(true,detail)
		if connected_once and not network.session_connected: return check(false,"connection lost while "+detail)
		await create_timer(.1).timeout
	return check(false,"timeout: "+detail)

func signal_phase(phase: String) -> void:
	var file := FileAccess.open(SHARED+"/"+role+"-"+phase+".json",FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"role":role,"phase":phase,"utc":Time.get_datetime_string_from_system(true),"tick":network.view.get("tick",0)}))
		file.close()
	print("PAIR_PHASE role=%s phase=%s tick=%s" % [role,phase,network.view.get("tick",0)])

func phase_exists(actor: String, phase: String) -> bool:
	return FileAccess.file_exists(SHARED+"/"+actor+"-"+phase+".json")

func set_field(field: String, value: String) -> bool:
	if not await wait_until(func(): return player().get("cooldowns",{}).get("brew",0.0) <= network.view.tick*.1,5,"brewing control cooldown clear"): return false
	var editor: SpinBox = game.settings[field]
	await acquire_input()
	if not await enter_text(editor.get_line_edit(),value):
		release_input()
		return false
	var apply: Button = editor.get_parent().get_child(editor.get_parent().get_child_count()-1)
	var accepted := await click_control(apply)
	print("PAIR_FIELD "+JSON.stringify({"field":field,"requested":value,"widget":editor.value,"draft":editor.get_line_edit().text,"tick":network.view.tick}))
	release_input()
	if not accepted: return false
	return await wait_until(func(): return is_equal_approx(game.session.state[field],float(value)),5,"authoritative GUI field "+field+"="+value)

func next_stage(expected: String) -> bool:
	if not await wait_until(func(): return game.session.sim.can_next(game.session.state),40,"stage ready for "+expected): return false
	if not await click("Next stage"): return false
	return await wait_until(func(): return game.session.state.stage == expected,5,"authoritative GUI enters "+expected)

func brew() -> bool:
	if role == "guest":
		if not await wait_until(func(): return game.session.state.stage_seconds >= 3600,20,"one scorched mash hour observed"): return false
		if not await set_field("target_c","66.7"): return false
	if not await wait_until(func(): return game.session.sim.can_next(game.session.state),40,"mash readiness observed"): return false
	await capture(role+"-01-mash")
	if not await next_stage("boil"): return false
	if role == "host":
		if not await wait_until(func(): return player().cooldowns.get("brew",0.0) <= network.view.tick*.1,5,"hop control cooldown clear"): return false
		if not await click("Add (5% AA)"): return false
		if not await wait_until(func(): return game.session.state.hops.size() == 1,5,"GUI hop charge accepted"): return false
	if not await wait_until(func(): return game.session.sim.can_next(game.session.state),30,"boil readiness observed"): return false
	await capture(role+"-02-boil")
	if not await next_stage("cooling"): return false
	if not await wait_until(func(): return game.session.sim.can_next(game.session.state),30,"cooling readiness observed"): return false
	await capture(role+"-03-cooling")
	if not await next_stage("fermentation"): return false
	if role == "guest" and not await set_field("target_c","30"): return false
	await capture(role+"-04-fermentation-start")
	await create_timer(120).timeout
	await capture(role+"-05-fermentation-progress")
	if not await wait_until(func(): return game.session.sim.can_next(game.session.state),300,"full fermentation readiness observed"): return false
	if not await next_stage("packaging"): return false
	if role == "guest" and not await set_field("priming_g","1000"): return false
	await capture(role+"-06-packaging")
	if not await click("Package & judge"): return false
	if not await wait_until(func(): return game.session.state.stage == "judging",5,"GUI packaging accepted"): return false
	var tasting = game.modules.filter(func(module): return module.get_script().resource_path == "res://src/social/judging_module.gd")[0]
	check(not tasting.panel.visible,"packaged batch waits for authoritative round judging")
	await capture(role+"-07-packaged-awaiting-final")
	signal_phase("packaged")
	return true

func mouse_capture(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = Vector2(650,400)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_RIGHT
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)

func stop_walking() -> void:
	for code in [KEY_W,KEY_A,KEY_S,KEY_D]: key(code,false)
	walking_keys.clear()
	mouse_capture(false)
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)

func walk_to(point: Vector2) -> bool:
	await acquire_input()
	var reached := await walk_with_focus(point)
	release_input()
	return reached

func walk_with_focus(point: Vector2) -> bool:
	root.grab_focus()
	if ui.panel.visible and not await click("Close"): return false
	root.gui_release_focus()
	mouse_capture(true)
	await frames(2)
	var deadline := Time.get_ticks_msec()+15000
	while Time.get_ticks_msec() < deadline:
		var p: Dictionary = player()
		if p.is_empty() or p.health <= 0:
			stop_walking()
			return check(false,"living authoritative player required for traversal")
		var delta2 := point-Vector2(p.position[0],p.position[1])
		if delta2.length() <= .6:
			stop_walking()
			await frames(2)
			return check(Vector2(player().position[0],player().position[1]).distance_to(point) <= 1.2,"WASD reached world point "+str(point))
		var local := Vector3(delta2.x,0,delta2.y).normalized().rotated(Vector3.UP,-game.camera.rotation.y)
		var wanted := {KEY_A:local.x < -.2,KEY_D:local.x > .2,KEY_W:local.z < -.2,KEY_S:local.z > .2}
		for code in wanted:
			if walking_keys.get(code,false) != wanted[code]: key(code,wanted[code])
		walking_keys = wanted
		await create_timer(.08).timeout
	stop_walking()
	return check(false,"WASD traversal timed out: "+str(point))

func interact() -> void:
	await acquire_input()
	root.grab_focus()
	root.gui_release_focus()
	key(KEY_E,true)
	key(KEY_E,false)
	await frames(2)
	release_input()

func host_combat() -> bool:
	if not await wait_until(func(): return network.view.players.size() == 2 and network.view.players.values().all(func(p): return p.batch.stage == "judging"),240,"both actual GUI recipes packaged"): return false
	if not await click("Lobby / combat / claims"): return false
	if not await click("Use weapon"): return false
	if not await wait_until(func(): return not network.view.spills.is_empty(),5,"wand creates server floor patch"): return false
	if not await click("Close"): return false
	await capture("host-08-wand-floor")
	if not await walk_to(Vector2(0,5.5)): return false
	signal_phase("at-exit")
	if not await wait_until(func(): return phase_exists("guest","escaped"),45,"guest staged and escaped through actual input"): return false
	var deadline := Time.get_ticks_msec()+110000
	while Time.get_ticks_msec() < deadline:
		if player().fire.phase == "staging" and not player().escaped: await interact()
		if network.view.players.values().all(func(p): return p.fire.phase != "staging") and network.view.players[2].claim.resolved: break
		await create_timer(.1).timeout
	if not check(network.view.players[2].claim.resolved,"guest claim resolved before fixture clock advance"): return false
	await capture("host-09-fire-claims-settled")
	if not await wait_until(func(): return phase_exists("guest","claim-observed"),20,"guest recorded actual claim outcome"): return false
	var from_tick: int = network.state.tick
	network.set_physics_process(false)
	while network.state.phase == "running": network.state = network.authority.advance(network.state,.1).state
	network.publish()
	profile.fixture_clock_advance = {"from_tick":from_tick,"to_tick":network.state.tick,"reason":"both full recipes and fire windows already observed at production speed"}
	print("PAIR_HOST_ONLY_CLOCK_ADVANCE "+JSON.stringify(profile.fixture_clock_advance))
	return check(network.state.phase == "finished" and network.state.elapsed == 900,"host fixture finalizes the competitive 900-second clock")

func guest_fire() -> bool:
	if not await wait_until(func(): return player().blind_until > network.view.tick*.1,240,"actual host wand effect received"): return false
	await capture("guest-08-wand-blindness")
	if not await wait_until(func(): return phase_exists("host","at-exit"),30,"host reached exit before fire traversal"): return false
	if not await click("Lobby / combat / claims"): return false
	await acquire_input()
	if not await click_control(ui.causes): return false
	key(KEY_DOWN,true)
	key(KEY_DOWN,false)
	key(KEY_ENTER,true)
	key(KEY_ENTER,false)
	await frames(2)
	release_input()
	if not check(ui.causes.selected == 1,"actual popup selects fictional cord incident"): return false
	if not await click("Fictional fire"): return false
	if not await wait_until(func(): return player().fire.phase == "staging",5,"actual fire command accepted"): return false
	if not await click("Close"): return false
	await capture("guest-09-fire-window")
	for object in ["receipt","evidence","equipment"]:
		var point: Array = ui.Fire.STAGING_POINTS[object]
		if not await walk_to(Vector2(point[0],point[1])): return false
		await interact()
		if not await wait_until(func(): return player().fire.objects[object],3,"E stages "+object+" at its actual prop"): return false
		await capture("guest-10-stage-"+object)
	await interact()
	if not await wait_until(func(): return player().escaped,3,"E escapes at actual exit"): return false
	await capture("guest-11-escaped")
	signal_phase("escaped")
	if not await wait_until(func(): return player().claim.resolved,60,"full actual fire window resolves"): return false
	check(player().claim.passed and player().claim.payout == 1500,"actual staged/escaped claim pays 150 percent once")
	if not await click("Lobby / combat / claims"): return false
	await capture("guest-12-claim-outcome")
	if not await click("Close"): return false
	signal_phase("claim-observed")
	return true

func run_proof() -> void:
	var args := OS.get_cmdline_user_args()
	if "--role" in args: role = args[args.find("--role")+1]
	output_path = SHARED+"/"+role
	create_timer(840).timeout.connect(func(): printerr("FAIL: pair role watchdog expired"); finish(2))
	if role not in ["host","guest"] or not await setup_scene():
		finish(1)
		return
	profile.role = role
	ui = game.get_node("Multiplayer")
	network = ui.network
	original_hash = game.session.sim.state_hash(game.session.state)
	if role == "guest" and not await wait_until(func(): return phase_exists("host","listening"),45,"host process is listening"): finish(1); return
	if not await click("Lobby / combat / claims"): finish(1); return
	if not await enter_text(ui.name_input,"Host" if role == "host" else "Guest"): finish(1); return
	if not await click("Host" if role == "host" else "Join"): finish(1); return
	if role == "host": signal_phase("listening")
	if not await wait_until(func(): return network.player_id > 0 and network.session_connected,15,"real GUI participant joined"): finish(1); return
	connected_once = true
	if role == "guest":
		if not await click("Close") or not await set_field("target_c","95") or not await click("Lobby / combat / claims"): finish(1); return
	if not await click("Toggle ready"): finish(1); return
	if role == "host":
		if not await wait_until(func(): return network.view.players.size() == 2 and network.view.players.values().all(func(p): return p.ready),30,"both participants ready through GUI"): finish(1); return
		if not await click("Start (host)"): finish(1); return
	if not await wait_until(func(): return network.view.get("phase") == "running",10,"GUI round started"): finish(1); return
	if not await click("Close"): finish(1); return
	if not await brew(): finish(1); return
	var played := false
	if role == "host": played = await host_combat()
	else: played = await guest_fire()
	if not played: finish(1); return
	if not await wait_until(func(): return network.view.get("phase") == "finished",60,"both windows receive authoritative final results"): finish(1); return
	await capture(role+"-13-final-tasting")
	var tasting = game.modules.filter(func(module): return module.get_script().resource_path == "res://src/social/judging_module.gd")[0]
	check(tasting.panel.visible and tasting.feed_active == (role == "guest"),"actual final normal/flawed feed boundary")
	if role == "guest":
		if not await click("Next →"): finish(1); return
		await capture("guest-14-feed-page-2")
		for i in range(30):
			if not await click("Next →"): finish(1); return
		check(tasting.page_index == 31 and tasting.rows.get_child_count() == 16,"actual multiplayer feed reaches bounded page32")
		await capture("guest-15-feed-page-32")
	if role == "host":
		if not await wait_until(func(): return phase_exists("guest","complete"),45,"guest completed before host leave"): finish(1); return
	if not await click("Back to garage") or not await click("Lobby / combat / claims") or not await click("Leave"): finish(1); return
	connected_once = false
	check(game.session.sim.state_hash(game.session.state) == original_hash,"actual GUI leave restores original local batch")
	signal_phase("complete")
	finish(1 if failures else 0)
