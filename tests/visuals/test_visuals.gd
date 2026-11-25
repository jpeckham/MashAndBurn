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
