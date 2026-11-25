extends RefCounted

class CountingGarage:
	extends "res://src/presentation/garage.gd"
	var refresh_count := 0
	func refresh() -> void:
		refresh_count += 1
		super.refresh()

func snapshot_burst(t) -> void:
	var branch := Node.new()
	branch.name = "BurstHost"
	t.root.add_child(branch)
	var api := SceneMultiplayer.new()
	api.root_path = branch.get_path()
	t.set_multiplayer(api,branch.get_path())
	var scene := CountingGarage.new()
	branch.add_child(scene)
	var ui = scene.get_node("Multiplayer")
	ui.network.set_physics_process(false)
	t.check(ui.network.host(26100+OS.get_process_id()%300,"Burst") == OK,"snapshot burst fixture hosts")
	var before := scene.refresh_count
	for i in range(100):
		ui.network.state.players[1].batch.target_c = 60+float(i)/10
		ui.network.publish()
	t.check(scene.refresh_count-before <= 1,"snapshot burst does not rebuild garage for every obsolete intermediate view")
	await t.process_frame
	await t.process_frame
	t.check(scene.refresh_count-before <= 1 and is_equal_approx(scene.session.state.target_c,69.9),"one garage application presents newest burst snapshot")
	ui.leave()
	t.set_multiplayer(null,branch.get_path())
	branch.queue_free()
	await t.process_frame

