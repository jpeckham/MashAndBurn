extends RefCounted

class FakeAuthorityTransport:
	extends RefCounted
	var intents: Array = []
	func send(action: String, data: Dictionary = {}) -> bool:
		intents.append({"action":action,"data":data})
		return true

func run(t) -> void:
	if not FileAccess.file_exists("res://src/presentation/brew_session.gd"):
		t.check(false,"presentation routing and save continuation implemented")
		return
	var script = load("res://src/presentation/brew_session.gd")
	var a = script.new()
	t.check(a.route("set", {"field":"target_c","value":67.0}), "route valid setting")
	t.check(a.state.target_c == 67.0, "routed setting reaches simulation")
	var previous: String = a.sim.state_hash(a.state)
	t.check(not a.route("set", {"field":"target_c","value":300}), "invalid temperature feedback")
	t.check(a.message.length() > 0 and a.sim.state_hash(a.state) == previous, "rejected action leaves state intact")
	t.check(not a.route("unknown"), "unsupported action rejected")
	a.step(100)
	var raw: String = a.encode_save()
	var b = script.new()
	t.check(b.decode_save(raw), "valid save reload")
	t.check(a.sim.state_hash(a.state) == b.sim.state_hash(b.state), "save exact state hash")
	a.step(100)
	b.step(100)
	t.check(a.sim.state_hash(a.state) == b.sim.state_hash(b.state), "deterministic reload continuation")
	for bad in ["{", "null", "[]", '{"save_version":99}', '{"save_version":1,"state":{}}']:
		previous = b.sim.state_hash(b.state)
		t.check(not b.decode_save(bad), "corrupt/versioned save rejected")
		t.check(previous == b.sim.state_hash(b.state), "corrupt save preserves current batch")
	var path := "res://evidence/test-save.tmp"
	t.check(a.save_to(path) and b.load_from(path), "save/load file IO")
	t.check(not b.load_from("res://missing-save.json"), "missing save feedback")
	var old_id: String = a.state.batch_id
	var old_seed: int = a.state.seed
	t.check(a.has_method("new_batch"), "new batch has distinct reproducible identity")
	if a.has_method("new_batch"):
		a.new_batch()
		t.check(a.state.batch_id != old_id and a.state.seed == old_seed + 1, "new batch advances seed and id")
	var tree = load("res://scenes/garage/garage.tscn").instantiate()
	t.check(tree != null, "garage scene loads")
	t.check(tree.has_method("register_module"), "module extension point")
	t.root.add_child(tree)
	var editing: SpinBox = tree.settings.target_c
	editing.value = 72.3
	for i in range(10): tree.refresh()
	t.check(is_equal_approx(editing.value,72.3),"ongoing snapshots preserve unsent recipe edits")
	t.check(tree.session.state.target_c == 66.7,"editing a field alone cannot change simulation")
	var apply_button: Button = editing.get_parent().get_child(editing.get_parent().get_child_count()-1)
	apply_button.pressed.emit()
	t.check(is_equal_approx(tree.session.state.target_c,72.3),"Set submits the user's preserved edit")
	t.check(tree.session.state.sim_seconds == 0,"recipe setting does not advance local simulation time")
	tree.free()
	var remote_path := "res://src/gameplay/network/remote_brew_session.gd"
	if not FileAccess.file_exists(remote_path):
		t.check(false,"multiplayer brew desk routes intents without local authority")
		return
	var adapter = load(remote_path).new()
	var transport := FakeAuthorityTransport.new()
	adapter.configure(transport)
	var original: String = adapter.sim.state_hash(adapter.state)
	t.check(adapter.route("set",{"field":"target_c","value":69.0}),"brew desk queues multiplayer setting")
	t.check(transport.intents.size() == 1 and transport.intents[0].action == "brew","brew desk uses authority transport")
	t.check(adapter.sim.state_hash(adapter.state) == original,"queued input cannot mutate local batch")
	adapter.step(240)
	adapter.new_batch()
	t.check(adapter.sim.state_hash(adapter.state) == original,"time skips/new batch cannot bypass multiplayer authority")
	t.check(not adapter.save_to() and not adapter.load_from() and not adapter.decode_save(raw),"local saves cannot replace server state")
