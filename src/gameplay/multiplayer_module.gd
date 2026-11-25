extends Node
## Garage extension: ENet lobby, authoritative brew desk, combat/claims HUD and world cues.
const Network = preload("res://src/gameplay/network/match_network.gd")
const RemoteSession = preload("res://src/gameplay/network/remote_brew_session.gd")
var garage: Node
var network: Node
var original_session
var remote_session
var remote_mode := false
var panel: PanelContainer
var summary: Label
var scoreboard: Label
var status_line: Label
var notice: Label
var name_input: LineEdit
var address: LineEdit
var port: SpinBox
var targets: OptionButton
var weapons: OptionButton
var styles: OptionButton
var causes: OptionButton
var veil: ColorRect
var markers: Dictionary = {}
var projectiles: Dictionary = {}
var fires: Dictionary = {}
var movement_timer := 0.0
const WEAPONS = ["wand","ladle","hydrometer","keg","bottle"]
const STYLES = ["pale_ale","lager","stout"]
const CAUSES = ["boil_over","cord","dust"]

func _init() -> void:
	name = "Multiplayer"

func setup(host: Node) -> void:
	garage = host
	network = Network.new()
	network.name = "MatchNetwork"
	add_child(network)
	garage.button("Multiplayer lobby / match",garage.module_slot,func(): panel.visible = not panel.visible)
	build_ui()
	network.changed.connect(sync)
	garage.box(Vector3(0,.02,5.7),Vector3(10,.03,.35),Color("32764b"))
	garage.sign3d("EXIT  /  ESCAPE FROM SMOKE",Vector3(0,2.7,6),Color("b2f4c1"),28)
	sync()

