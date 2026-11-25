extends RefCounted

func run(t) -> void:
	var path := "res://src/visuals/beer_optics.gd"
	if not FileAccess.file_exists(path):
		t.check(false,"chemistry-driven optics mapper exists")
		return
	var optics = load(path).new()
	var previous := 3.1
	for srm in [2.0,10.0,20.0,45.0]:
		var p: Dictionary = optics.parameters({"srm":srm},"gl_compatibility")
		t.check(p.color.r+p.color.g+p.color.b < previous,"SRM darkens monotonically")
		previous = p.color.r+p.color.g+p.color.b
		t.check(p.tier == "compatibility" and not p.reflection_probe,"compatibility fallback avoids unsupported reflection probes")
	var clear: Dictionary = optics.parameters({"haze":0.0,"protein":0.0,"ibu":0.0,"co2":0.0,"temp_c":20.0},"gl_compatibility")
	var hazy: Dictionary = optics.parameters({"haze":1.0,"protein":1.0,"ibu":80.0,"co2":3.0,"temp_c":100.0},"forward_plus")
	t.check(hazy.haze > clear.haze and hazy.foam > clear.foam,"haze and protein/IBU foam respond to chemistry")
	t.check(hazy.bubbles > clear.bubbles and hazy.steam > clear.steam,"CO2 nucleation and thermal steam respond to chemistry")
	t.check(hazy.reflection_probe and hazy.tier == "forward_plus","higher renderer enables supported reflection tier")
	for bad in [NAN,INF,-INF,-100000.0,100000.0]:
		var p: Dictionary = optics.parameters({"srm":bad,"haze":bad,"protein":bad,"ibu":bad,"co2":bad,"temp_c":bad},"unknown")
		for key in ["srm","haze","foam","bubbles","steam","condensation"]:
			t.check(is_finite(p[key]) and p[key] >= 0.0,"finite nonnegative shader input "+key)
		t.check(is_finite(p.color.r) and is_finite(p.color.g) and is_finite(p.color.b),"finite absorption color")
		t.check(p.tier == "compatibility","unknown renderer has conservative fallback")
	var sim = load("res://src/chemistry/brewing_simulation.gd").new()
	var state: Dictionary = sim.initial_state(42)
	var before: String = sim.state_hash(state)
	var mapped: Dictionary = optics.from_batch(state,"gl_compatibility")
	t.check(mapped.srm >= 2 and mapped.srm <= 50,"batch maps to bounded estimated SRM")
	t.check(sim.state_hash(state) == before,"optical snapshot consumption is read-only")
	var display_path := "res://src/visuals/beer_display.gd"
	if not FileAccess.file_exists(display_path):
		t.check(false,"bounded beer and thermal display exists")
		return
	var display = load(display_path).new()
	t.root.add_child(display)
	display.configure(mapped)
	var count: int = display.get_child_count()
	for i in range(20): display.configure(hazy)
	t.check(display.get_child_count() == count,"snapshot changes reuse display nodes")
	t.check(display.bubbles.size() <= 32 and display.drops.size() <= 24,"nucleation and condensation are bounded")
	t.check(is_equal_approx(display.material.get_shader_parameter("srm"),hazy.srm),"mapped absorption reaches live shader")
	t.check(display.foam.visible and display.steam.visible,"foam and hot steam render in fallback")
	display.configure(clear)
	t.check(not display.foam.visible and not display.steam.visible,"cold flat chemistry disables foam/steam")
	t.check(not display.steam.observe_hazard({"kind":"fire"}) and not display.steam.visible,"malformed hazard cannot enable visual fire")
	t.check(display.steam.observe_hazard({"type":"HazardEvent","version":1,"seq":1,"tick":1,"safe_state":true,"kind":"fire"}) and display.steam.visible,"validated generic fire event drives independent VFX")
	display.queue_free()
	await t.process_frame
	t.check(not is_instance_valid(display),"display and effect children are freed")
	var garage = load("res://scenes/garage/garage.tscn").instantiate()
	t.root.add_child(garage)
	var module = garage.get_node("BeerVisuals")
	var initial_srm: float = module.display.material.get_shader_parameter("srm")
	garage.session.state.flaws.astringency = 1.0
	garage.refresh()
	t.check(module.display.material.get_shader_parameter("srm") > initial_srm,"live garage chemistry changes sample absorption")
	garage.queue_free()
	await t.process_frame
	t.check(not is_instance_valid(module),"garage lifetime owns visual module")
