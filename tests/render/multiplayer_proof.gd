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
var observed_replies := 0
var fire_smoke_only := false

func trace_reply() -> void:
	if network.reply_count == observed_replies: return
	observed_replies = network.reply_count
	if network.message != "Server accepted input.":
		print("PAIR_REJECT "+JSON.stringify({"message":network.message,"tick":network.view.get("tick",0),"stage":player().get("batch",{}).get("stage"),"safe":player().get("batch",{}).get("safe_state"),"queued":network.queued.size()}))

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
	if not await wait_until(func(): return player().cooldowns.get("brew",0.0) <= network.view.tick*.1,5,"packaging control cooldown clear"): return false
	if not await click("Package & judge"): return false
	if not await wait_until(func(): return game.session.state.stage == "judging",10,"GUI packaging accepted: "+network.message):
		print("PAIR_PACKAGE_FAILURE "+JSON.stringify({"message":network.message,"batch":player().batch,"pending":network.pending,"queued":network.queued}))
		return false
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

func look_at_point(point: Vector3) -> bool:
	await acquire_input()
	root.grab_focus()
	root.gui_release_focus()
	mouse_capture(true)
	await frames(2)
	var direction: Vector3 = point-game.camera.global_position
	var yaw := atan2(-direction.x,-direction.z)
	var pitch := clampf(atan2(direction.y,Vector2(direction.x,direction.z).length()),-1.3,.7)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(650,400)
	motion.relative = Vector2(wrapf(game.camera.rotation.y-yaw,-PI,PI)/.003,(game.camera.rotation.x-pitch)/.003)
	Input.parse_input_event(motion)
	await frames(2)
	mouse_capture(false)
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	release_input()
	return check(absf(wrapf(game.camera.rotation.y-yaw,-PI,PI)) < .06 and absf(game.camera.rotation.x-pitch) < .06,"actual mouse-look frames the observed world effect")

func host_combat() -> bool:
	if not fire_smoke_only and not await wait_until(func(): return network.view.players.size() == 2 and network.view.players.values().all(func(p): return p.batch.stage == "judging"),240,"both actual GUI recipes packaged"): return false
	if not await wait_until(func(): return phase_exists("guest","awaiting-wand"),30,"guest is observing the short wand effect"): return false
	if not await click("Lobby / combat / claims"): return false
	if not await click("Use weapon"): return false
	if not await wait_until(func(): return not network.view.spills.is_empty(),5,"wand creates server floor patch"): return false
	if not await click("Close"): return false
	var rival: Dictionary = network.view.players[2]
	if not await look_at_point(Vector3(rival.position[0],.04,rival.position[1])): return false
	await capture("host-08-wand-floor")
	if not await walk_to(Vector2(0,5.5)): return false
	signal_phase("at-exit")
	if not await wait_until(func(): return phase_exists("guest","escaped"),45,"guest staged and escaped through actual input"): return false
	if player().fire.phase == "staging" and not player().escaped: await interact()
	var origin: Array = network.view.players[2].fire.get("origin",network.view.players[2].position)
	if not await look_at_point(Vector3(origin[0],1.1,origin[1])): return false
	if not check(network.view.players[2].fire.phase == "staging","active fire window remains visible for the overview"): return false
	await capture("host-09-active-fire-overview")
	var deadline := Time.get_ticks_msec()+110000
	while Time.get_ticks_msec() < deadline:
		if player().fire.phase == "staging" and not player().escaped: await interact()
		if network.view.players.values().all(func(p): return p.fire.phase != "staging") and network.view.players[2].claim.resolved: break
		await create_timer(.1).timeout
	if not check(network.view.players[2].claim.resolved,"guest claim resolved before fixture clock advance"): return false
	await capture("host-09-fire-claims-settled")
	if not await wait_until(func(): return phase_exists("guest","claim-observed"),20,"guest recorded actual claim outcome"): return false
	if fire_smoke_only: return true
	var from_tick: int = network.state.tick
	network.set_physics_process(false)
	while network.state.phase == "running": network.state = network.authority.advance(network.state,.1).state
	network.publish()
	profile.fixture_clock_advance = {"from_tick":from_tick,"to_tick":network.state.tick,"reason":"both full recipes and fire windows already observed at production speed"}
	print("PAIR_HOST_ONLY_CLOCK_ADVANCE "+JSON.stringify(profile.fixture_clock_advance))
	return check(network.state.phase == "finished" and network.state.elapsed == 900,"host fixture finalizes the competitive 900-second clock")

