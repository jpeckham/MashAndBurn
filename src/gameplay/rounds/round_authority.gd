extends RefCounted
## Pure, deterministic server rules. All physical effects here are fictional game units.
const Simulation = preload("res://src/chemistry/brewing_simulation.gd")
const Protocol = preload("res://src/contracts/protocol.gd")
const Judge = preload("res://src/social/beer_judge.gd")
const Fire = preload("res://src/gameplay/fire/fire_claims.gd")
const TICK := .1
const ROUND_TICKS := 9000
const MAX_PLAYERS := 8
const WEAPONS = {"wand":{"range":4.0,"cooldown":1.0,"damage":0.0},"ladle":{"range":2.0,"cooldown":1.2,"damage":18.0},"hydrometer":{"range":1.5,"cooldown":.8,"damage":25.0},"keg":{"range":9.0,"cooldown":3.0,"damage":34.0},"bottle":{"range":7.0,"cooldown":2.5,"damage":26.0}}
const STYLES = {"pale_ale":{"ibu":35.0,"og":1.055},"lager":{"ibu":22.0,"og":1.048},"stout":{"ibu":45.0,"og":1.065}}
var sim := Simulation.new()
var protocol := Protocol.new()
var judge := Judge.new()
var fire := Fire.new()

func initial_state(seed_value: int, host_peer: int = 1) -> Dictionary:
	return {"version":1,"round_id":"round-%d" % seed_value,"seed":seed_value,"host_peer":host_peer,"phase":"lobby","tick":0,"elapsed":0.0,"style":"pale_ale","players":{},"peer_players":{},"credentials":{},"projectiles":[],"projectile_seq":0,"events":[],"event_id":0,"hardware_safe":false,"results":[]}

func rejected(s: Dictionary, error: String) -> Dictionary:
	return {"ok":false,"state":s.duplicate(true),"events":[],"error":error}

func accepted(s: Dictionary, prior: int) -> Dictionary:
	return {"ok":true,"state":s,"events":s.events.filter(func(e): return e.id > prior),"error":""}

func emit(s: Dictionary, kind: String, who: int, details: Dictionary = {}) -> void:
	s.event_id += 1
	s.events.append({"id":s.event_id,"tick":s.tick,"kind":kind,"player":who,"details":details})
	if s.events.size() > 64: s.events.pop_front()

func disarm(s: Dictionary, who: int, reason: String) -> void:
	s.hardware_safe = true
	s.players[who].batch.safe_state = true
	emit(s,"disarm",who,{"type":"HazardEvent","version":1,"seq":s.event_id+1,"tick":s.tick,"kind":reason,"safe_state":true})

func snapshot(s: Dictionary) -> Dictionary:
	var view: Dictionary = s.duplicate(true)
	view.erase("credentials")
	view.erase("peer_players")
	view.erase("host_peer")
	for p in view.players.values(): p.erase("peer")
	return view

func join(state: Dictionary, peer: int, player_name: String, token: String, reconnect: bool = false) -> Dictionary:
	if peer <= 0 or state.peer_players.has(peer): return rejected(state,"Peer already joined or invalid.")
	if token.length() < 12 or token.length() > 128: return rejected(state,"Invalid reconnect credential.")
	var s: Dictionary = state.duplicate(true)
	var who := 0
	if reconnect:
		if not s.credentials.has(token): return rejected(state,"Invalid reconnect credential.")
		who = s.credentials[token]
		if not s.players.has(who) or s.players[who].connected or s.phase == "finished": return rejected(state,"This identity cannot reconnect.")
		s.players[who].peer = peer
		s.players[who].connected = true
	else:
		if s.phase != "lobby": return rejected(state,"Round already started; fresh late joins are disabled.")
		if s.players.size() >= MAX_PLAYERS: return rejected(state,"Lobby full (maximum eight participants).")
		if s.credentials.has(token): return rejected(state,"Duplicate reconnect credential.")
		if player_name.strip_edges().is_empty() or player_name.length() > 32: return rejected(state,"Use a name of 1–32 characters.")
		for id in range(1,MAX_PLAYERS+1):
			if not s.players.has(id):
				who = id
				break
		var batch: Dictionary = sim.initial_state((s.seed+who*101)%2147483647)
		batch.batch_id = "%s-player-%d" % [s.round_id,who]
		s.players[who] = {"id":who,"peer":peer,"name":player_name.strip_edges(),"connected":true,"ready":false,"seq":0,"position":[float((who-1)%4)*3.0-4.5,1.0+float((who-1)/4)*2.0],"move":[0.0,0.0],"last_move_tick":0,"health":100.0,"blind_until":0.0,"slip_until":0.0,"cooldowns":{},"redline":false,"batch":batch,"escaped":false,"fire":fire.initial(),"claim":{"resolved":false,"passed":false,"payout":0,"penalty":0},"money":1000,"replacement":1000,"bankrupt":false}
		s.credentials[token] = who
	s.peer_players[peer] = who
	emit(s,"joined",who,{"reconnected":reconnect})
	var result := accepted(s,state.event_id)
	result.player_id = who
	result.resume_token = token
	return result

