extends Node3D
## Bounded camera-facing analytical vapor layers; no fluid or ignition solver.
var material := ShaderMaterial.new()
var smoke_material := ShaderMaterial.new()
var layer: MeshInstance3D
var smoke: MeshInstance3D
var light: OmniLight3D

func observe_hazard(event: Dictionary) -> bool:
	if not preload("res://src/contracts/protocol.gd").new().validate(event).is_empty(): return false
	if event.get("type") != "HazardEvent" or event.get("kind") != "fire": return false
	configure(1,true,.65)
	return true

func _ready() -> void:
	material.shader = preload("res://src/visuals/vapor.gdshader")
	smoke_material.shader = material.shader
	smoke_material.set_shader_parameter("kind",2)
	layer = plane(Vector2(.9,1.6),material,Vector3(0,.8,0))
	smoke = plane(Vector2(1.2,2.1),smoke_material,Vector3(0,2,0))
	light = OmniLight3D.new()
	light.position.y = .5
	light.light_color = Color("ff8a35")
	light.omni_range = 3
	add_child(light)
	configure(0)

func plane(size_value: Vector2, mat: Material, at: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size_value
	mesh.mesh = quad
	mesh.material_override = mat
	mesh.position = at
	add_child(mesh)
	return mesh

func configure(intensity: float, flame: bool = false, smoke_amount: float = 0) -> void:
	var strength := clampf(intensity,0,1) if is_finite(intensity) else 0.0
	var soot := clampf(smoke_amount,0,1) if is_finite(smoke_amount) else 0.0
	visible = strength > .001 or soot > .001
	material.set_shader_parameter("strength",strength)
	material.set_shader_parameter("kind",1 if flame else 0)
	smoke_material.set_shader_parameter("strength",soot)
	if light != null:
		light.visible = flame and strength > .001
		light.light_energy = strength*.8 if flame else 0.0

func _process(_delta: float) -> void:
	if not visible: return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	for mesh in [layer,smoke]:
		if mesh.global_position.distance_squared_to(camera.global_position) > .01: mesh.look_at(camera.global_position)