func wait_for(tree, predicate: Callable, seconds: float = 4.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await tree.process_frame
	return predicate.call()

func garage(tree, label: String) -> Node:
	var branch := Node.new()
	branch.name = label
	tree.root.add_child(branch)
	var api := SceneMultiplayer.new()
	api.root_path = branch.get_path()
	tree.set_multiplayer(api,branch.get_path())
	var scene: Node = load("res://scenes/garage/garage.tscn").instantiate()
	branch.add_child(scene)
	return scene

func tasting(scene):
	return scene.modules.filter(func(module): return module.get_script().resource_path == "res://src/social/judging_module.gd")[0]

func run(t) -> void:
	await snapshot_burst(t)
	var host_scene = garage(t,"IntegratedHost")
	var client_scene = garage(t,"IntegratedClient")
	var host_ui = host_scene.get_node("Multiplayer")
	var client_ui = client_scene.get_node("Multiplayer")
	var server = host_ui.network
	var client = client_ui.network
	var original: String = client_scene.session.sim.state_hash(client_scene.session.state)
	server.set_physics_process(false)
	var port: int = 26500+OS.get_process_id()%500
	t.check(server.host(port,"Host") == OK,"full garage hosts ENet")
	t.check(client.connect_to("127.0.0.1",port,"Guest") == OK,"full garage client connects")
	var joined: bool = await wait_for(t,func(): return client.player_id == 2 and client_ui.remote_mode)
	t.check(joined,"real garage module switches to authoritative remote session")
	if joined:
		var editor: SpinBox = client_scene.settings.target_c
		editor.value = 69.4
		var revision: int = client.view.event_id
		server.authority.emit(server.state,"fixture_refresh",0)
		server.publish()
		t.check(await wait_for(t,func(): return client.view.event_id > revision),"actual ENet snapshot reaches live garage controls")
		t.check(is_equal_approx(editor.value,69.4),"real network refresh preserves unsent edit")
		var button: Button = editor.get_parent().get_child(editor.get_parent().get_child_count()-1)
		button.pressed.emit()
		t.check(await wait_for(t,func(): return server.state.players[2].batch.target_c == 69.4),"actual garage Set button submits own-batch intent")
		t.check(server.state.players[1].batch.target_c == 66.7 and server.state.players[2].batch.sim_seconds == 0,"live client setting cannot affect rival or advance time")
		server.send("ready",{"ready":true})
		client.send("ready",{"ready":true})
		t.check(await wait_for(t,func(): return server.state.players.values().all(func(p): return p.ready)),"full UI endpoints ready")
		t.check(server.start_round("stout"),"full UI host selects stout target")
		# Deliberately flawed packaged fixture exercises final-result consumption,
		# not a complete brewing playthrough (which remains a separate visible gate).
		server.state.players[2].batch.stage = "judging"
		server.state.players[2].batch.flaws.diacetyl = .8
		server.state.players[2].batch.flaws.acetaldehyde = .8
		server.authority.emit(server.state,"fixture_packaged",2)
		server.publish()
		t.check(await wait_for(t,func(): return client_scene.session.state.stage == "judging"),"packaged batch mirrors into real garage")
		var feed = tasting(client_scene)
		t.check(not feed.panel.visible and feed.current.is_empty(),"multiplayer tasting waits for authoritative final result")
		server.state.tick = 8999
		server.state.elapsed = 899.9
		server.state = server.authority.advance(server.state,.1).state
		server.publish()
		t.check(await wait_for(t,func(): return client.view.get("phase") == "finished"),"full client receives final results")
		var own: Dictionary = server.state.results.filter(func(result): return result.player == 2)[0].judge
		t.check(feed.current == own,"tasting uses exact authoritative categories feedback and score")
		t.check(feed.summary.text.to_lower().contains("stout"),"tasting names host-selected rubric")
		t.check(feed.feed_active and feed.service.persona_count == 512,"authoritative flawed result triggers fictional feed")
		for page in [0,1,31]:
			feed.page_index = page
			feed.render_page()
			t.check(feed.rows.get_child_count() == 16,"live integrated feed page %d stays bounded" % (page+1))
		server.publish()
		await t.process_frame
		t.check(feed.service.seen.size() == 1,"repeated final snapshots do not retrigger feed")
		t.check(host_ui.get("staging_props") is Dictionary,"garage exposes spatial staging props")
		client_ui.leave()
		t.check(client_scene.session.sim.state_hash(client_scene.session.state) == original and not client_ui.remote_mode,"leaving restores original local batch exactly")
		print("GARAGE_ENET_SMOKE style=stout final_result=authoritative local_batch=restored")
		await interactions(t,host_scene,client_scene,port+1)
	for scene in [client_scene,host_scene]:
		var branch: Node = scene.get_parent()
		scene.get_node("Multiplayer").leave()
		t.set_multiplayer(null,branch.get_path())
		branch.queue_free()
	await t.process_frame

func interactions(t, host_scene, client_scene, port: int) -> void:
	var host_ui = host_scene.get_node("Multiplayer")
	var client_ui = client_scene.get_node("Multiplayer")
	var server = host_ui.network
	var client = client_ui.network
	server.host(port,"Host")
	client.connect_to("127.0.0.1",port,"Guest")
	if not await wait_for(t,func(): return client.player_id == 2 and client_ui.remote_mode):
		t.check(false,"second full garage session joins")
		return
	server.send("ready",{"ready":true})
	client.send("ready",{"ready":true})
	await wait_for(t,func(): return server.state.players.values().all(func(p): return p.ready))
	server.start_round()
	server.state.players[2].position = [-4.8,-.2]
	server.publish()
	await wait_for(t,func(): return client.view.get("phase") == "running")
	client.send("ignite",{"cause":"cord"})
	t.check(await wait_for(t,func(): return client.view.players[2].fire.phase == "staging"),"real client receives fire incident")
	t.root.gui_release_focus()
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = KEY_E
		event.physical_keycode = KEY_E
		event.pressed = pressed
		Input.parse_input_event(event)
	t.check(await wait_for(t,func(): return server.state.players[2].fire.objects.receipt),"E travels through real viewport and ENet to spatial staging")
	t.check(await wait_for(t,func(): return client_ui.staging_props.receipt.get_node("PropLabel").text.contains("STAGED")),"authoritative prop progress updates real client label")
	server.state.players[1].position = [-4.0,-.2]
	server.publish()
	client.send("attack",{"weapon":"wand","target":1})
	t.check(await wait_for(t,func(): return server.state.spills.size() == 1 and client_ui.spills.size() == 1),"real client renders authoritative floor patch")
	if not client_ui.spills.is_empty():
		var patch = client_ui.spills.values()[0]
		for tick in range(85): server.state = server.authority.advance(server.state,.1).state
		server.publish()
		t.check(await wait_for(t,func(): return client_ui.spills.is_empty()),"expired floor snapshot removes client patch")
		await t.process_frame
		t.check(not is_instance_valid(patch),"expired floor visual is freed")
	t.check(client_ui.fires.has(2),"fire visual remains during its active window")
	var flame = client_ui.fires.get(2)
	client_ui.leave()
	await t.process_frame
	t.check(client_ui.fires.is_empty() and client_ui.spills.is_empty() and not is_instance_valid(flame),"leave frees transient fire/floor visuals")
	t.check(not client_ui.staging_props.receipt.get_node("PropLabel").text.contains("STAGED"),"leave resets local prop progress for the next session")
	print("GARAGE_INTERACTION_SMOKE staging=viewport_E floor=expired_and_freed leave=clean")
