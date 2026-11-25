extends RefCounted
## Bounded artistic RGB absorption, not measured spectral optics or fluid physics.

func bounded(input: Dictionary, key: String, fallback: float, low: float, high: float) -> float:
	var value = input.get(key,fallback)
	if not (value is float or value is int) or not is_finite(float(value)): return fallback
	return clampf(float(value),low,high)

func parameters(input: Dictionary, renderer: String) -> Dictionary:
	var srm := bounded(input,"srm",10.0,2.0,50.0)
	var haze := bounded(input,"haze",.15,0.0,1.0)
	var protein := bounded(input,"protein",.5,0.0,1.0)
	var ibu := bounded(input,"ibu",20.0,0.0,120.0)
	var co2 := bounded(input,"co2",.85,0.0,4.0)
	var temp := bounded(input,"temp_c",20.0,0.0,102.0)
	var color := Color(exp(-srm*.06),exp(-srm*.18),exp(-srm*.38))
	var foam := clampf((.12+protein*.58+ibu/120.0*.30)*(co2/2.5),0.0,1.0)
	var tier := renderer if renderer in ["forward_plus","mobile"] else "compatibility"
	return {"srm":srm,"color":color,"haze":haze,"foam":foam,"bubbles":clampf(co2/3.0,0,1),"steam":clampf((temp-55)/45.0,0,1),"condensation":clampf((temp-25)/65.0,0,1),"tier":tier,"reflection_probe":tier != "compatibility"}

func from_batch(state: Dictionary, renderer: String) -> Dictionary:
	# Protocol v1 has no malt color or protein analysis: use explicit artistic estimates.
	var grain := bounded(state,"grain_kg",5,0,20)
	var volume := bounded(state,"volume_l",20,.1,100)
	var flaws: Dictionary = state.get("flaws",{}) if state.get("flaws",{}) is Dictionary else {}
	var loading := clampf(grain/volume,0,1)
	var input := {"srm":2+loading*28+bounded(flaws,"astringency",0,0,1)*25,"haze":1-bounded(state,"flocculation",0,0,1),"protein":clampf(loading*2,0,1),"ibu":bounded(state,"ibu",0,0,120),"co2":bounded(state,"co2_volumes",.85,0,4),"temp_c":bounded(state,"temp_c",20,0,102)}
	return parameters(input,renderer)
