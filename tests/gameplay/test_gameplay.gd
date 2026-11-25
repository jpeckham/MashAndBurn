extends RefCounted

func command(s: Dictionary, who: int, action: String, data: Dictionary = {}) -> Dictionary:
	var c := data.duplicate(true)
	c.merge({"version":1,"round_id":s.round_id,"seq":s.players[who].seq+1,"tick":s.tick,"action":action})
	return c

func lobby(engine, count: int = 2) -> Dictionary:
	var s: Dictionary = engine.initial_state(812)
	for peer in range(1,count+1):
		s = engine.join(s,peer,"Brewer %d" % peer,"private-token-%d" % peer).state
	for who in s.players.keys():
		s = engine.submit(s,s.players[who].peer,command(s,who,"ready",{"ready":true})).state
	return s

func running(engine, count: int = 2) -> Dictionary:
	return engine.begin(lobby(engine,count),1).state

func run(t) -> void:
	var path := "res://src/gameplay/rounds/round_authority.gd"
	if not FileAccess.file_exists(path):
		t.check(false,"authoritative multiplayer rounds, combat and fire implemented")
		return
	var engine = load(path).new()
	var s: Dictionary = engine.initial_state(812)
	t.check(not engine.begin(s,1).ok,"cannot start empty or solo lobby")
	for peer in range(1,9):
		var result: Dictionary = engine.join(s,peer,"Brewer %d" % peer,"private-token-%d" % peer)
		t.check(result.ok,"lobby accepts participant %d" % peer)
		s = result.state
	t.check(not engine.join(s,9,"Overflow","private-token-9").ok,"reject ninth participant")
	t.check(not engine.join(s,1,"Duplicate","another-token").ok,"duplicate peer cannot reset identity")
	t.check(not engine.begin(s,2).ok,"only host can start")
	t.check(not engine.begin(s,1).ok,"all players must ready")
	var public: Dictionary = engine.snapshot(s)
	t.check(not JSON.stringify(public).contains("private-token"),"snapshots never leak reconnect credentials")
	public.players[1].health = 0
	t.check(s.players[1].health == 100,"snapshots do not alias authoritative state")
	s = running(engine)
	t.check(s.phase == "running" and s.elapsed == 0,"ready two-player round starts at zero")
	t.check(not engine.join(s,3,"Late","private-token-3").ok,"active round rejects fresh late join")
	var valid := command(s,1,"move",{"direction":[1.0,0.0]})
	var moved: Dictionary = engine.submit(s,1,valid)
	t.check(moved.ok and moved.state.players[1].seq == 2,"server accepts next bounded intent")
	t.check(not engine.submit(moved.state,1,valid).ok,"duplicate input rejected")
	for change in [{"seq":999},{"tick":999},{"tick":-1},{"version":2},{"round_id":"forged"},{"action":"award_money","amount":99999},{"damage":99999},{"target":2},{"direction":[INF,0]},{"direction":[2,0]}]:
		var bad := valid.duplicate(true)
		for k in change: bad[k] = change[k]
		var result: Dictionary = engine.submit(s,1,bad)
		t.check(not result.ok,"reject malformed/forged command " + str(change))
		t.check(result.state == s,"rejected input preserves authoritative state")
	t.check(not engine.submit(s,99,valid).ok,"unknown sender cannot submit")
	var before_x: float = moved.state.players[1].position[0]
	var advanced: Dictionary = engine.advance(moved.state,.1)
	t.check(advanced.ok and advanced.state.players[1].position[0] <= before_x+.30001,"server integrates bounded movement")
	t.check(not engine.advance(s,0).ok and not engine.advance(s,INF).ok and not engine.advance(s,.2).ok,"fixed tick rejects invalid delta")
	var brew := command(s,1,"brew",{"command":{"action":"set","field":"target_c","value":70.0}})
	var brewed: Dictionary = engine.submit(s,1,brew)
	t.check(brewed.ok and brewed.state.players[1].batch.target_c == 70,"own batch settings are authoritative")
	t.check(brewed.state.players[2].batch.target_c == 66.7,"own brew command cannot change rival batch")
	t.check(brewed.state.players[1].batch.sim_seconds == s.players[1].batch.sim_seconds and brewed.state.players[1].batch.tick == s.players[1].batch.tick,"accepted settings never advance server-owned batch time")
	t.check(brewed.state.players[1].batch.temp_c == s.players[1].batch.temp_c,"setting a target does not instantly heat the batch")
	brew.command.value = 900
	t.check(not engine.submit(s,1,brew).ok,"chemistry bounds apply to multiplayer")
	var control := running(engine)
	var spam := running(engine)
	for tick in range(20):
		if tick%2 == 0: spam = engine.submit(spam,1,command(spam,1,"brew",{"command":{"action":"set","field":"target_c","value":66.7}})).state
		control = engine.advance(control,.1).state
		spam = engine.advance(spam,.1).state
	t.check(control.players[1].batch.sim_seconds == spam.players[1].batch.sim_seconds and control.players[1].batch.conversion == spam.players[1].batch.conversion,"input frequency cannot buy faster brewing")
	var cooling := running(engine)
	cooling.players[1].batch.stage = "cooling"
	cooling.players[1].batch.temp_c = 100.0
	cooling = engine.submit(cooling,2,command(cooling,2,"sabotage",{"kind":"chiller","target":1})).state
	var direct: Dictionary = engine.submit(cooling,1,command(cooling,1,"brew",{"command":{"action":"set","field":"temp_c","value":20.0}}))
	t.check(not direct.ok and direct.state.players[1].batch.temp_c == 100,"client cannot set measured temperature to bypass cooling")
	var override: Dictionary = engine.submit(cooling,1,command(cooling,1,"brew",{"command":{"action":"set","field":"chiller","value":1.0}}))
	t.check(not override.ok and override.state.players[1].batch.temp_c == 100,"broken chiller cannot provide one hidden cooling step")
	var redline := running(engine)
	redline = engine.submit(redline,2,command(redline,2,"sabotage",{"kind":"burner","target":1})).state
	t.check(not engine.submit(redline,1,command(redline,1,"brew",{"command":{"action":"set","field":"target_c","value":20.0}})).ok,"redline constraint cannot be overridden between ticks")
	var gone: Dictionary = engine.disconnect_peer(s,2)
	t.check(not gone.state.players[2].connected and gone.state.players[2].batch.safe_state,"disconnect stops that bay safely")
	t.check(not engine.join(gone.state,20,"Stolen","wrong-token",true).ok,"reconnect requires credential")
	var back: Dictionary = engine.join(gone.state,20,"Ignored","private-token-2",true)
	t.check(back.ok and back.player_id == 2 and back.state.players[2].seq == s.players[2].seq,"reconnect preserves identity/order")
	t.check(back.state.players[2].batch.safe_state,"reconnect cannot clear safety latch")
	t.check(not engine.submit(back.state,2,command(back.state,2,"move",{"direction":[0,0]})).ok,"old peer loses authority after reconnect")
	var freed: Dictionary = engine.disconnect_peer(lobby(engine),2)
	t.check(freed.state.players.size() == 1,"lobby disconnect releases slot")
	for weapon in ["wand","ladle","hydrometer","keg","bottle"]:
		var fight := running(engine)
		fight.players[1].position = [0.0,0.0]
		fight.players[2].position = [.8,0.0]
		var attack := command(fight,1,"attack",{"weapon":weapon,"target":2})
		var hit: Dictionary = engine.submit(fight,1,attack)
		t.check(hit.ok,"server accepts arsenal " + weapon)
		t.check(not engine.submit(hit.state,1,command(hit.state,1,"attack",{"weapon":weapon,"target":2})).ok,"weapon cooldown cannot be bypassed " + weapon)
		for i in range(10): hit = engine.advance(hit.state,.1)
		t.check(hit.state.players[2].health < 100 or hit.state.players[2].blind_until > 0,"weapon has bounded gameplay effect " + weapon)
		t.check(hit.state.players[2].health >= 0,"weapon damage bounded " + weapon)
		attack.weapon = "forged-weapon"
		t.check(not engine.submit(fight,1,attack).ok,"unsupported weapon rejected")
	var far := running(engine)
	far.players[2].position = [6.0,6.0]
	t.check(not engine.submit(far,1,command(far,1,"attack",{"weapon":"hydrometer","target":2})).ok,"melee range enforced")
	for kind in ["chiller","contamination","burner"]:
		var sabotage := running(engine)
		sabotage.players[1].position = [0.0,0.0]
		sabotage.players[2].position = [.8,0.0]
		var result: Dictionary = engine.submit(sabotage,1,command(sabotage,1,"sabotage",{"kind":kind,"target":2}))
		t.check(result.ok,"server resolves sabotage " + kind)
		var victim: Dictionary = result.state.players[2]
		match kind:
			"chiller": t.check(victim.batch.chiller == 0,"damaged chiller stops cooling flow")
			"contamination": t.check(victim.batch.infected and victim.batch.infection_risk == 1,"contamination reaches chemistry")
			"burner": t.check(victim.redline and victim.batch.target_c == 100,"redline changes rival burner")
		var retry := command(result.state,1,"sabotage",{"kind":kind,"target":2})
		t.check(not engine.submit(result.state,1,retry).ok,"sabotage cooldown enforced")
	var timed := running(engine)
	for i in range(8999): timed = engine.advance(timed,.1).state
	t.check(timed.phase == "running","round still running before 900 seconds")
	timed = engine.advance(timed,.1).state
	t.check(timed.phase == "finished" and is_equal_approx(timed.elapsed,900),"round ends at exactly 15 minutes")
	t.check(timed.results.size() == 2,"server judges all participants at round end")
	t.check(not engine.submit(timed,1,command(timed,1,"move",{"direction":[0,0]})).ok,"finished round rejects gameplay commands")
	var repeated: Dictionary = engine.advance(timed,.1)
	t.check(not repeated.ok and repeated.state == timed,"finished round cannot award twice")
	check_fire(t,engine)