func disconnect_peer(state: Dictionary, peer: int) -> Dictionary:
	if not state.peer_players.has(peer): return rejected(state,"Unknown peer.")
	var s: Dictionary = state.duplicate(true)
	var who: int = s.peer_players[peer]
	s.peer_players.erase(peer)
	if s.phase == "lobby":
		s.players.erase(who)
		for token in s.credentials.keys():
			if s.credentials[token] == who: s.credentials.erase(token)
	else:
		s.players[who].connected = false
		s.players[who].move = [0.0,0.0]
		disarm(s,who,"disconnect")
		for i in range(s.projectiles.size()-1,-1,-1):
			if s.projectiles[i].owner == who: s.projectiles.remove_at(i)
	emit(s,"disconnected",who)
	return accepted(s,state.event_id)

func begin(state: Dictionary, peer: int, style: String = "pale_ale") -> Dictionary:
	if peer != state.host_peer: return rejected(state,"Only the host may start the round.")
	if state.phase != "lobby" or state.players.size() < 2: return rejected(state,"A round needs 2–8 participants in the lobby.")
	if style not in STYLES: return rejected(state,"Unsupported judging style.")
	for p in state.players.values():
		if not p.ready or not p.connected: return rejected(state,"Every participant must be ready.")
	var s: Dictionary = state.duplicate(true)
	s.phase = "running"
	s.style = style
	if style == "lager":
		for p in s.players.values(): p.batch.yeast = "lager"
	emit(s,"round_started",0,{"duration_seconds":900,"style":style})
	return accepted(s,state.event_id)

func valid_number(value, lo: float, hi: float) -> bool:
	return protocol.number(value,lo,hi)

func distance(a: Dictionary, b: Dictionary) -> float:
	return Vector2(a.position[0],a.position[1]).distance_to(Vector2(b.position[0],b.position[1]))

