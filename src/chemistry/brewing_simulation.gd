extends RefCounted
## Game approximations, SI units, deterministic fixed-step integration; never hardware control.
const Protocol = preload("res://src/contracts/protocol.gd")
const STAGES = ["mash", "boil", "cooling", "fermentation", "packaging", "judging"]
const YEAST = {"ale": {"attenuation":0.78, "flocculation":0.7, "optimum_c":20.0}, "lager": {"attenuation":0.82, "flocculation":0.85, "optimum_c":12.0}}

func f_to_c(f: float) -> float:
	return (f - 32.0) / 1.8

func c_to_f(c: float) -> float:
	return c * 1.8 + 32.0

func minutes_to_seconds(minutes: float) -> float:
	return minutes * 60.0

func enzyme(temp: float, peak: float, width: float) -> float:
	return exp(-0.5 * pow((temp - peak) / width, 2))

func tinseth(gravity: float, minutes: float) -> float:
	return 1.65 * pow(0.000125, gravity - 1.0) * (1.0 - exp(-0.04 * minutes)) / 4.15

func ibu(grams: float, alpha: float, litres: float, gravity: float, minutes: float, vigor: float) -> float:
	return grams * alpha * 1000.0 * tinseth(gravity, minutes) * vigor / maxf(litres, 0.1)

func pressure_psi(c: float, volumes: float) -> float:
	var f := c_to_f(c)
	return maxf(0, -16.6999 - 0.0101059*f + 0.00116512*f*f + 0.173354*f*volumes + 4.24267*volumes - 0.0684226*volumes*volumes)

func ion_balance(ions: Dictionary) -> float:
	return ions.Ca/20.04 + ions.Mg/12.15 - ions.SO4/48.03 - ions.Cl/35.45 - ions.HCO3/61.02

func approximate_ph(ions: Dictionary) -> float:
	return clampf(5.4 + (ions.HCO3 - 60.0)*0.001 - (ions.Ca - 50.0)*0.0015 - (ions.Mg - 10.0)*0.0005, 4.0, 7.0)

func initial_state(seed_value: int) -> Dictionary:
	return {"type":"BatchState", "version":1, "seed":seed_value, "batch_id":"batch-%d" % seed_value,
		"tick":0, "seq":0, "sim_seconds":0.0, "stage_seconds":0.0, "stage":"mash",
		"volume_l":20.0, "grain_kg":5.0, "temp_c":66.7, "target_c":66.7,
		"ions":{"Ca":50.0,"Mg":10.0,"SO4":75.0,"Cl":60.0,"HCO3":60.0}, "ph":5.4,
		"conversion":0.0, "sugar_kg":0.0, "fermented_kg":0.0, "og":1.0, "gravity":1.0,
		"ibu":0.0, "hop_oils":0.0, "hops":[], "vigor":1.0, "chiller":1.0,
		"infection_risk":0.0, "infected":false, "yeast":"ale", "attenuation":0.0, "flocculation":0.0,
		"priming_g":120.0, "regulator_psi":0.0, "co2_volumes":0.85, "pressure_psi":0.0,
		"safe_state":false, "flaws":{"astringency":0.0,"dms":0.0,"phenolic":0.0,"esters":0.0,"fusels":0.0,"diacetyl":0.0,"acetaldehyde":0.0}}

func state_hash(state: Dictionary) -> String:
	return JSON.stringify(state, "", true, true).sha256_text()

func can_next(s: Dictionary) -> bool:
	match s.stage:
		"mash": return s.stage_seconds >= 3600 and s.conversion >= 0.6
		"boil": return s.stage_seconds >= 3600 and s.temp_c >= 95
		"cooling": return s.temp_c <= 25
		"fermentation": return s.stage_seconds >= 172800 and s.attenuation >= 0.95
		"packaging": return true
	return false