func check_fire(t,engine) -> void:
	var s := running(engine)
	var fire: Dictionary = engine.submit(s,1,command(s,1,"ignite",{"cause":"cord"}))
	t.check(fire.ok and fire.state.players[1].batch.safe_state,"fire immediately latches bay disarm")
	t.check(fire.events.size() >= 2 and fire.events[0].kind == "disarm","disarm precedes fire presentation events")
	t.check(fire.state.players[1].fire.remaining == 45,"staging begins with 45 server seconds")
	var staged: Dictionary = fire.state
	for action in ["receipt","equipment","evidence"]:
		staged.players[1].position = [0.0,0.0]
		staged = engine.submit(staged,1,command(staged,1,"stage",{"object":action})).state
		for i in range(10): staged = engine.advance(staged,.1).state
	staged.players[1].position = [0.0,5.5]
	var escape: Dictionary = engine.submit(staged,1,command(staged,1,"escape"))
	t.check(escape.ok and escape.state.players[1].escaped,"living player can escape at exit")
	staged = escape.state
	while staged.players[1].fire.phase == "staging": staged = engine.advance(staged,.1).state
	t.check(staged.players[1].fire.phase == "resolved","inspection resolves staging")
	t.check(staged.players[1].claim.passed and staged.players[1].claim.payout == 1500,"good fictional staging/escape pays 150 percent exactly")
	var money: int = staged.players[1].money
	for i in range(30): staged = engine.advance(staged,.1).state
	t.check(staged.players[1].money == money,"claim cannot pay more than once")
	t.check(not engine.submit(staged,1,command(staged,1,"stage",{"object":"receipt"})).ok,"closed staging window rejects evidence edits")
	var failed: Dictionary = engine.submit(s,1,command(s,1,"ignite",{"cause":"dust"})).state
	for i in range(450): failed = engine.advance(failed,.1).state
	t.check(not failed.players[1].claim.passed and failed.players[1].bankrupt,"failed claim applies bankruptcy penalty")
	t.check(failed.players[1].health == 0,"remaining indoors through lethal smoke kills player")
	t.check(not engine.submit(fire.state,1,command(fire.state,1,"escape")).ok,"escape requires reaching exit")
	var cutoff: Dictionary = fire.state.duplicate(true)
	cutoff.players[1].fire.remaining = .1
	cutoff.players[1].position = [0.0,5.5]
	cutoff = engine.advance(cutoff,.1).state
	t.check(cutoff.players[1].fire.phase == "resolved","45-second boundary closes before further commands")
	var late := running(engine)
	late.tick = 8999
	late.elapsed = 899.9
	late = engine.submit(late,1,command(late,1,"ignite",{"cause":"cord"})).state
	late = engine.advance(late,.1).state
	t.check(not late.players[1].claim.resolved and late.players[1].fire.remaining > 44,"round end cannot truncate a late 45-second staging window")
	t.check(late.elapsed == 900 and late.phase == "settling","brewing clock stops while active claims settle")
	t.check(not engine.submit(late,1,command(late,1,"attack",{"weapon":"wand","target":2})).ok,"settlement cannot extend combat beyond 15 minutes")
	var steps := 0
	while late.phase != "finished" and steps < 1000:
		late = engine.advance(late,.1).state
		steps += 1
	t.check(late.phase == "finished" and late.elapsed == 900,"late fire resolves once without extending competitive clock")