func submit(state: Dictionary, peer: int, command) -> Dictionary:
	if not state.peer_players.has(peer): return rejected(state,"Unknown sender.")
	if not command is Dictionary: return rejected(state,"Command must be an object.")
	var who: int = state.peer_players[peer]
	var player: Dictionary = state.players[who]
	if command.get("version") != 1 or command.get("round_id") != state.round_id: return rejected(state,"Unsupported command version or round.")
	if not valid_number(command.get("seq"),1,2147483647) or command.seq != player.seq+1: return rejected(state,"Expected the next consecutive input sequence.")
	if not valid_number(command.get("tick"),maxi(0,state.tick-30),state.tick) or float(command.tick) != floor(float(command.tick)): return rejected(state,"Stale, future or invalid command tick.")
	var action = command.get("action")
	var allowed := {"ready":["ready"],"move":["direction"],"brew":["command"],"attack":["weapon","target"],"sabotage":["kind","target"],"ignite":["cause"],"stage":["object"],"escape":[]}
	if action not in allowed: return rejected(state,"Unsupported gameplay action.")
	for key in command:
		if key not in ["version","round_id","seq","tick","action"] and key not in allowed[action]: return rejected(state,"Unsupported command field.")
	if state.phase == "finished": return rejected(state,"The round has finished.")
	if state.phase == "settling" and action not in ["move","stage","escape"]: return rejected(state,"Competition ended; only staging and escape remain.")
	if action == "ready":
		if state.phase != "lobby" or not command.get("ready") is bool: return rejected(state,"Ready status requires a lobby and boolean.")
	elif state.phase not in ["running","settling"] and action != "brew": return rejected(state,"Wait for the host to start the round.")
	elif player.health <= 0 or player.escaped or not player.connected: return rejected(state,"This player cannot act.")
	var s: Dictionary = state.duplicate(true)
	var p: Dictionary = s.players[who]
	var error := ""
	match action:
		"ready": p.ready = command.ready
		"move":
			var direction = command.get("direction")
			if not direction is Array or direction.size() != 2 or not valid_number(direction[0],-1,1) or not valid_number(direction[1],-1,1): return rejected(state,"Invalid movement intent.")
			if Vector2(direction[0],direction[1]).length() > 1.001: return rejected(state,"Movement intent exceeds unit length.")
			p.move = direction.duplicate()
			p.last_move_tick = s.tick
		"brew": error = brew(s,who,command.get("command"))
		"attack", "sabotage":
			var target = command.get("target")
			if not target is int and not target is float: return rejected(state,"Invalid target.")
			if not valid_number(target,1,MAX_PLAYERS) or float(target) != floor(float(target)): return rejected(state,"Invalid target.")
			target = int(target)
			if not s.players.has(target) or target == who or not s.players[target].connected or s.players[target].health <= 0 or s.players[target].escaped: return rejected(state,"Target is unavailable.")
			error = attack(s,who,int(target),command.get("weapon")) if action == "attack" else sabotage(s,who,int(target),command.get("kind"))
		"ignite":
			if not command.get("cause") is String: return rejected(state,"Invalid ignition category.")
			error = fire.ignite(s,who,command.cause,emit,disarm)
		"stage":
			if not command.get("object") is String: return rejected(state,"Invalid staging object.")
			if s.tick*TICK < p.cooldowns.get("stage",0.0): return rejected(state,"Staging cooldown is active.")
			error = fire.stage(p,command.object)
			if error.is_empty(): p.cooldowns.stage = s.tick*TICK+1
		"escape": error = fire.escape(p)
	if not error.is_empty(): return rejected(state,error)
	p.seq = int(command.seq)
	emit(s,"input",who,{"action":action,"seq":p.seq})
	return accepted(s,state.event_id)

func brew(s: Dictionary, who: int, input) -> String:
	var p: Dictionary = s.players[who]
	if p.batch.safe_state: return "This bay has a latched safety shutdown."
	if not input is Dictionary or input.get("action") not in ["set","add_hops","next"]: return "Unsupported brewing intent."
	var fields: Array = {"set":["action","field","value"],"add_hops":["action","grams","alpha"],"next":["action"]}[input.action]
	for key in input:
		if key not in fields: return "Unsupported brewing field."
	if s.tick*TICK < p.cooldowns.get("brew",0.0): return "Brewing command cooldown is active."
	if s.phase == "lobby":
		if input.action != "set": return "Only recipe settings can change in the lobby."
		var c: Dictionary = input.duplicate(true)
		c.merge({"type":"PlayerCommand","version":1,"tick":p.batch.tick,"seq":p.batch.seq+1})
		var error: String = protocol.validate(c)
		if not error.is_empty(): return error
		p.batch[input.field] = input.value
	else:
		var result: Dictionary = sim.advance(p.batch,input,60.0)
		if not result.ok: return result.error
		p.batch = result.state
		for hazard in result.events: disarm(s,who,hazard.kind)
		# Broken cooling equipment cannot be repaired by sending an arbitrary setting.
		if p.get("broken_chiller",false): p.batch.chiller = 0.0
		if p.redline: p.batch.target_c = 100.0 if p.batch.stage in ["mash","boil"] else p.batch.target_c
	p.cooldowns.brew = s.tick*TICK+.2
	return ""

