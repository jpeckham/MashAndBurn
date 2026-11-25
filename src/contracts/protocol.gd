extends RefCounted
const BOUNDS = {"volume_l":[0.1,100.0],"grain_kg":[0.0,20.0],"target_c":[0.0,100.0],"temp_c":[0.0,100.0],"vigor":[0.0,1.0],"chiller":[0.0,1.0],"priming_g":[0.0,1000.0],"regulator_psi":[0.0,60.0]}
const STAGES = ["mash","boil","cooling","fermentation","packaging","judging"]

func number(v, lo: float, hi: float) -> bool:
	return (v is float or v is int) and is_finite(float(v)) and v >= lo and v <= hi

func validate(m) -> String:
	if not m is Dictionary: return "Message must be an object."
	for k in ["version","type","seq","tick"]:
		if not m.has(k): return "Missing " + k
	if m.version != 1: return "Unsupported protocol version."
	for k in ["seq","tick"]:
		if not number(m[k],0,2147483647) or float(m[k]) != floor(float(m[k])): return "Invalid ordering counter."
	match m.type:
		"PlayerCommand":
			if not m.get("action") in ["set","add_hops","next","hazard","fire","disconnect"]: return "Unsupported action."
			if m.action == "set":
				if not m.get("field") in BOUNDS: return "Unsupported setting."
				var b: Array = BOUNDS[m.field]
				if not number(m.get("value"),b[0],b[1]): return "Setting outside bounds: " + m.field
			if m.action == "add_hops" and (not number(m.get("grams"),0,500) or not number(m.get("alpha"),0,0.3)): return "Invalid hop quantity or alpha fraction."
		"BatchState":
			for k in BOUNDS:
				if not number(m.get(k), BOUNDS[k][0], BOUNDS[k][1]): return "Invalid " + k
			if not m.get("stage") in STAGES: return "Invalid stage."
			if not m.get("yeast") in ["ale","lager"]: return "Invalid yeast."
			if not m.get("batch_id") is String or m.batch_id.is_empty() or m.batch_id.length() > 80: return "Invalid batch id."
			if not number(m.get("seed"),0,2147483647): return "Invalid seed."
			for k in ["safe_state","infected"]:
				if not m.get(k) is bool: return "Invalid boolean " + k
			for k in ["sim_seconds","stage_seconds","sugar_kg","fermented_kg","hop_oils","ibu","pressure_psi","co2_volumes"]:
				if not number(m.get(k),0,1e12): return "Invalid " + k
			for k in ["conversion","attenuation","flocculation","infection_risk"]:
				if not number(m.get(k),0,1): return "Invalid " + k
			if not number(m.get("ph"),0,14) or not number(m.get("og"),1,100) or not number(m.get("gravity"),0.9,100): return "Invalid chemistry."
			if m.sugar_kg > m.grain_kg*0.8 + 0.000001 or m.fermented_kg > m.sugar_kg: return "Mass exceeds input."
			if not m.get("ions") is Dictionary or not m.get("flaws") is Dictionary: return "Missing composition."
			for k in ["Ca","Mg","SO4","Cl","HCO3"]:
				if not number(m.ions.get(k),0,2000): return "Invalid ion."
			for k in ["astringency","dms","phenolic","esters","fusels","diacetyl","acetaldehyde"]:
				if not number(m.flaws.get(k),0,1): return "Invalid flaw."
			if not m.get("hops") is Array or m.hops.size() > 32: return "Invalid hop charges."
			for h in m.hops:
				if not h is Dictionary: return "Invalid hop charge."
				if not number(h.get("grams"),0,500) or not number(h.get("alpha"),0,0.3) or not number(h.get("minutes"),0,1e12): return "Invalid hop charge."
		"HazardEvent":
			if not m.get("kind") in ["hazard","fire","disconnect","overpressure"] or m.get("safe_state") != true: return "Invalid hazard safe-state."
		"HardwareFrame":
			if not m.get("enabled") is bool or not m.get("safe_state") is bool: return "Missing interlock."
			if not number(m.get("heater"),0,1) or not number(m.get("pump"),0,1): return "Invalid actuator."
			if (m.safe_state or not m.enabled) and (m.heater != 0 or m.pump != 0): return "Unsafe actuator output."
		"JudgeResult":
			if not m.get("batch_id") is String or not m.get("categories") is Dictionary or not m.get("feedback") is Array or not m.get("severe_flaws") is Array: return "Invalid judging payload."
			var total := 0.0
			for k in ["aroma","appearance","flavor","mouthfeel","style_accuracy"]:
				if not number(m.categories.get(k),0,20): return "Invalid category."
				total += m.categories[k]
			if not number(m.get("score"),0,100) or abs(total-m.score) > .001: return "Score must equal categories."
		_: return "Unsupported message type."
	return ""

func decode(raw: String) -> Dictionary:
	if raw.length() > 1000000: return {"ok":false,"error":"Message too large."}
	var parsed := JSON.new()
	if parsed.parse(raw) != OK: return {"ok":false,"error":"Malformed JSON."}
	var err := validate(parsed.data)
	return {"ok":err.is_empty(),"error":err,"message":parsed.data}
