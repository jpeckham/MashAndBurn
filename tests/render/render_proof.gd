extends SceneTree
## Run only on a permitted hosted X11/Mesa runner. Uses real GUI hit testing, not button signals.
const OUTPUT := "res://.tools/render-proof"
var game: Node
var checks := 0
var failures := 0
var mouse := Vector2.ZERO
var captures: Array = []
var observations: Array = []
var profile: Dictionary = {}
var watermark: Label

func _initialize() -> void:
	call_deferred("run_proof")

func check(ok: bool, detail: String) -> bool:
	checks += 1
	observations.append({"ok":ok,"detail":detail})
	if not ok:
		failures += 1
		printerr("FAIL: "+detail)
	return ok

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func key(code: int, pressed: bool, ctrl: bool = false, unicode_value: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.ctrl_pressed = ctrl
	event.unicode = unicode_value
	Input.parse_input_event(event)

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text.begins_with(text): return node
	for child in node.get_children():
		var result := find_button(child,text)
		if result != null: return result
	return null

func click_control(control: Control) -> bool:
	if not check(control != null,"click target exists"): return false
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await frames()
	var point := control.get_global_rect().get_center()
	if not check(control.is_visible_in_tree() and Rect2(Vector2.ZERO,Vector2(root.size)).has_point(point),"click target is visible inside viewport: "+control.name): return false
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = point-mouse
	Input.parse_input_event(motion)
	mouse = point
	await frames(1)
	var hovered: Control = root.gui_get_hovered_control()
	var activations: Array = []
	var on_pressed := func(): activations.append(true)
	if control is Button: control.pressed.connect(on_pressed)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)
	await frames(2)
	if control is Button:
		control.pressed.disconnect(on_pressed)
		print("GUI_CLICK "+JSON.stringify({"text":control.text,"point":[point.x,point.y],"hovered":str(hovered.get_path()) if hovered != null else "none","target":str(control.get_path()),"disabled":control.disabled,"activations":activations.size(),"stage":game.session.state.stage,"message":game.session.message}))
		if not check(activations.size() == 1,"mouse activates button exactly once: "+control.text): return false
	return true

func click(text: String) -> bool:
	return await click_control(find_button(game,text))

func metrics_scroll(down: bool) -> void:
	if not await click_control(game.info_scroll): return
	for i in range(15):
		# Viewport retains mouse focus until each wheel button is released too.
		for pressed in [true,false]:
			var event := InputEventMouseButton.new()
			event.position = mouse
			event.global_position = mouse
			event.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
			event.pressed = pressed
			event.factor = 1.0
			Input.parse_input_event(event)
			await frames(1)
	check(game.info_scroll.get_global_rect().end.y < 620,"metrics stay above station controls")

func set_field(field: String, value: String) -> bool:
	var editor: SpinBox = game.settings[field]
	if not await click_control(editor.get_line_edit()): return false
	key(KEY_CTRL,true)
	key(KEY_A,true,true)
	key(KEY_A,false,true)
	key(KEY_CTRL,false)
	for character in value:
		var code: int = character.unicode_at(0)
		key(code,true,false,code)
		key(code,false)
		await frames(1)
	var apply: Button = editor.get_parent().get_child(editor.get_parent().get_child_count()-1)
	if not await click_control(apply): return false
	return check(is_equal_approx(game.session.state[field],float(value)),"GUI setting applied: "+field+"="+value)

func capture(name: String) -> void:
	watermark.text = "GITHUB-HOSTED INPUT PROOF  /  %s  /  %s" % [OS.get_environment("GITHUB_SHA").left(8),name]
	await frames()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var colors: Dictionary = {}
	for x in range(0,image.get_width(),57):
		for y in range(0,image.get_height(),43): colors[image.get_pixel(x,y).to_html()] = true
	check(image.get_size() == Vector2i(1366,740) and colors.size() > 20,"rendered nonblank 1366x740 frame: "+name)
	var path := OUTPUT+"/"+name+".png"
	check(image.save_png(path) == OK,"saved frame: "+name)
	var s: Dictionary = game.session.state
	captures.append({"file":name+".png","utc":Time.get_datetime_string_from_system(true),"stage":s.stage,"seed":s.seed,"tick":s.tick,"simulation_seconds":s.sim_seconds,"state_hash":game.session.sim.state_hash(s),"temperature_c":s.temp_c,"ph":s.ph,"gravity":s.gravity,"ibu":s.ibu,"co2_volumes":s.co2_volumes})
	print("CAPTURE "+JSON.stringify(captures.back()))