func guest_fire() -> bool:
	signal_phase("awaiting-wand")
	if not await wait_until(func(): return player().blind_until > network.view.tick*.1,240,"actual host wand effect received"): return false
	await capture("guest-08-wand-blindness")
	if not await wait_until(func(): return phase_exists("host","at-exit"),30,"host reached exit before fire traversal"): return false
	if not await click("Lobby / combat / claims"): return false
	await acquire_input()
	if not await click_control(ui.causes): return false
	var popup: PopupMenu = ui.causes.get_popup()
	popup.grab_focus()
	await frames(2)
	var window_id: int = root.get_window_id() if popup.is_embedded() else popup.get_window_id()
	print("PAIR_POPUP "+JSON.stringify({"window":window_id,"embedded":popup.is_embedded(),"focus":popup.has_focus(),"item":popup.get_focused_item()}))
	# Opening by mouse can leave no item focused (-1). Navigate by actual keys
	# until the desired row is focused, then activate it; never assign selection.
	for i in range(3):
		if popup.get_focused_item() == 1: break
		key(KEY_DOWN,true,false,0,window_id)
		await frames(1)
		key(KEY_DOWN,false,false,0,window_id)
		await frames(1)
	if not check(popup.get_focused_item() == 1,"keyboard focuses fictional cord menu row"): return false
	key(KEY_ENTER,true,false,0,window_id)
	await frames(1)
	key(KEY_ENTER,false,false,0,window_id)
	await frames(2)
	release_input()
	if not check(ui.causes.selected == 1,"actual popup selects fictional cord incident"): return false
	if not await click("Fictional fire"): return false
	if not await wait_until(func(): return player().fire.phase == "staging",5,"actual fire command accepted"): return false
	signal_phase("fire-started")
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
	fire_smoke_only = "--fire-smoke-only" in args
	output_path = SHARED+"/"+role
	create_timer(840).timeout.connect(func(): printerr("FAIL: pair role watchdog expired"); finish(2))
	if role not in ["host","guest"] or not await setup_scene():
		finish(1)
		return
	profile.role = role
	profile.scenario = "fire-input-smoke-only; no recipe or final-clock proof" if fire_smoke_only else "full-brewing-fire-final"
	ui = game.get_node("Multiplayer")
	network = ui.network
	network.changed.connect(trace_reply)
	original_hash = game.session.sim.state_hash(game.session.state)
	if role == "guest" and not await wait_until(func(): return phase_exists("host","listening"),45,"host process is listening"): finish(1); return
	if not await click("Lobby / combat / claims"): finish(1); return
	if not await enter_text(ui.name_input,"Host" if role == "host" else "Guest"): finish(1); return
	if not await click("Host" if role == "host" else "Join"): finish(1); return
	if role == "host": signal_phase("listening")
	if not await wait_until(func(): return network.player_id > 0 and network.session_connected,15,"real GUI participant joined"): finish(1); return
	connected_once = true
	if role == "guest" and not fire_smoke_only:
		if not await click("Close") or not await set_field("target_c","95") or not await click("Lobby / combat / claims"): finish(1); return
	if not await click("Toggle ready"): finish(1); return
	if role == "host":
		if not await wait_until(func(): return network.view.players.size() == 2 and network.view.players.values().all(func(p): return p.ready),30,"both participants ready through GUI"): finish(1); return
		if not await click("Start (host)"): finish(1); return
	if not await wait_until(func(): return network.view.get("phase") == "running",10,"GUI round started"): finish(1); return
	if OS.get_environment("PAIR_BRIDGE_ENABLED") == "true":
		var bridge = game.get_node("HardwareBridge")
		if not check(OS.get_environment("MAB_OPERATOR_TOKEN").is_empty(),"game has no operator credential"): finish(1); return
		if not check(bridge.start(),"explicit fixture opt-in starts local mock telemetry"): finish(1); return
		if not await wait_until(func(): return FileAccess.file_exists(SHARED+"/bridge-"+role+"-armed.json"),25,"separate mock operator armed after healthy game frames"): finish(1); return
	if not await click("Close"): finish(1); return
	if not fire_smoke_only and not await brew(): finish(1); return
	var played := false
	if role == "host": played = await host_combat()
	else: played = await guest_fire()
	if not played: finish(1); return
	if fire_smoke_only:
		if role == "host" and not await wait_until(func(): return phase_exists("guest","complete"),30,"guest smoke scenario completed"): finish(1); return
		if not await click("Lobby / combat / claims") or not await click("Leave"): finish(1); return
		connected_once = false
		check(game.session.sim.state_hash(game.session.state) == original_hash,"fire smoke GUI leave restores local batch")
		signal_phase("complete")
		finish(1 if failures else 0)
		return
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