func attack(s: Dictionary, who: int, target: int, weapon) -> String:
	if weapon not in WEAPONS: return "Unsupported weapon."
	var p: Dictionary = s.players[who]
	var victim: Dictionary = s.players[target]
	var spec: Dictionary = WEAPONS[weapon]
	if distance(p,victim) > spec.range: return "Target is out of weapon range."
	if s.tick*TICK < p.cooldowns.get("attack",0.0): return "Weapon cooldown is active."
	if weapon in ["keg","bottle"]:
		if s.projectiles.filter(func(projectile): return projectile.owner == who).size() >= 2: return "Too many active projectiles."
		var origin := Vector2(p.position[0],p.position[1])
		var direction := (Vector2(victim.position[0],victim.position[1])-origin).normalized()
		if direction == Vector2.ZERO: direction = Vector2.RIGHT
		s.projectile_seq += 1
		s.projectiles.append({"id":s.projectile_seq,"owner":who,"weapon":weapon,"position":[origin.x,1.2,origin.y],"velocity":[direction.x*8,2.0,direction.y*8],"age":0.0})
	elif weapon == "wand":
		victim.blind_until = s.tick*TICK+2.0
		victim.slip_until = s.tick*TICK+4.0
	else: damage(s,target,spec.damage,who,weapon)
	p.cooldowns.attack = s.tick*TICK+spec.cooldown
	emit(s,"attack",who,{"weapon":weapon,"target":target})
	return ""

func sabotage(s: Dictionary, who: int, target: int, kind) -> String:
	if kind not in ["chiller","contamination","burner"]: return "Unsupported sabotage category."
	var p: Dictionary = s.players[who]
	var victim: Dictionary = s.players[target]
	if distance(p,victim) > 3: return "Move within three game metres of the rival."
	if s.tick*TICK < p.cooldowns.get("sabotage",0.0): return "Sabotage cooldown is active."
	match kind:
		"chiller":
			victim.batch.chiller = 0.0
			victim.broken_chiller = true
		"contamination":
			victim.batch.infection_risk = 1.0
			victim.batch.infected = true
		"burner":
			victim.redline = true
			victim.batch.target_c = 100.0
			victim.batch.vigor = 1.0
	p.cooldowns.sabotage = s.tick*TICK+5.0
	emit(s,"sabotage",who,{"kind":kind,"target":target})
	return ""

func damage(s: Dictionary, target: int, amount: float, owner: int, weapon: String) -> void:
	var p: Dictionary = s.players[target]
	p.health = clampf(p.health-clampf(amount,0,100),0,100)
	if p.health == 0:
		p.move = [0.0,0.0]
		if not p.batch.safe_state: disarm(s,target,"hazard")
	emit(s,"damage",target,{"amount":amount,"owner":owner,"weapon":weapon})

func advance(state: Dictionary, dt: float) -> Dictionary:
	if not is_finite(dt) or not is_equal_approx(dt,TICK): return rejected(state,"Expected one fixed 0.1-second server tick.")
	if state.phase not in ["running","settling"]: return rejected(state,"Only a running round or active claims settlement advances.")
	var s: Dictionary = state.duplicate(true)
	s.tick += 1
	s.elapsed = minf(900,s.tick*TICK)
	for who in s.players.keys():
		var p: Dictionary = s.players[who]
		if p.connected and p.health > 0 and not p.escaped:
			# Missing movement input times out; disconnect cannot leave a player walking.
			if s.tick-p.last_move_tick > 5: p.move = [0.0,0.0]
			var speed := 1.2 if p.slip_until > s.tick*TICK else 3.0
			p.position[0] = clampf(p.position[0]+p.move[0]*dt*speed,-6.5,6.5)
			p.position[1] = clampf(p.position[1]+p.move[1]*dt*speed,-.5,6)
			if s.phase == "running" and not p.batch.safe_state and p.batch.stage != "judging":
				var result: Dictionary = sim.advance(p.batch,{},60.0)
				if result.ok: p.batch = result.state
				else: disarm(s,who,"hazard")
				for hazard in result.events: disarm(s,who,hazard.kind)
			if s.phase == "running" and p.redline and p.batch.stage == "boil" and p.batch.temp_c >= 95 and p.fire.phase == "idle": fire.ignite(s,who,"boil_over",emit,disarm)
	if s.phase == "running": advance_projectiles(s,dt)
	fire.advance(s,dt,emit,disarm)
	if s.tick >= ROUND_TICKS:
		if s.players.values().any(func(p): return p.fire.phase == "staging"):
			if s.phase != "settling":
				s.phase = "settling"
				s.projectiles.clear()
				for who in s.players:
					if not s.players[who].batch.safe_state: disarm(s,who,"disconnect")
				emit(s,"round_clock_expired",0,{"claims_pending":true})
		else: finish(s)
	return accepted(s,state.event_id)

