extends Node3D
## Presentation-only geometry and UI. Modules register through project setting mash_burn/modules.
const Session = preload("res://src/presentation/brew_session.gd")
var session := Session.new()
var camera: Camera3D
var status: Label
var notice: Label
var instruction: Label
var next_button: Button
var pause_button: Button
var module_slot: VBoxContainer
var controls: VBoxContainer
var modules: Array = []
var station_nodes: Array = []
var paused := true
var speed := 60.0
var accumulated := 0.0
var look_pitch := -0.12
var settings: Dictionary = {}
var settings_dirty: Dictionary = {}
var stage_buttons: Array = []
var batch_label: Label
const STAGES = ["mash","boil","cooling","fermentation","packaging"]
const COLORS = [Color("e9b660"),Color("f28b59"),Color("62c5d9"),Color("a7bc7d"),Color("b8a1d6")]

func _ready() -> void:
	build_world()
	build_ui()
	for path in ProjectSettings.get_setting("mash_burn/modules", []):
		var script = load(path)
		if script: register_module(script.new())
	refresh()

func register_module(module: Node) -> void:
	modules.append(module)
	add_child(module)
	if module.has_method("setup"): module.setup(self)

func box(pos: Vector3, size: Vector3, color: Color, metal: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = .35 if metal > 0 else .85
	node.material_override = material
	add_child(node)
	return node

func cylinder(pos: Vector3, radius: float, height: float, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = .65
	mat.roughness = .26
	node.material_override = mat
	add_child(node)

func sign3d(text: String, pos: Vector3, color: Color, size: int = 40) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.position = pos
	node.font_size = size
	node.pixel_size = .006
	node.modulate = color
	add_child(node)
	return node

func build_world() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("19272e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b0c8d1")
	env.ambient_light_energy = .65
	env_node.environment = env
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-30,0)
	sun.light_energy = 1.2
	add_child(sun)
	box(Vector3(0,-.15,0),Vector3(14,.3,14),Color("41494a"))
	box(Vector3(0,2.5,-4),Vector3(14,5,.2),Color("283a40"))
	box(Vector3(-7,2.5,0),Vector3(.2,5,8),Color("34474b"))
	box(Vector3(7,2.5,0),Vector3(.2,5,8),Color("34474b"))
	for x in range(-6,7):
		box(Vector3(x,.012,0),Vector3(.025,.02,12),Color("54605e"))
	for z in range(-5,7):
		box(Vector3(0,.012,z),Vector3(14,.02,.025),Color("54605e"))
	for i in range(5):
		var x: float = (i-2)*2.25
		box(Vector3(x,.45,-2.5),Vector3(1.9,.9,1.2),Color("17282f"))
		box(Vector3(x,.95,-2.5),Vector3(2,.12,1.4),Color("90a4a7"),.7)
		box(Vector3(x,1.05,-1.78),Vector3(1.8,.05,.04),COLORS[i])
		cylinder(Vector3(x,1.55,-2.5),.48,1.05,Color("a3b5ba"))
		cylinder(Vector3(x,2.10,-2.5),.51,.08,Color("586f77"))
		cylinder(Vector3(x,2.18,-2.5),.09,.1,COLORS[i])
		box(Vector3(x+.53,1.35,-2.4),Vector3(.18,.1,.16),COLORS[i],.4)
		station_nodes.append(sign3d("%02d  %s" % [i+1,STAGES[i].to_upper()],Vector3(x,2.65,-2.6),COLORS[i],30))
		box(Vector3(x,3.25,-3.85),Vector3(1.7,.06,.08),COLORS[i])
		var light := OmniLight3D.new()
		light.position = Vector3(x,3,-1.7)
		light.light_color = COLORS[i]
		light.light_energy = .7
		light.omni_range = 4
		add_child(light)
	# Distinct chiller coil, fermenter airlock, and packaging bottles.
	for j in range(6): cylinder(Vector3(.65,1.3+j*.12,-2.5),.16,.05,Color("cf9264"))
	box(Vector3(2.25,2.45,-2.5),Vector3(.06,.5,.06),Color("a7bc7d"))
	for j in range(4): cylinder(Vector3(4.0+j*.25,1.23,-1.95),.075,.45,Color("73512c"))
	sign3d("MASH & BURN  /  GARAGE 01",Vector3(0,4.15,-3.85),Color("ecdfbb"),52)
	sign3d("SMALL BATCHES. BIG CONSEQUENCES.",Vector3(0,3.65,-3.85),Color("8aa2a5"),25)
	camera = Camera3D.new()
	camera.position = Vector3(0,2.35,5.8)
	camera.rotation.x = look_pitch
	camera.fov = 75
	add_child(camera)
	camera.current = true

func panel(parent: Node, pos: Vector2, size: Vector2) -> VBoxContainer:
	var bg := PanelContainer.new()
	bg.position = pos
	bg.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.04,.08,.10,.94)
	style.border_color = Color("3c5359")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	bg.add_theme_stylebox_override("panel",style)
	parent.add_child(bg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",8)
	bg.add_child(v)
	return v

func label(text: String, parent: Node, size: int = 16, color: Color = Color("d9e4df")) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color)
	parent.add_child(node)
	return node