func advance(state: Dictionary, command: Dictionary, dt_seconds: float) -> Dictionary:
	var err := Protocol.new().validate(state)
	if not err.is_empty() or not is_finite(dt_seconds) or dt_seconds <= 0 or dt_seconds > 60:
		return {"ok":false, "state":state.duplicate(true), "events":[], "error":"Invalid state or timestep (0 < seconds <= 60). " + err}
	var s := state.duplicate(true)
	var events: Array = []
	if not command.is_empty():
		var c := command.duplicate(true)
		c.merge({"type":"PlayerCommand", "version":1,"seq":s.seq + 1,"tick":s.tick}, false)
		err = Protocol.new().validate(c)
		if not err.is_empty() or c.tick != s.tick or c.seq != s.seq + 1:
			return {"ok":false,"state":state.duplicate(true),"events":[],"error":"Rejected command: " + err + " (check tick/sequence)"}
		match c.action:
			"set":
				if c.field in ["grain_kg", "volume_l"] and (s.stage != "mash" or s.stage_seconds > 0):
					return {"ok":false,"state":state.duplicate(true),"events":[],"error":"Recipe quantities lock after mash begins."}
				s[c.field] = c.value
			"add_hops":
				if s.stage != "boil" or s.hops.size() >= 32:
					return {"ok":false,"state":state.duplicate(true),"events":[],"error":"Add up to 32 hop charges during boil."}
				s.hops.append({"grams":c.grams,"alpha":c.alpha,"minutes":0.0})
				s.hop_oils += c.grams * 0.02
			"next":
				if not can_next(s):
					return {"ok":false,"state":state.duplicate(true),"events":[],"error":"Stage not ready. Follow the station instructions."}
				s.stage = STAGES[STAGES.find(s.stage) + 1]
				s.stage_seconds = 0.0
				match s.stage:
					"boil": s.target_c = 100.0
					"fermentation":
						s.target_c = YEAST[s.yeast].optimum_c
						var rng := RandomNumberGenerator.new()
						rng.seed = s.seed + s.tick * 7919
						s.infected = rng.randf() < s.infection_risk
					"judging":
						s.co2_volumes = 0.85 + s.priming_g / (4.0 * s.volume_l)
						if s.regulator_psi > 0:
							var lo := 0.0
							var hi := 8.0
							for i in range(24):
								var mid := (lo + hi) / 2
								if pressure_psi(s.temp_c, mid) < s.regulator_psi: lo = mid
								else: hi = mid
							s.co2_volumes = (lo + hi) / 2
			"hazard", "fire", "disconnect":
				s.safe_state = true
				events.append(hazard(s, c.action))
		s.seq = c.seq
	s.tick += 1
	s.sim_seconds += dt_seconds
	s.stage_seconds += dt_seconds
	s.ph = approximate_ph(s.ions)
	if s.safe_state:
		return {"ok":true, "state":s,"events":events,"error":""}
	if s.stage == "cooling":
		s.temp_c = 20.0 + (s.temp_c - 20.0) * exp(-(0.00005 + 0.002*s.chiller)*dt_seconds)
		if s.temp_c >= 25 and s.temp_c <= 60:
			s.infection_risk = 1.0 - (1.0 - s.infection_risk)*exp(-dt_seconds / 72000.0)
	elif s.stage in ["mash", "boil", "fermentation"]:
		# 3 kW maximum net heating/cooling; water equivalent thermal mass.
		var limit: float = 3.0 * dt_seconds / (s.volume_l * 4.186)
		s.temp_c = move_toward(s.temp_c, s.target_c, limit)
	match s.stage:
		"mash":
			var rate: float = (enzyme(s.temp_c, 70, 5) + enzyme(s.temp_c, 63, 4)) / 2400.0
			rate *= exp(-pow((s.ph - 5.4)/0.6, 2))
			s.conversion = 1 - (1-s.conversion)*exp(-rate*dt_seconds)
			s.sugar_kg = s.grain_kg * 0.8 * s.conversion
			s.og = 1 + s.sugar_kg * 0.384 / s.volume_l
			s.gravity = s.og
			if s.temp_c > 78:
				s.flaws.astringency = minf(1, s.flaws.astringency + (s.temp_c-78)*dt_seconds/36000)
				s.flaws.dms = minf(1, s.flaws.dms + dt_seconds/36000)
				s.flaws.phenolic = minf(1, s.flaws.phenolic + dt_seconds/72000)
		"boil":
			if s.temp_c >= 95:
				# Evaporation bounded by available heat / water latent heat (2257 kJ/kg).
				s.volume_l = maxf(0.1, s.volume_l - 3.0*s.vigor*dt_seconds/2257.0)
				s.og = 1 + s.sugar_kg*0.384/s.volume_l
				s.gravity = s.og
				s.ibu = 0.0
				for h in s.hops:
					h.minutes += dt_seconds/60.0
					s.ibu += ibu(h.grams,h.alpha,s.volume_l,s.og,h.minutes,s.vigor)
				s.hop_oils *= exp(-dt_seconds/1800.0)
				s.flaws.dms *= exp(-dt_seconds/1800.0)
		"fermentation":
			var strain: Dictionary = YEAST[s.yeast]
			var activity := enzyme(s.temp_c, strain.optimum_c, 10.0)
			s.attenuation = 1-(1-s.attenuation)*exp(-dt_seconds*activity/43200.0)
			s.fermented_kg = s.sugar_kg * strain.attenuation * s.attenuation
			s.gravity = s.og - s.fermented_kg*0.384/s.volume_l
			s.flocculation = strain.flocculation * s.attenuation
			s.flaws.esters = minf(1, s.flaws.esters + maxf(0,s.temp_c-strain.optimum_c)*dt_seconds/2000000)
			s.flaws.fusels = minf(1, s.flaws.fusels + maxf(0,s.temp_c-strain.optimum_c-4)*dt_seconds/1500000)
			s.flaws.diacetyl = (1-s.attenuation)*0.8
			s.flaws.acetaldehyde = (1-s.attenuation)*0.9
	s.pressure_psi = pressure_psi(s.temp_c, s.co2_volumes) if s.stage in ["packaging","judging"] else 0.0
	if s.stage in ["packaging","judging"] and (s.co2_volumes > 3.5 or s.pressure_psi > 60):
		s.safe_state = true
		events.append(hazard(s, "overpressure"))
	return {"ok":true,"state":s,"events":events,"error":""}

func hazard(s: Dictionary, kind: String) -> Dictionary:
	return {"type":"HazardEvent","version":1,"seq":s.seq,"tick":s.tick,"kind":kind,"safe_state":true}
