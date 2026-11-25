extends SceneTree
func _initialize() -> void:
	var s = preload("res://src/chemistry/brewing_simulation.gd").new().initial_state(42)
	var examples := [s,
		{"type":"PlayerCommand","version":1,"seq":1,"tick":0,"action":"set","field":"target_c","value":66.7},
		{"type":"HazardEvent","version":1,"seq":1,"tick":0,"kind":"disconnect","safe_state":true},
		{"type":"HardwareFrame","version":1,"seq":0,"tick":0,"enabled":false,"safe_state":true,"heater":0.0,"pump":0.0},
		{"type":"JudgeResult","version":1,"seq":1,"tick":100,"batch_id":"batch-42","categories":{"aroma":15,"appearance":15,"flavor":15,"mouthfeel":15,"style_accuracy":15},"score":75,"feedback":["A balanced fictional pale ale."],"severe_flaws":[]}]
	var file := FileAccess.open("res://src/contracts/examples.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(examples,"\t"))
	quit()