func button(text: String, parent: Node, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 34
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func row(parent: Node) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation",8)
	parent.add_child(r)
	return r

func field(title: String, key: String, lo: float, hi: float, value: float, step_value: float = 1.0) -> void:
	var r := row(controls)
	var l := label(title,r,14)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var input := SpinBox.new()
	input.min_value = lo
	input.max_value = hi
	input.step = step_value
	input.value = value
	input.custom_minimum_size.x = 112
	r.add_child(input)
	settings[key] = input
	input.value_changed.connect(func(_value): settings_dirty[key] = true)
	button("Set",r,func():
		input.apply()
		if session.route("set",{"field":key,"value":input.value}): settings_dirty.erase(key)
		refresh())

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	label("MASH & BURN",root,30,Color("f0c36f")).position = Vector2(24,16)
	label("GARAGE 01     /     LOCAL BREW LAB",root,13,Color("aec4c8")).position = Vector2(26,56)
	var info := panel(root,Vector2(24,91),Vector2(300,470))
	batch_label = label("LIVE BATCH",info,16,Color("f0c36f"))
	status = label("",info,15)
	status.custom_minimum_size.x = 268
	label("MODEL: GAME APPROXIMATIONS",info,11,Color("9db1b2"))
	var right := PanelContainer.new()
	right.position = Vector2(950,20)
	right.size = Vector2(390,690)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.04,.08,.10,.96)
	style.set_corner_radius_all(10)
	right.add_theme_stylebox_override("panel",style)
	root.add_child(right)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	right.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	controls = VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation",8)
	scroll.add_child(controls)
	label("BREW DESK",controls,23,Color("f0c36f"))
	instruction = label("",controls,14)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.custom_minimum_size.x = 335
	next_button = button("Next stage",controls,advance_stage)
	var time_row := row(controls)
	pause_button = button("Resume",time_row,func(): paused = not paused; refresh())
	button("+ 1 hour",time_row,func(): session.step(60); refresh())
	button("+ 4 hours",time_row,func(): session.step(240); refresh())
	var speed_row := row(controls)
	label("Speed",speed_row,14)
	var speeds := OptionButton.new()
	for text in ["1x real time","60x","3,600x","86,400x"]: speeds.add_item(text)
	speeds.select(1)
	speed_row.add_child(speeds)
	speeds.item_selected.connect(func(i): speed = [1.0,60.0,3600.0,86400.0][i])
	label("RECIPE & STATION SETTINGS",controls,13,Color("a3bfc2"))
	field("Water  / L","volume_l",.1,100,20,.1)
	field("Grain  / kg","grain_kg",0,20,5,.1)
	field("Target  / C","target_c",0,100,66.7,.1)
	field("Boil vigor","vigor",0,1,1,.05)
	field("Chiller flow","chiller",0,1,1,.05)
	var hops := row(controls)
	label("Hops  / g",hops,14)
	var hop_g := SpinBox.new()
	hop_g.max_value = 500
	hop_g.value = 30
	hops.add_child(hop_g)
	button("Add (5% AA)",hops,func(): session.route("add_hops",{"grams":hop_g.value,"alpha":.05}); refresh())
	field("Prime  / g","priming_g",0,1000,120,5)
	field("Regulator / psi","regulator_psi",0,60,0,1)
	var saves := row(controls)
	button("Save batch",saves,func(): session.save_to(); refresh())
	button("Load batch",saves,func():
		if session.load_from(): settings_dirty.clear()
		paused = true
		refresh())
	button("New batch",saves,func(): session.new_batch(); settings_dirty.clear(); paused = true; accumulated = 0; refresh())
	notice = label("",controls,13,Color("f0c36f"))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	module_slot = VBoxContainer.new()
	controls.add_child(module_slot)
	var bottom := panel(root,Vector2(24,620),Vector2(900,90))
	var stations := row(bottom)
	for i in range(5):
		var index := i
		var b := button("%02d  %s" % [i+1,STAGES[i].capitalize()],stations,func(): visit_station(index))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stage_buttons.append(b)
	label("WASD walk  ·  Hold right mouse to look  ·  E interact  ·  Esc releases mouse",bottom,13,Color("aec4c8"))