func next_stage(expected: String) -> bool:
	if not await click("Next stage"): return false
	return check(game.session.state.stage == expected,"GUI enters "+expected)

func batch(flawed: bool) -> bool:
	var prefix := "flawed" if flawed else "normal"
	if flawed:
		if not await set_field("target_c","95"): return false
		if not await click("+ 1 hour"): return false
		if not await set_field("target_c","66.7"): return false
	if not await click("+ 1 hour"): return false
	for i in range(3):
		if game.session.sim.can_next(game.session.state): break
		if not await click("+ 1 hour"): return false
	await capture(prefix+"-01-mash")
	if not flawed:
		if not await click("Resume"): return false
		var before: int = game.session.state.tick
		await create_timer(1.4).timeout
		if not await click("Pause"): return false
		check(game.session.state.tick > before and game.paused,"GUI resume/pause advances then stops time")
		before = game.session.state.tick
		await create_timer(.2).timeout
		check(game.session.state.tick == before,"paused time remains stopped")
		var saved: String = game.session.sim.state_hash(game.session.state)
		if not await click("Save batch"): return false
		if not await click("+ 1 hour"): return false
		check(game.session.sim.state_hash(game.session.state) != saved,"batch changed after save")
		if not await click("Load batch"): return false
		check(game.session.sim.state_hash(game.session.state) == saved and game.paused,"GUI reload restores exact mid-batch state")
		await capture("normal-02-reloaded")
		await metrics_scroll(true)
		await capture("normal-02b-metrics")
		await metrics_scroll(false)
	if not await next_stage("boil"): return false
	if not flawed:
		if not await click("Add (5% AA)"): return false
		check(game.session.state.hops.size() == 1,"GUI hop addition reaches simulation")
	if not await click("+ 1 hour"): return false
	await capture(prefix+"-03-boil")
	if not await next_stage("cooling"): return false
	if not await click("+ 1 hour"): return false
	await capture(prefix+"-04-cooling")
	if not await next_stage("fermentation"): return false
	if flawed and not await set_field("target_c","35"): return false
	var doses := 0
	while not game.session.sim.can_next(game.session.state) and doses < 40:
		if not await click("+ 4 hours"): return false
		doses += 1
		if doses == 6: await capture(prefix+"-05-fermentation")
	if not check(doses < 40,"fermentation becomes ready through GUI time controls"): return false
	if not await next_stage("packaging"): return false
	if flawed and not await set_field("priming_g","1000"): return false
	await capture(prefix+"-06-packaging")
	if not await click("Package & judge"): return false
	var judge = game.modules.filter(func(module): return module.get_script().resource_path == "res://src/social/judging_module.gd")[0]
	check(game.session.state.stage == "judging" and judge.panel.visible,"GUI packaging opens five-category judging")
	check(judge.current.categories.size() == 5 and not judge.current.feedback.is_empty(),"visible judging includes categories and causes")
	check(judge.feed_active if flawed else not judge.feed_active,"expected fictional feed boundary for "+prefix)
	await capture(prefix+"-07-judging-page-1")
	if flawed:
		if not await click("Next →"): return false
		check(judge.page_index == 1 and judge.rows.get_child_count() == 16,"GUI feed page two replaces rows")
		await capture("flawed-08-feed-page-2")
		for i in range(30):
			if not await click("Next →"): return false
		check(judge.page_index == 31 and judge.rows.get_child_count() == 16,"GUI final feed page remains bounded")
		await capture("flawed-09-feed-page-32")
		if not await click("Back to garage"): return false
		await metrics_scroll(true)
		await capture("flawed-10-defects-and-latch")
	return true

