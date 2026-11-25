extends RefCounted
## Read-only simulated telemetry. This producer never authorizes companion arming.
const Protocol = preload("res://src/contracts/protocol.gd")
const STEPS = {"mash":"MASH_IN","boil":"BOIL","cooling":"COOL","fermentation":"FERMENT","packaging":"PACKAGE","judging":"JUDGE"}
var enabled := false
var latched := false
var fault := ""
var seq := 0
var accumulated := 0.0
var last_timestamp := -1
var observed_batch := ""
var observed_hops := 0

func set_enabled(value: bool) -> void:
	enabled = value
	accumulated = 0.0
	latched = not value
	fault = "" if value else "disabled"

func finite(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func trip(reason: String) -> void:
	latched = true
	fault = reason

func fault_reason(state: Dictionary, context: Dictionary) -> String:
	if not Protocol.new().validate(state).is_empty(): return "malformed-batch"
	for field in ["connected","estop","sensor_ok","paused"]:
		if context.has(field) and not context[field] is bool: return "malformed-context"
	if not context.get("connected",true): return "disconnect"
	if context.get("estop",false): return "e-stop"
	var sensor = context.get("sensor_temp_c",state.temp_c)
	if not context.get("sensor_ok",true) or not finite(sensor) or sensor < -20 or sensor > 130: return "sensor-error"
	if sensor >= 102: return "thermal-cutoff"
	if context.get("hazard","none") not in ["none","hazard","fire","disconnect","overpressure"] or context.get("fire_phase","idle") not in ["idle","staging","resolved"]: return "malformed-context"
	if state.safe_state or context.get("hazard","none") != "none" or context.get("fire_phase","idle") == "staging": return "hazard"
	return ""

func make_frame(state: Dictionary, context: Dictionary, unix_ms: int) -> Dictionary:
	var reason := fault_reason(state,context)
	if not reason.is_empty(): trip(reason)
	if unix_ms < 0 or unix_ms < last_timestamp: trip("clock-regression")
	if seq >= 2147483647: trip("sequence-exhausted")
	else: seq += 1
	last_timestamp = maxi(last_timestamp,unix_ms)
	var stage: String = str(state.get("stage",""))
	var paused: bool = context.get("paused",false) == true
	var active := enabled and not latched and not paused
	var target := clampf(float(state.get("target_c",20)),0,100) if finite(state.get("target_c")) else 20.0
	var sensor = context.get("sensor_temp_c",state.get("temp_c"))
	var sensor_valid := finite(sensor) and float(sensor) >= -20 and float(sensor) <= 130
	var sensor_ok: bool = context.get("sensor_ok",true) == true and sensor_valid
	var heater := clampf((target-float(sensor))/5.0,0,1) if active and sensor_valid and stage in ["mash","boil"] else 0.0
	var pump := 0.0
	if active:
		if stage == "mash": pump = .85
		elif stage == "cooling": pump = clampf(float(state.chiller),0,1)
	var batch: String = str(state.get("batch_id",""))
	var hops: int = state.get("hops",[]).size() if state.get("hops") is Array else 0
	var hopper = null
	if observed_batch == batch and active and stage == "boil" and hops > observed_hops: hopper = mini(3,hops-1)
	observed_batch = batch
	observed_hops = hops
	var hazard: String = str(context.get("hazard","none"))
	if hazard not in ["none","hazard","fire","disconnect","overpressure"]: hazard = "hazard"
	if latched and hazard == "none": hazard = "disconnect" if fault == "disconnect" else "hazard"
	var fire_phase: String = str(context.get("fire_phase","idle"))
	if fire_phase not in ["idle","staging","resolved"]: fire_phase = "idle"
	return {"type":"HardwareFrame","version":1,"seq":seq,"tick":int(state.get("tick",0)) if finite(state.get("tick")) and state.get("tick",0) >= 0 and state.get("tick",0) <= 2147483647 else 0,"sent_at_unix_ms":maxi(0,unix_ms),"step":STEPS.get(stage,"IDLE"),"enabled":enabled and not paused,"safe_state":latched,"heater":heater,"pump":pump,"target_temp_c":target,"pump_duty":pump,"valve_states":[1,0,1] if pump > 0 else [0,0,0],"hop_drop_hopper":hopper,"sensor_temp_c":float(sensor) if sensor_valid else null,"sensor_ok":sensor_ok,"connected":context.get("connected",true) == true,"estop":context.get("estop",false) == true,"hazard":hazard,"fire_phase":fire_phase}

func advance(delta: float, state: Dictionary, context: Dictionary, unix_ms: int) -> Array:
	if not is_finite(delta) or delta < 0 or delta > .3:
		trip("missed-process-heartbeat")
		accumulated = 0.0
		return [make_frame(state,context,unix_ms)]
	if not latched and not fault_reason(state,context).is_empty():
		accumulated = 0.0
		return [make_frame(state,context,unix_ms)]
	accumulated += delta
	if accumulated+.0000001 < .1: return []
	accumulated = fposmod(accumulated,.1)
	return [make_frame(state,context,unix_ms)]
