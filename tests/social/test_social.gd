extends RefCounted

func result(score: int, severe: Array = [], id: String = "test") -> Dictionary:
	return {"type":"JudgeResult","version":1,"seq":0,"tick":0,"batch_id":id,"score":score,"categories":{"aroma":score/5.0,"appearance":score/5.0,"flavor":score/5.0,"mouthfeel":score/5.0,"style_accuracy":score/5.0},"feedback":[],"severe_flaws":severe}

func run(t) -> void:
	if not FileAccess.file_exists("res://src/social/social_psyops_service.gd"):
		t.check(false,"local feed boundary and reproducibility implemented")
		return
	var script = load("res://src/social/social_psyops_service.gd")
	var service = script.new()
	t.check(service.submit(result(44),42), "44 triggers")
	t.check(not service.submit(result(44),42), "one batch triggers once")
	t.check(not script.new().submit(result(45),42), "45 does not trigger on score")
	for flaw in ["diacetyl","acetaldehyde"]:
		t.check(script.new().submit(result(90,[flaw]),42), "severe " + flaw + " independently triggers")
	t.check(not script.new().submit({"score":44},42), "malformed judging rejected")
	t.check(service.persona_count == 512, "512 fictional personas preserved")
	var ids := {}
	for page in range(32):
		var rows: Array = service.page(page)
		t.check(rows.size() == 16, "bounded materialization page " + str(page))
		for post in rows:
			ids[post.id] = true
			t.check(post.fictional and post.handle.begins_with("sim_"), "fictional persona identifier")
	t.check(ids.size() == 512,"all personas unique and browsable")
	t.check(service.page(-1).is_empty() and service.page(32).is_empty(), "out of range pages bounded")
	var same = script.new()
	same.submit(result(44),42)
	t.check(service.page(7) == same.page(7), "seeded feed reproducibility")
	var different = script.new()
	different.submit(result(44),43)
	t.check(service.page(7) != different.page(7), "seed changes content")
	t.check(service.has_method("select_batch"), "revisit feed without retriggering batch")
	if service.has_method("select_batch"):
		service.submit(result(44,[],"second"),43)
		t.check(service.select_batch(result(44),42) and service.page(7) == same.page(7),"revisited batch restores seeded page")
	var sim = load("res://src/chemistry/brewing_simulation.gd").new()
	var judge = load("res://src/social/beer_judge.gd").new()
	var state: Dictionary = sim.initial_state(42)
	state.stage = "judging"
	state.flaws.diacetyl = .8
	state.flaws.acetaldehyde = .8
	var judged: Dictionary = judge.evaluate(state)
	t.check("diacetyl" in judged.severe_flaws and "acetaldehyde" in judged.severe_flaws,"judge severe flaw threshold")
	t.check(load("res://src/contracts/protocol.gd").new().validate(judged).is_empty(), "JudgeResult conforms to protocol")
	t.check(judged.feedback.size() > 0 and judged.score <= 100 and judged.score >= 0,"actionable bounded score")
	state.flaws.diacetyl = .59
	state.flaws.acetaldehyde = .59
	t.check(judge.evaluate(state).severe_flaws.is_empty(), "below severe threshold")
	t.check(judge.evaluate(state) == judge.evaluate(state), "deterministic judging")
	var garage = load("res://scenes/garage/garage.tscn").instantiate()
	t.root.add_child(garage)
	var tasting: Array = garage.modules.filter(func(candidate): return candidate.get_script().resource_path == "res://src/social/judging_module.gd")
	t.check(tasting.size() == 1, "registered tasting module initialized")
	garage.session.state = state.duplicate(true)
	garage.session.state.batch_id = "integration-severe"
	garage.session.state.flaws.diacetyl = .8
	garage.refresh()
	var module = tasting[0]
	t.check(module.get("private_alerts") != null,"tasting module exposes disabled-by-default private notification adapter")
	t.check(module.panel.visible and module.feed_active, "end batch opens tasting/feed UI")
	t.check(module.rows.get_child_count() == 16, "render bounded to 16 rows")
	module.page_index = 31
	module.render_page()
	t.check(module.rows.get_child_count() == 16, "last page replaces rather than appends rows")
	garage.session.new_batch()
	garage.refresh()
	t.check(not module.panel.visible, "new batch closes previous tasting UI")
	garage.free()
	private_delivery(t)

func private_delivery(t) -> void:
	var path := "res://src/social/private_notifications.gd"
	if not FileAccess.file_exists(path):
		t.check(false,"opt-in private alert payload adapter exists")
		return
	var notify = load(path).new()
	t.check(not notify.enabled and notify.http == null and not notify.enqueue(result(44),42),"private alerts perform no default network activity")
	t.check(not notify.configure("ws://127.0.0.1:27842/api/v1/telemetry","hosted-fake-token-with-no-real-credentials","friends",false),"game-side explicit opt-in is required")
	t.check(not notify.configure("ws://example.com:27842/api/v1/telemetry","hosted-fake-token-with-no-real-credentials","friends",true),"game can contact only the authenticated local bridge")
	t.check(notify.configure("ws://127.0.0.1:27842/api/v1/telemetry","hosted-fake-token-with-no-real-credentials","friends",true) and notify.http == null,"configuration alone does not dispatch a message")
	t.check(notify.payload(result(45),42).is_empty(),"normal batch cannot dispatch private alert")
	var body: Dictionary = notify.payload(result(44),42)
	t.check(body.destination == "friends" and body.event_id.length() == 64 and body.score == 44 and body.keys().size() == 5,"eligible batch creates bounded private-channel envelope")
	t.check(not notify.payload(result(90,["diacetyl"]),42).is_empty(),"severe butter flaw preserves independent private-alert boundary")
	notify.free()
