extends SceneTree
const Optics = preload("res://src/visuals/beer_optics.gd")
const Display = preload("res://src/visuals/beer_display.gd")
const Thermal = preload("res://src/visuals/thermal_effect.gd")
var optics := Optics.new()
var world: Node3D
var camera: Camera3D
var samples: Array = []
var incidents: Array = []
var labels: Array[Label] = []
var heading: Label
var footer: Label
var output := ""
var captures: Array = []
var profile: Dictionary = {}
var current_inputs: Array = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count): await process_frame

func label(text: String, position_value: Vector2, width: float, size_value: int) -> Label:
	var node := Label.new()
	node.text = text
	node.position = position_value
	node.size.x = width
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_font_size_override("font_size",size_value)
	node.add_theme_color_override("font_color",Color("f0dfb7"))
	root.add_child(node)
	return node

func box(at: Vector3, size_value: Vector3, tint: Color, metal: float = 0) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = metal
	material.roughness = .25 if metal > 0 else .8
	node.material_override = material
	world.add_child(node)

func apply(inputs: Array, descriptions: Array, fires: Array = []) -> void:
	current_inputs = inputs.duplicate(true)
	for i in range(4):
		var params: Dictionary = optics.parameters(inputs[i],RenderingServer.get_current_rendering_method())
		samples[i].configure(params)
		labels[i].text = descriptions[i]
		incidents[i].configure(fires[i] if not fires.is_empty() else 0.0,true,.65 if not fires.is_empty() and fires[i] > 0 else 0.0)

func capture(name_value: String) -> void:
	heading.text = "MASH & BURN  /  "+name_value.to_upper().replace("-"," ")
	await frames(12)
	await RenderingServer.frame_post_draw
	var bitmap := root.get_texture().get_image()
	if bitmap.save_png(output+"/"+name_value+".png") != OK: quit(1); return
	var params: Array = []
	for input in current_inputs:
		var p: Dictionary = optics.parameters(input,RenderingServer.get_current_rendering_method())
		p.color = [p.color.r,p.color.g,p.color.b]
		params.append(p)
	captures.append({"file":name_value+".png","inputs":current_inputs.duplicate(true),"parameters":params,"utc":Time.get_datetime_string_from_system(true)})
	print("VISUAL_CAPTURE "+name_value)

func run() -> void:
	if OS.get_environment("GITHUB_ACTIONS") != "true" or OS.get_environment("RUNNER_ENVIRONMENT") != "github-hosted" or DisplayServer.get_name() == "headless":
		printerr("Visual comparisons require a disposable hosted display.")
		quit(2)
		return
	create_timer(120).timeout.connect(func(): printerr("VISUAL_TIMEOUT"); quit(2))
	root.size = Vector2i(1366,740)
	output = "res://.tools/visual-proof/"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	world = Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("16272e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dce7ee")
	environment.ambient_light_energy = .7
	var env := WorldEnvironment.new()
	env.environment = environment
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-25,0)
	light.light_energy = 1.4
	world.add_child(light)
	box(Vector3(0,-.16,0),Vector3(8,.2,5),Color("62767b"),.7)
	box(Vector3(0,1.3,-.8),Vector3(7,3,.1),Color("d7d4c5"))
	for i in range(15): box(Vector3((i-7)*.4,1.1,-.73),Vector3(.07,2.3,.03),Color("34464b"))
	camera = Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,2.4,6.8)
	camera.look_at(Vector3(0,.9,0))
	camera.fov = 42
	camera.current = true
	if RenderingServer.get_current_rendering_method() in ["forward_plus","mobile"]:
		var probe := ReflectionProbe.new()
		probe.size = Vector3(12,8,12)
		probe.position.y = 2
		world.add_child(probe)
	heading = label("",Vector2(80,16),1206,26)
	footer = label("",Vector2(24,651),1318,16)
	for i in range(4):
		var display := Display.new()
		world.add_child(display)
		display.position.x = (i-1.5)*1.3
		samples.append(display)
		var fire := Thermal.new()
		world.add_child(fire)
		fire.position = Vector3(display.position.x,0,.45)
		incidents.append(fire)
		var point := camera.unproject_position(Vector3(display.position.x,0,0))
		labels.append(label("",Vector2(point.x-150,point.y+15),300,18))
	footer.text = "%s / %s\nRGB absorption + artistic scattering; bounded mesh nucleation and vapor; no ray tracing\nGitHub-hosted %s / source %s" % [RenderingServer.get_current_rendering_method(),RenderingServer.get_video_adapter_name(),OS.get_environment("GITHUB_RUN_ID"),OS.get_environment("GITHUB_SHA").left(8)]
	apply([{"srm":2,"haze":0,"co2":2.5},{"srm":10,"haze":0,"co2":2.5},{"srm":20,"haze":0,"co2":2.5},{"srm":45,"haze":0,"co2":2.5}],["SRM 2 / CLEAR","SRM 10 / CLEAR","SRM 20 / CLEAR","SRM 45 / CLEAR"])
	await capture("01-srm-2-10-20-45")
	apply([{"srm":10,"haze":0},{"srm":10,"haze":1},{"srm":20,"haze":0},{"srm":20,"haze":1}],["SRM 10 / CLEAR","SRM 10 / HAZY","SRM 20 / CLEAR","SRM 20 / HAZY"])
	await capture("02-haze-scattering")
	apply([{"srm":10,"protein":0,"ibu":0,"co2":0},{"srm":10,"protein":.2,"ibu":5,"co2":1},{"srm":10,"protein":1,"ibu":80,"co2":3},{"srm":10,"protein":1,"ibu":80,"co2":0}],["FLAT / NO HEAD","LOW RETENTION","PROTEIN + IBU + CO2","PROTEIN / NO CO2"])
	await capture("03-foam-nucleation")
	apply([{"temp_c":20},{"temp_c":60},{"temp_c":80},{"temp_c":100}],["20 C / COLD","60 C / WARM","80 C / STEAM","100 C / CONDENSATE"])
	await capture("04-steam-condensation")
	apply([{"temp_c":20},{"temp_c":20},{"temp_c":20},{"temp_c":20}],["NO INCIDENT","LOW FICTIONAL FIRE","HIGH FIRE / SMOKE","HIGH FIRE / SMOKE"],[0,.3,.7,1])
	await capture("05-fire-smoke")
	var frame_times: Array = []
	var start := Time.get_ticks_usec()
	var previous := start
	for i in range(120):
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times.append((now-previous)/1000.0)
		previous = now
	frame_times.sort()
	profile = {"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),"engine":Engine.get_version_info(),"display":DisplayServer.get_name(),"sample_frames":120,"fps":120000000.0/maxi(1,Time.get_ticks_usec()-start),"frame_interval_p50_ms":frame_times[60],"frame_interval_p95_ms":frame_times[114],"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
	var report := {"source_commit":OS.get_environment("GITHUB_SHA"),"run_id":OS.get_environment("GITHUB_RUN_ID"),"machine":OS.get_environment("RUNNER_NAME"),"utc":Time.get_datetime_string_from_system(true),"profile":profile,"captures":captures,"operator":"GitHub-hosted original fixed-camera reference fixture","limits":"Analytic RGB absorption, empirical haze/foam, mesh bubbles/droplets, camera-facing vapor layers and reflection-probe raster rendering only."}
	var file := FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("VISUAL_RESULT "+JSON.stringify(profile))
	quit(0)
