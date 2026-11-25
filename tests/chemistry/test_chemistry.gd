extends RefCounted

func run(t) -> void:
	if not FileAccess.file_exists("res://src/chemistry/brewing_simulation.gd"):
		t.check(false, "deterministic simulation implemented")
		t.check(false, "Tinseth 60 minute fixture implemented")
		return
	var sim = load("res://src/chemistry/brewing_simulation.gd").new()
	t.check(abs(sim.f_to_c(152.0) - 66.6666667) < 0.00001, "F to C fixture")
	t.check(abs(sim.c_to_f(100.0) - 212.0) < 0.00001, "C to F fixture")
	t.check(sim.minutes_to_seconds(60.0) == 3600.0, "minutes to seconds")
	t.check(abs(sim.tinseth(1.050, 60.0) - 0.230664077) < 0.000001, "Tinseth utilization fixture")
	t.check(abs(sim.ibu(30.0, 0.05, 20.0, 1.050, 60.0, 1.0) - 17.2998058) < 0.0001, "IBU fixture")
	t.check(sim.ibu(30, .05, 20, 1.05, 60, 1) > sim.ibu(30, .05, 20, 1.05, 10, 1), "boil exposure increases bitterness")
	t.check(sim.ibu(30, .05, 20, 1.08, 60, 1) < sim.ibu(30, .05, 20, 1.04, 60, 1), "gravity suppresses utilization")
	for f in [144.0, 152.0, 162.0]:
		t.check(sim.enzyme(sim.f_to_c(f), 65.0, 5.0) > 0, "mash enzyme window " + str(f))
	t.check(sim.enzyme(65, 65, 5) > sim.enzyme(90, 65, 5), "enzyme temperature peak")
	var s: Dictionary = sim.initial_state(42)
	t.check(s.ph >= 5.2 and s.ph <= 5.6, "default pH target")
	t.check(abs(sim.ion_balance(s.ions) - (s.ions.Ca/20.04 + s.ions.Mg/12.15 - s.ions.SO4/48.03 - s.ions.Cl/35.45 - s.ions.HCO3/61.02)) < .00001, "ion equivalent balance")
	var a: Dictionary = s.duplicate(true)
	var b: Dictionary = s.duplicate(true)
	for tick in range(120):
		a = sim.advance(a, {}, 60.0).state
		b = sim.advance(b, {}, 60.0).state
		if tick in [0, 29, 59, 119]:
			t.check(sim.state_hash(a) == sim.state_hash(b), "fixed tick replay " + str(tick))
			print("REPLAY tick=%d hash=%s" % [a.tick,sim.state_hash(a)])
	t.check(s.tick == 0 and s.conversion == 0, "advance leaves input unchanged")
	t.check(a.conversion > .8 and a.sugar_kg <= a.grain_kg * .8, "conversion and mass limit")
	var cold: Dictionary = s.duplicate(true)
	cold.temp_c = 20.0
	var warmed: Dictionary = sim.advance(cold, {"action":"set", "field":"target_c", "value":100.0}, 60).state
	t.check((warmed.temp_c - cold.temp_c) * cold.volume_l * 4.186 <= 180.00001, "heater energy bounded by 3 kW")
	var boiling: Dictionary = s.duplicate(true)
	boiling.stage = "boil"
	boiling.temp_c = 94.0
	boiling.target_c = 100.0
	var boiled: Dictionary = sim.advance(boiling, {}, 60).state
	var used_energy: float = (boiled.temp_c-boiling.temp_c)*boiling.volume_l*4.186 + (boiling.volume_l-boiled.volume_l)*2257
	t.check(used_energy <= 180.00001,"boil sensible plus latent energy cannot double spend heat")
	for bad in [-1.0, INF, NAN]:
		t.check(not sim.advance(s, {"action":"set", "field":"grain_kg", "value":bad}, 60).ok, "invalid amounts rejected")
	for dt in [-1.0, 0.0, 61.0, INF, NAN]:
		t.check(not sim.advance(s, {}, dt).ok, "invalid dt rejected")
	var dry: Dictionary = s.duplicate(true)
	dry.volume_l = .001
	t.check(not sim.advance(dry, {}, 60).ok, "near zero volume rejected")
	var scorch: Dictionary = s.duplicate(true)
	scorch.temp_c = 95.0
	scorch.target_c = 100.0
	t.check(sim.advance(scorch, {}, 60).state.flaws.astringency > 0, "scorching adds flaws")
	var cooling: Dictionary = s.duplicate(true)
	cooling.stage = "cooling"
	cooling.temp_c = 40.0
	cooling.chiller = 0.0
	var slow: Dictionary = sim.advance(cooling, {}, 60).state
	cooling.chiller = 1.0
	var fast: Dictionary = sim.advance(cooling, {}, 60).state
	t.check(fast.temp_c < slow.temp_c, "chiller removes heat")
	t.check(slow.infection_risk > 0, "cooling exposure infection probability")
	var package: Dictionary = s.duplicate(true)
	package.stage = "packaging"
	package.priming_g = 500.0
	var over: Dictionary = sim.advance(package, {"action":"next"}, 60)
	t.check(over.state.co2_volumes > 3.5 and over.state.safe_state and over.events.size() > 0, "overpriming hazard safe state")
	t.check(sim.pressure_psi(25, 2.5) > sim.pressure_psi(4, 2.5), "CO2 pressure increases with temperature")
	var ferment: Dictionary = s.duplicate(true)
	ferment.stage = "fermentation"
	ferment.sugar_kg = 3.0
	ferment.og = 1.0575
	ferment.temp_c = 30.0
	ferment.target_c = 30.0
	var hot: Dictionary = sim.advance(ferment, {}, 60).state
	t.check(hot.fermented_kg > 0 and hot.fermented_kg <= 3 and hot.flaws.fusels > 0, "fermentation mass and warm fusels")
	t.check(not sim.advance(s, {"action":"next"}, 60).ok, "premature stage transition rejected")
	var full: Dictionary = s.duplicate(true)
	for stage in ["mash", "boil", "cooling", "fermentation", "packaging"]:
		t.check(full.stage == stage, "batch enters " + stage)
		var n := 0
		while not sim.can_next(full) and n < 20000:
			full = sim.advance(full, {}, 60).state
			n += 1
		t.check(n < 20000, "stage ready " + stage)
		print("BATCH stage=%s tick=%d simulation_seconds=%.0f hash=%s" % [stage,full.tick,full.sim_seconds,sim.state_hash(full)])
		full = sim.advance(full, {"action":"next"}, 60).state
	t.check(full.stage == "judging", "complete batch to judging")