func advance_stage() -> void:
	if session.route("next"):
		var index := STAGES.find(session.state.stage)
		if index >= 0: visit_station(index)
	refresh()

func visit_station(index: int) -> void:
	camera.position = Vector3((index-2)*2.25,1.9,.8)
	camera.rotation = Vector3(-.1,0,0)
	look_pitch = -.1
	session.message = "At %s. %s" % [STAGES[index].capitalize(),session.instructions()]
	refresh()

func refresh() -> void:
	var s := session.state
	batch_label.text = "LIVE BATCH  /  SEED %d" % s.seed
	var flaws := ""
	for k in s.flaws:
		if s.flaws[k] > .01: flaws += "%s %.2f\n" % [k.capitalize(),s.flaws[k]]
	status.text = ("%s   ·   TICK %d\nStage time   %.1f h\nBatch time   %.1f h\n\nTemperature   %.1f C / %.1f F\npH   %.2f   [target 5.2–5.6]\nWater   %.2f L\nCa %.0f · Mg %.0f mg/L\nSO4 %.0f · Cl %.0f · HCO3 %.0f\nIon balance   %+.2f mEq/L\n\nConversion   %.1f%%\nGravity   %.4f / OG %.4f\nBitterness   %.1f IBU\nHop oils   %.2f g equivalent\nYeast progress   %.1f%%\nFlocculation   %.1f%%\nInfection risk   %.2f%%\nCO2   %.2f vol / %.1f psi\n\n%s" % [s.stage.to_upper(),s.tick,s.stage_seconds/3600,s.sim_seconds/3600,s.temp_c,session.sim.c_to_f(s.temp_c),s.ph,s.volume_l,s.ions.Ca,s.ions.Mg,s.ions.SO4,s.ions.Cl,s.ions.HCO3,session.sim.ion_balance(s.ions),s.conversion*100,s.gravity,s.og,s.ibu,s.hop_oils,s.attenuation*100,s.flocculation*100,s.infection_risk*100,s.co2_volumes,s.pressure_psi,"Flaws: none detected" if flaws.is_empty() else flaws])
	instruction.text = session.instructions()
	notice.text = ("SAFETY LATCH: outputs disabled. Start a new batch.\n" if s.safe_state else "") + session.message
	next_button.text = "Package & judge" if s.stage == "packaging" else "Next stage →"
	next_button.disabled = not session.sim.can_next(s)
	pause_button.text = "Resume" if paused else "Pause"
	for key in settings:
		if not settings_dirty.get(key,false) and not settings[key].get_line_edit().has_focus(): settings[key].set_value_no_signal(s[key])
	for i in range(5):
		stage_buttons[i].modulate = COLORS[i] if s.stage == STAGES[i] else Color.WHITE
	for module in modules:
		if module.has_method("on_state"): module.on_state(s)

func _process(delta: float) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var move := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		move = move.rotated(Vector3.UP,camera.rotation.y)
		camera.position += move.normalized()*delta*3
		camera.position.x = clampf(camera.position.x,-6.5,6.5)
		camera.position.z = clampf(camera.position.z,-.5,6)
	if paused: return
	accumulated += delta*speed
	var ticks := mini(240,int(accumulated/60))
	if ticks > 0:
		accumulated -= ticks*60
		session.step(ticks)
		refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera.rotation.y -= event.relative.x*.003
		look_pitch = clampf(look_pitch-event.relative.y*.003,-1.2,1.2)
		camera.rotation.x = look_pitch
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if event.keycode == KEY_E:
			var index := STAGES.find(session.state.stage)
			if index >= 0 and camera.position.distance_to(Vector3((index-2)*2.25,1.9,-2.5)) < 4:
				advance_stage()
			else:
				session.message = "Walk to the active station or use its numbered visit button."
				refresh()
