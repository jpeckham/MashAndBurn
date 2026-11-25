extends RefCounted
## Fictional abstract game fields and evidence, not a model of real ignition or claims.
const WINDOW := 45.0

func initial() -> Dictionary:
	return {"phase":"idle","remaining":0.0,"heat":0.0,"fuel":1.0,"smoke":0.0,"cause":"","spread":false,"objects":{"receipt":false,"equipment":false,"evidence":false}}

func ignite(s: Dictionary, who: int, cause: String, emit: Callable, disarm: Callable) -> String:
	var p: Dictionary = s.players[who]
	if cause not in ["boil_over","cord","dust"]: return "Unsupported fictional ignition category."
	if p.fire.phase != "idle": return "This bay already has a fire incident."
	p.fire = initial()
	p.fire.merge({"phase":"staging","remaining":WINDOW,"heat":.25,"smoke":.05,"cause":cause},true)
	# Hardware consumers must observe the latch before any visual or claims event.
	disarm.call(s,who,"fire")
	emit.call(s,"fire",who,{"cause":cause,"window_seconds":WINDOW})
	return ""

func stage(p: Dictionary, object: String) -> String:
	if p.fire.phase != "staging" or p.fire.remaining <= 0: return "The staging window is closed."
	if p.escaped or p.health <= 0: return "An escaped or incapacitated player cannot stage objects."
	if object not in p.fire.objects: return "Unsupported fictional evidence object."
	if p.fire.objects[object]: return "This object has already been staged."
	p.fire.objects[object] = true
	return ""

func escape(p: Dictionary) -> String:
	if p.fire.phase != "staging" or p.health <= 0 or p.escaped: return "No living indoor escape is available."
	if p.position[1] < 4.8: return "Reach the marked garage exit first."
	p.escaped = true
	p.move = [0.0,0.0]
	return ""

func advance(s: Dictionary, dt: float, emit: Callable, disarm: Callable) -> void:
	var spread: Array = []
	for who in s.players.keys():
		var p: Dictionary = s.players[who]
		if p.fire.phase != "staging": continue
		p.fire.remaining = maxf(0,p.fire.remaining-dt)
		if p.fire.remaining < .000001: p.fire.remaining = 0.0
		p.fire.fuel = maxf(0,p.fire.fuel-dt*.005)
		p.fire.heat = clampf(p.fire.heat+dt*.014,0,1)
		p.fire.smoke = clampf(p.fire.smoke+dt*.035,0,1)
		if not p.escaped:
			p.health = maxf(0,p.health-dt*(2+8*p.fire.smoke))
			if p.health == 0: p.move = [0.0,0.0]
		if p.fire.heat >= .75 and not p.fire.spread:
			p.fire.spread = true
			for neighbor in [who-1,who+1]:
				if s.players.has(neighbor) and s.players[neighbor].fire.phase == "idle": spread.append(neighbor)
		if p.fire.remaining == 0: inspect(s,who,emit)
	for who in spread:
		if s.players[who].fire.phase == "idle": ignite(s,who,"boil_over",emit,disarm)

func inspect(s: Dictionary, who: int, emit: Callable) -> void:
	var p: Dictionary = s.players[who]
	if p.claim.resolved: return
	var o: Dictionary = p.fire.objects
	var confidence := .15+.25*int(o.receipt)+.25*int(o.equipment)+.25*int(o.evidence)+.25*int(p.escaped)
	confidence -= .25 if p.redline else 0.0
	confidence -= .15 if p.fire.cause == "dust" else .05
	var rng := RandomNumberGenerator.new()
	rng.seed = s.seed+who*7919
	var passed: bool = p.health > 0 and p.escaped and rng.randf() < clampf(confidence,0,1)
	var payout: int = int(p.replacement*1.5) if passed else 0
	var penalty: int = 0 if passed else int(p.replacement*1.5)
	p.money = maxi(0,p.money+payout-penalty)
	p.bankrupt = not passed and p.money == 0
	p.claim = {"resolved":true,"passed":passed,"payout":payout,"penalty":penalty,"confidence":clampf(confidence,0,1),"reason":"Fictional inspection accepted the staged record." if passed else "Inspection failed: escape, smoke, burn pattern, valve or staged record was inconsistent."}
	p.fire.phase = "resolved"
	emit.call(s,"claim",who,p.claim.duplicate(true))
