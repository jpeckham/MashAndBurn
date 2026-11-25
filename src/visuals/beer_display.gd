extends Node3D
const Thermal = preload("res://src/visuals/thermal_effect.gd")
var material := ShaderMaterial.new()
var foam: MeshInstance3D
var steam: Node3D
var bubbles: Array[Vector3] = []
var drops: Array[Vector3] = []
var bubble_mesh: MultiMeshInstance3D
var drop_mesh: MultiMeshInstance3D
var clock := 0.0
var bubble_activity := 0.0

func surface(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = .18 if metallic > 0 else .45
	if color.a < 1:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func cylinder(radius: float, height: float, at: Vector3, mat: Material, open_top: bool = false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	mesh.cap_top = not open_top
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	add_child(node)
	return node

func particles(count: int, radius: float, mat: Material) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius*2
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = mat
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.mesh = sphere
	node.multimesh.instance_count = count
	add_child(node)
	return node

func _ready() -> void:
	material.shader = preload("res://src/visuals/beer.gdshader")
	cylinder(.295,.76,Vector3(0,.49,0),material)
	cylinder(.325,1.13,Vector3(0,.57,0),surface(Color(.8,.92,1,.12)),true)
	cylinder(.34,.035,Vector3(0,.015,0),surface(Color("9aaeb6"),.75))
	var rim := TorusMesh.new()
	rim.inner_radius = .31
	rim.outer_radius = .33
	var rim_node := MeshInstance3D.new()
	rim_node.mesh = rim
	rim_node.material_override = surface(Color("c8dae0"),.7)
	rim_node.position.y = 1.13
	add_child(rim_node)
	foam = cylinder(.298,.12,Vector3(0,.9,0),surface(Color("f4e4bf")))
	bubble_mesh = particles(32,.012,surface(Color(.95,.9,.72,.7)))
	for i in range(32): bubbles.append(Vector3(sin(i*2.4)*.2,float(i)/32,cos(i*2.4)*.2))
	drop_mesh = particles(24,.015,surface(Color(.7,.9,1,.65)))
	# Condensate on a cooler pane behind the hot vessel, not a temperature solver.
	var pane := MeshInstance3D.new()
	var glass := BoxMesh.new()
	glass.size = Vector3(.9,1.2,.025)
	pane.mesh = glass
	pane.material_override = surface(Color(.45,.7,.8,.12))
	pane.position = Vector3(0,.7,-.48)
	add_child(pane)
	for i in range(24):
		var pos := Vector3(float(i%6)*.15-.375,float(i/6)*.23+.3,-.43)
		drops.append(pos)
		drop_mesh.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(.5,1.8,.5)),pos))
	steam = Thermal.new()
	add_child(steam)
	steam.position.y = 1.05
	steam.scale = Vector3.ONE*.65

func configure(params: Dictionary) -> void:
	material.set_shader_parameter("srm",params.srm)
	material.set_shader_parameter("haze",params.haze)
	foam.visible = params.foam > .001
	foam.scale.y = .15+params.foam*1.4
	foam.position.y = .87+.06*foam.scale.y
	bubble_activity = params.bubbles
	bubble_mesh.multimesh.visible_instance_count = int(round(params.bubbles*32))
	drop_mesh.multimesh.visible_instance_count = int(round(params.condensation*24))
	steam.configure(params.steam)

func _process(delta: float) -> void:
	clock += minf(delta,.1)
	if bubble_activity <= .001: return
	for i in range(bubbles.size()):
		var pos := bubbles[i]
		pos.y = .13+fposmod(pos.y+clock*(.18+bubble_activity*.2),.7)
		bubble_mesh.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,pos))