func advance_projectiles(s: Dictionary, dt: float) -> void:
	for i in range(s.projectiles.size()-1,-1,-1):
		var projectile: Dictionary = s.projectiles[i]
		projectile.age += dt
		projectile.velocity[1] -= 7*dt
		for axis in range(3): projectile.position[axis] += projectile.velocity[axis]*dt
		var explode: bool = projectile.position[1] <= 0 or projectile.age >= 4
		var point := Vector2(projectile.position[0],projectile.position[2])
		for who in s.players:
			var p: Dictionary = s.players[who]
			if who != projectile.owner and p.connected and not p.escaped and p.health > 0 and point.distance_to(Vector2(p.position[0],p.position[1])) <= .8 and projectile.position[1] <= 2.2: explode = true
		if not explode: continue
		var radius := 2.2 if projectile.weapon == "keg" else 1.8
		for who in s.players:
			var p: Dictionary = s.players[who]
			if who != projectile.owner and p.connected and not p.escaped and point.distance_to(Vector2(p.position[0],p.position[1])) <= radius: damage(s,who,WEAPONS[projectile.weapon].damage,projectile.owner,projectile.weapon)
		emit(s,"projectile_impact",projectile.owner,{"weapon":projectile.weapon,"position":projectile.position.duplicate()})
		s.projectiles.remove_at(i)

func finish(s: Dictionary) -> void:
	s.phase = "finished"
	s.projectiles.clear()
	for who in s.players:
		var p: Dictionary = s.players[who]
		p.move = [0.0,0.0]
		var result: Dictionary = judge.evaluate(p.batch)
		var target: Dictionary = STYLES[s.style]
		result.categories.style_accuracy = snappedf(clampf(20-absf(p.batch.ibu-target.ibu)*.25-absf(p.batch.og-target.og)*150-(1-p.batch.attenuation)*8,0,20),.1)
		result.feedback = result.feedback.filter(func(line): return not line.begins_with("Low bitterness for the pale-ale") and not line.begins_with("Bitterness dominates"))
		result.feedback.append("Round style target: %s, %.0f IBU / OG %.3f." % [s.style,target.ibu,target.og])
		if p.batch.stage != "judging":
			for category in result.categories: result.categories[category] = snappedf(result.categories[category]*.25,.1)
			result.feedback.append("Incomplete packaging: category scores reduced to 25%.")
		if p.health <= 0:
			for category in result.categories: result.categories[category] = 0.0
			result.feedback.append("Incapacitated: this round's tasting score is zero.")
		result.score = 0.0
		for score in result.categories.values(): result.score += score
		result.score = snappedf(result.score,.1)
		s.results.append({"player":who,"name":p.name,"judge":result,"health":p.health,"money":p.money,"claim":p.claim.duplicate(true)})
		if not p.batch.safe_state: disarm(s,who,"disconnect")
	s.results.sort_custom(func(a,b): return a.judge.score > b.judge.score if a.judge.score != b.judge.score else a.player < b.player)
	emit(s,"round_finished",0,{"winner":s.results[0].player if not s.results.is_empty() else 0})