func build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	veil = ColorRect.new()
	veil.position = Vector2(330,90)
	veil.size = Vector2(610,515)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.color = Color(0,0,0,0)
	root.add_child(veil)
	status_line = garage.label("",root,14,Color("f0c36f"))
	status_line.position = Vector2(350,18)
	var toggle: Button = garage.button("Lobby / combat / claims",root,func(): panel.visible = not panel.visible)
	toggle.position = Vector2(350,53)
	panel = PanelContainer.new()
	panel.position = Vector2(335,100)
	panel.size = Vector2(600,500)
	panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101e27")
	style.border_color = Color("ceac67")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	for side in ["left","right","top","bottom"]: style.set("content_margin_"+side,14)
	panel.add_theme_stylebox_override("panel",style)
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560,465)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation",8)
	scroll.add_child(controls)
	var title: HBoxContainer = garage.row(controls)
	garage.label("BREWERY DEATHMATCH",title,22,Color("f0c36f")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	garage.button("Close",title,func(): panel.visible = false)
	garage.label("2–8 brewers · 15-minute server clock · fictional game effects",controls,13)
	name_input = LineEdit.new()
	name_input.text = "Brewer"
	name_input.max_length = 32
	name_input.placeholder_text = "Your brewer name"
	controls.add_child(name_input)
	var connection: HBoxContainer = garage.row(controls)
	address = LineEdit.new()
	address.text = "127.0.0.1"
	address.placeholder_text = "Host IP address"
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connection.add_child(address)
	port = SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.step = 1
	port.value = 27841
	connection.add_child(port)
	var lobby: HBoxContainer = garage.row(controls)
	garage.button("Host",lobby,func(): network.host(int(port.value),name_input.text))
	garage.button("Join",lobby,func(): connect_match(false))
	garage.button("Reconnect",lobby,func(): connect_match(true))
	garage.button("Leave",lobby,leave)
	var ready: HBoxContainer = garage.row(controls)
	garage.button("Toggle ready",ready,func():
		if network.view.get("players",{}).has(network.player_id): network.send("ready",{"ready":not network.view.players[network.player_id].ready}))
	styles = OptionButton.new()
	for style_name in STYLES: styles.add_item(style_name.capitalize())
	ready.add_child(styles)
	garage.button("Start (host)",ready,func(): network.start_round(STYLES[styles.selected]))
	notice = garage.label("",controls,13,Color("f0c36f"))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.x = 550
	summary = garage.label("",controls,14)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	garage.label("Use the Brew Desk for your own batch. Server speed: 600x.\nClose this panel, hold right mouse and WASD to approach rivals.",controls,13)
	var equipment: HBoxContainer = garage.row(controls)
	targets = OptionButton.new()
	targets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment.add_child(targets)
	weapons = OptionButton.new()
	for weapon in WEAPONS: weapons.add_item(weapon.capitalize())
	equipment.add_child(weapons)
	garage.button("Use weapon",equipment,func(): network.send("attack",{"weapon":WEAPONS[weapons.selected],"target":targets.get_selected_id()}))
	var sabotage: HBoxContainer = garage.row(controls)
	for kind in ["chiller","contamination","burner"]:
		var selected: String = kind
		garage.button("Sabotage " + kind,sabotage,func(): network.send("sabotage",{"kind":selected,"target":targets.get_selected_id()}))
	var ignition: HBoxContainer = garage.row(controls)
	causes = OptionButton.new()
	for cause in ["Boil-over incident","Cord incident","Grain-dust incident"]: causes.add_item(cause)
	ignition.add_child(causes)
	garage.button("Fictional fire",ignition,func(): network.send("ignite",{"cause":CAUSES[causes.selected]}))
	var staging: HBoxContainer = garage.row(controls)
	for object in ["receipt","equipment","evidence"]:
		var selected: String = object
		garage.button("Stage " + object,staging,func(): network.send("stage",{"object":selected}))
	garage.button("Escape (reach green exit first)",controls,func(): network.send("escape"))
	garage.label("Fire disarms telemetry immediately. Stage fictional objects during 45 seconds,\nthen escape smoke. Server inspection grants 150% replacement or a penalty.",controls,12)
	scoreboard = garage.label("",controls,13)
	scoreboard.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scoreboard.custom_minimum_size.x = 550

func connect_match(resume: bool) -> void:
	var error: Error = network.connect_to(address.text,int(port.value),name_input.text,resume)
	if error != OK: notice.text = "Invalid address/port or connection setup failed (%d)." % error

func leave() -> void:
	network.shutdown()
	if remote_mode:
		garage.session = original_session
		remote_mode = false
		garage.paused = true
		garage.accumulated = 0.0
		garage.refresh()
	for collection in [markers,projectiles,fires]:
		for object in collection.values(): object.queue_free()
		collection.clear()
	status_line.text = ""
	veil.color = Color(0,0,0,0)
	notice.text = "Offline. Your local batch is restored."
	scoreboard.text = ""
	summary.text = ""

func sync() -> void:
	notice.text = network.message
	var view: Dictionary = network.view
	if view.is_empty(): return
	if view.players.has(network.player_id):
		if not remote_mode:
			original_session = garage.session
			remote_session = RemoteSession.new()
			remote_session.configure(network)
			garage.session = remote_session
			remote_mode = true
		remote_session.apply_snapshot(view,network.player_id)
		garage.paused = true
		garage.accumulated = 0.0
		garage.refresh()
		var p: Dictionary = view.players[network.player_id]
		garage.camera.position = Vector3(p.position[0],1.9,p.position[1])
		status_line.text = "%s  %02d:%02d  ·  HP %.0f  ·  capital %d%s" % [view.phase.to_upper(),int(maxf(0,900-view.elapsed))/60,int(maxf(0,900-view.elapsed))%60,p.health,p.money,"  ·  DISARMED" if view.hardware_safe else ""]
		veil.color = Color(0,0,0,.78) if p.blind_until > view.tick*.1 else Color(.2,.18,.15,p.fire.smoke*.25 if p.fire.phase == "staging" and not p.escaped else 0.0)
		summary.text = "Style: %s  ·  Stage: %s  ·  Connected: %s\n%s" % [view.style,p.batch.stage,"yes" if network.session_connected else "no",fire_summary(p)]
	var selected: int = targets.get_selected_id()
	targets.clear()
	var lines: Array[String] = []
	for who in view.players:
		var p: Dictionary = view.players[who]
		lines.append("%d  %s  ·  HP %.0f  ·  %s  ·  %s" % [who,p.name,p.health,p.batch.stage,"ready" if p.ready else "not ready"])
		if who != network.player_id:
			targets.add_item("%d %s" % [who,p.name],who)
			if selected == who: targets.select(targets.item_count-1)
	if view.phase == "finished":
		lines.append("\nFINAL TASTING / SERVER RESULTS")
		for result in view.results:
			var c: Dictionary = result.judge.categories
			lines.append("%s: %.1f/100 · capital %d\nAroma %.1f / Look %.1f / Flavor %.1f / Feel %.1f / Style %.1f\n%s" % [result.name,result.judge.score,result.money,c.aroma,c.appearance,c.flavor,c.mouthfeel,c.style_accuracy," ".join(result.judge.feedback)])
	scoreboard.text = "\n".join(lines)
	render_world(view)

func fire_summary(p: Dictionary) -> String:
	if p.fire.phase == "staging": return "FIRE: %.1f seconds to inspection · Smoke %.0f%% · %s" % [p.fire.remaining,p.fire.smoke*100,"ESCAPED" if p.escaped else "Reach the green exit"]
	if p.claim.resolved: return "Claim %s: payout %d / penalty %d. %s" % ["accepted" if p.claim.passed else "rejected",p.claim.payout,p.claim.penalty,p.claim.reason]
	return "No fire incident. Keep your batch safe while competing."

func mesh_marker(color: Color, projectile: bool = false) -> Node3D:
	var body := Node3D.new()
	var mesh := MeshInstance3D.new()
	if projectile:
		var sphere := SphereMesh.new()
		sphere.radius = .2
		sphere.height = .4
		mesh.mesh = sphere
	else:
		var capsule := CapsuleMesh.new()
		capsule.radius = .28
		capsule.height = 1.6
		mesh.mesh = capsule
		mesh.position.y = .85
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .6
	mesh.material_override = material
	body.add_child(mesh)
	var label := Label3D.new()
	label.name = "Nameplate"
	label.font_size = 28
	label.position.y = 1.9
	body.add_child(label)
	garage.add_child(body)
	return body

func render_world(view: Dictionary) -> void:
	for who in markers.keys():
		if not view.players.has(who):
			markers[who].queue_free()
			markers.erase(who)
	for who in view.players:
		var p: Dictionary = view.players[who]
		if not markers.has(who): markers[who] = mesh_marker(Color.from_hsv(float(who)/8,.6,.9))
		markers[who].visible = who != network.player_id
		markers[who].position = Vector3(p.position[0],0,p.position[1])
		markers[who].get_node("Nameplate").text = "%s  %.0f HP%s" % [p.name,p.health," [offline]" if not p.connected else ""]
		if p.fire.phase == "staging":
			if not fires.has(who): fires[who] = mesh_marker(Color("f2803b"),true)
			var origin: Array = p.fire.get("origin",p.position)
			fires[who].position = Vector3(origin[0],.6,origin[1])
			fires[who].scale = Vector3(3,6,3)*(.5+p.fire.heat)
		elif fires.has(who):
			fires[who].queue_free()
			fires.erase(who)
	var active: Array = []
	for p in view.projectiles:
		active.append(p.id)
		if not projectiles.has(p.id): projectiles[p.id] = mesh_marker(Color("bac8ce") if p.weapon == "keg" else Color("d9ad62"),true)
		projectiles[p.id].position = Vector3(p.position[0],p.position[1],p.position[2])
	for id in projectiles.keys():
		if id not in active:
			projectiles[id].queue_free()
			projectiles.erase(id)

func _process(delta: float) -> void:
	if not remote_mode or not network.session_connected or network.view.get("phase") not in ["running","settling"]: return
	movement_timer += delta
	if movement_timer < .1: return
	movement_timer = 0.0
	var direction := Vector3.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not panel.visible:
		direction = Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		direction = direction.rotated(Vector3.UP,garage.camera.rotation.y).normalized()
	network.send("move",{"direction":[direction.x,direction.z]})

func on_state(_state: Dictionary) -> void:
	pass