func run_proof() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	create_timer(330).timeout.connect(func(): printerr("FAIL: render proof watchdog expired"); finish(2))
	if not check(DisplayServer.get_name() != "headless","actual window/display driver required"):
		finish(1)
		return
	root.size = Vector2i(1366,740)
	game = load("res://scenes/garage/garage.tscn").instantiate()
	root.add_child(game)
	var layer := CanvasLayer.new()
	layer.layer = 20
	root.add_child(layer)
	watermark = Label.new()
	watermark.position = Vector2(345,717)
	watermark.add_theme_font_size_override("font_size",12)
	layer.add_child(watermark)
	await frames(6)
	profile = {"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),"display":DisplayServer.get_name()}
	var started := Time.get_ticks_msec()
	var rendered := Engine.get_frames_drawn()
	await frames(30)
	profile.measured_fps = float(Engine.get_frames_drawn()-rendered)*1000.0/maxi(1,Time.get_ticks_msec()-started)
	profile.frame_time_ms = 1000.0/maxf(.001,profile.measured_fps)
	check(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME) > 0,"3D geometry actually rendered")
	await capture("00-garage")
	if not await click("01  Mash"):
		finish(1)
		return
	var position: Vector3 = game.camera.position
	var right := InputEventMouseButton.new()
	right.position = Vector2(600,400)
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	Input.parse_input_event(right)
	var yaw: float = game.camera.rotation.y
	var look := InputEventMouseMotion.new()
	look.position = right.position
	look.global_position = right.position
	look.relative = Vector2(35,-8)
	Input.parse_input_event(look)
	await frames(1)
	check(absf(game.camera.rotation.y-yaw) > .01,"right-mouse motion changes camera look")
	key(KEY_W,true)
	await create_timer(.3).timeout
	key(KEY_W,false)
	right = right.duplicate() as InputEventMouseButton
	right.pressed = false
	Input.parse_input_event(right)
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	check(game.camera.position.distance_to(position) > .1,"actual input routing moves the garage camera")
	key(KEY_E,true)
	key(KEY_E,false)
	await frames()
	check(game.session.message.contains("not ready"),"E interaction reaches station readiness feedback")
	await capture("01-controls-and-readiness")
	if not await click("05  Packaging"):
		finish(1)
		return
	right.pressed = true
	Input.parse_input_event(right)
	await frames(2)
	look.relative = Vector2(-PI/.003,0)
	Input.parse_input_event(look)
	await frames(2)
	check(absf(absf(game.camera.rotation.y)-PI) < .05,"mouse-look turns toward the rear garage")
	right.pressed = false
	Input.parse_input_event(right)
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	await capture("02-buick-trunk-and-exit")
	if not await click("01  Mash"):
		finish(1)
		return
	if not await batch(false):
		finish(1)
		return
	if not await click("Back to garage") or not await click("New batch"):
		finish(1)
		return
	check(game.session.state.seed == 43,"second GUI batch advances seed reproducibly")
	if not await batch(true):
		finish(1)
		return
	finish(1 if failures else 0)

func finish(code: int) -> void:
	var report := {"source_commit":OS.get_environment("GITHUB_SHA"),"run_id":OS.get_environment("GITHUB_RUN_ID"),"machine":OS.get_environment("RUNNER_NAME"),"operator":"GitHub Actions / Godot Input.parse_input_event automation","utc":Time.get_datetime_string_from_system(true),"command":OS.get_cmdline_args(),"profile":profile,"checks":checks,"failures":failures,"exit_code":code,"captures":captures,"observations":observations}
	var file := FileAccess.open(OUTPUT+"/manifest.json",FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	print("RENDER_PROOF_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"exit_code":code,"captures":captures.size(),"profile":profile}))
	quit(code)
