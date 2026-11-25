extends RefCounted
## Original procedural props; world points are shared with the server's interaction rules.
const Fire = preload("res://src/gameplay/fire/fire_claims.gd")
const TITLES = {"receipt":"RECEIPT DESK","equipment":"OLD BUICK / EQUIPMENT TRUNK","evidence":"EVIDENCE STATION"}

static func build(garage: Node) -> Dictionary:
	var props: Dictionary = {}
	for object in Fire.STAGING_POINTS:
		var point: Array = Fire.STAGING_POINTS[object]
		var color: Color = {"receipt":Color("626f91"),"equipment":Color("467760"),"evidence":Color("a87b46")}[object]
		var marker: MeshInstance3D = garage.box(Vector3(point[0],.4,point[1]),Vector3(.7,.8,.6),color)
		var label := Label3D.new()
		label.name = "PropLabel"
		label.text = TITLES[object]+"\nE to stage nearby"
		label.font_size = 25
		label.position.y = 1.4
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.add_child(label)
		props[object] = marker
	# Receipt paper and a conspicuous evidence folder identify the two workstations.
	garage.box(Vector3(-4.8,.82,-.2),Vector3(.45,.025,.35),Color("e4dfcb"))
	garage.box(Vector3(4.8,.86,-.2),Vector3(.45,.10,.3),Color("d7aa54"))
	# An old sedan at the open garage exit: body, roof, glass, trunk, lights and wheels.
	garage.box(Vector3(5.7,.55,4.4),Vector3(1.35,.7,2.6),Color("456378"),.55)
	garage.box(Vector3(5.7,1.12,4.15),Vector3(1.1,.65,1.35),Color("344b60"),.45)
	garage.box(Vector3(5.7,1.18,4.84),Vector3(.94,.43,.025),Color("83a4ad"),.35)
	garage.box(Vector3(5.7,.95,5.35),Vector3(1.3,.08,.6),Color("6e8290"),.5)
	for x in [5.03,6.37]:
		for z in [3.6,5.2]:
			var wheel := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = .27
			mesh.bottom_radius = .27
			mesh.height = .16
			wheel.mesh = mesh
			wheel.position = Vector3(x,.3,z)
			wheel.rotation_degrees.z = 90
			var rubber := StandardMaterial3D.new()
			rubber.albedo_color = Color("202326")
			wheel.material_override = rubber
			garage.add_child(wheel)
	for x in [5.25,6.15]: garage.box(Vector3(x,.6,5.72),Vector3(.25,.18,.04),Color("c77e65"))
	return props

static func show_progress(props: Dictionary, objects: Dictionary) -> void:
	for object in props:
		var staged: bool = objects.get(object,false)
		var label: Label3D = props[object].get_node("PropLabel")
		label.text = TITLES[object]+("\nYOUR RECORD: STAGED" if staged else "\nE to stage nearby")
		label.modulate = Color("a2e1b7") if staged else Color.WHITE
