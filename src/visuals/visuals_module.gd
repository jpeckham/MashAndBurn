extends Node3D
const Optics = preload("res://src/visuals/beer_optics.gd")
const Display = preload("res://src/visuals/beer_display.gd")
const Thermal = preload("res://src/visuals/thermal_effect.gd")
var garage: Node
var display: Node3D
var incident: Node3D
var optics := Optics.new()
var caption: Label3D
var last_batch := ""

func setup(host: Node) -> void:
	name = "BeerVisuals"
	garage = host
	display = Display.new()
	add_child(display)
	display.position = Vector3(0,1.0,-.5)
	garage.box(Vector3(0,.46,-.5),Vector3(1.4,.92,.9),Color("24343b"))
	garage.box(Vector3(0,.95,-.5),Vector3(1.5,.07,1),Color("91a5a9"),.75)
	caption = garage.sign3d("BEER SAMPLE / OPTICAL ESTIMATE",Vector3(0,2.5,-.7),Color("efc16c"),20)
	incident = Thermal.new()
	add_child(incident)
	incident.position = Vector3(0,.05,-1)
	garage.button("Inspect beer & effects",garage.module_slot,func():
		garage.camera.position = Vector3(0,1.95,2.5)
		garage.camera.look_at(Vector3(0,1.6,-.5))
		garage.look_pitch = garage.camera.rotation.x)
	if RenderingServer.get_current_rendering_method() in ["forward_plus","mobile"]:
		var probe := ReflectionProbe.new()
		probe.size = Vector3(12,6,12)
		probe.position = Vector3(0,2,0)
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		add_child(probe)

func on_state(state: Dictionary) -> void:
	var params: Dictionary = optics.from_batch(state,RenderingServer.get_current_rendering_method())
	display.configure(params)
	caption.text = "SRM ~%.0f / HAZE %.0f%% / FOAM %.0f%%\nARTISTIC CHEMISTRY ESTIMATE" % [params.srm,params.haze*100,params.foam*100]
	if last_batch != state.batch_id:
		last_batch = state.batch_id
		incident.configure(0)
	for event in garage.session.events: incident.observe_hazard(event)
