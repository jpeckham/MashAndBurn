extends RefCounted

func wait_for(tree, predicate: Callable, seconds: float = 4.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call(): return true
		await tree.process_frame
	return predicate.call()

func endpoint(tree, script, label: String) -> Node:
	var branch := Node.new()
	branch.name = label
	tree.root.add_child(branch)
	var api := SceneMultiplayer.new()
	api.root_path = branch.get_path()
	tree.set_multiplayer(api,branch.get_path())
	var network: Node = script.new()
	network.name = "MatchNetwork"
	branch.add_child(network)
	return network

func run(t) -> void:
	var path := "res://src/gameplay/network/match_network.gd"
	if not FileAccess.file_exists(path):
		t.check(false,"real ENet multiplayer transport implemented")
		return
	var script = load(path)
	for count in [2,8]:
		var nodes: Array = []
		var server = endpoint(t,script,"NetworkServer%d" % count)
		nodes.append(server)
		server.set_physics_process(false)
		var port: int = 24000+OS.get_process_id()%1000+count
		t.check(server.host(port,"Dedicated",false) == OK,"ENet dedicated host starts for %d clients" % count)
		var clients: Array = []
		for i in range(count):
			var client = endpoint(t,script,"Client%d_%d" % [count,i])
			nodes.append(client)
			clients.append(client)
			t.check(client.connect_to("127.0.0.1",port,"Brewer %d" % i) == OK,"real ENet client initializes")
		var joined: bool = await wait_for(t,func(): return server.state.players.size() == count and clients.all(func(c): return c.player_id > 0))
		t.check(joined,"all %d real clients receive server identities" % count)
		if joined:
			for client in clients: client.send("ready",{"ready":true})
			var ready: bool = await wait_for(t,func(): return server.state.players.values().all(func(p): return p.ready))
			t.check(ready,"ready intents cross actual ENet transport")
			if count == 8:
				var extra = endpoint(t,script,"OverflowClient")
				nodes.append(extra)
				extra.connect_to("127.0.0.1",port,"Overflow")
				t.check(await wait_for(t,func(): return extra.message.contains("full")),"real ninth client receives explicit capacity rejection")
				t.check(server.state.players.size() == 8,"unsupported join cannot exceed capacity")
			t.check(server.start_round("pale_ale"),"host starts authoritative 15-minute round")
			t.check(await wait_for(t,func(): return clients.all(func(c): return c.view.get("phase") == "running")),"all clients receive running snapshot")
			var first = clients[0]
			# A slow rendered client may miss several snapshots. The server must keep
			# rejecting stale ticks, while transport preserves a never-applied intent.
			for tick in range(40): server.state = server.authority.advance(server.state,.1).state
			var replies: int = first.reply_count
			first.send("brew",{"command":{"action":"set","field":"target_c","value":69.0}})
			t.check(await wait_for(t,func(): return first.reply_count > replies),"server acknowledges own-batch command")
			t.check(await wait_for(t,func(): return server.state.players[first.player_id].batch.target_c == 69),"stale real client recovers never-applied intent using authoritative reply clock")
			replies = first.reply_count
			first.send("award_money",{"amount":100000})
			t.check(await wait_for(t,func(): return first.reply_count > replies),"malicious real client receives rejection")
			t.check(first.message.contains("Unsupported") and server.state.players[first.player_id].money == 1000,"remote input cannot award money")
			var identity: int = first.player_id
			var token: String = first.resume_token
			first._drop_connection("Fixture disconnect")
			t.check(await wait_for(t,func(): return not server.state.players[identity].connected),"actual disconnect reaches authoritative cleanup")
			t.check(not first.send("move",{"direction":[0,0]}),"disconnected client cannot send through offline fallback")
			first.connect_to("127.0.0.1",port,"Reconnect",true)
			t.check(await wait_for(t,func(): return first.player_id == identity and server.state.players[identity].connected),"actual reconnect restores reserved identity")
			t.check(first.resume_token == token and server.state.players[identity].batch.safe_state,"reconnect preserves credential and hazard latch")
			# Advance the server's fixed clock in the fixture, not via a network command.
			# Production never exposes a speed or elapsed-time RPC.
			for tick in range(9000): server.state = server.authority.advance(server.state,.1).state
			server.publish()
			t.check(await wait_for(t,func(): return clients.all(func(c): return c.view.get("phase") == "finished")),"%d real clients finish server-owned round" % count)
			t.check(clients.all(func(c): return c.view.elapsed == 900 and c.view.results.size() == count),"clients agree on 900-second clock and results")
			print("ENET_SMOKE clients=%d elapsed=%s results=%d server_tick=%d" % [count,server.state.elapsed,server.state.results.size(),server.state.tick])
			server.shutdown()
			t.check(await wait_for(t,func(): return first.message.contains("Server disconnected")),"server loss reaches clients")
			t.check(not first.send("move",{"direction":[0,0]}),"server loss never enables local authority")
		for network in nodes:
			var branch: Node = network.get_parent()
			network.shutdown()
			t.set_multiplayer(null,branch.get_path())
			branch.queue_free()
		await t.process_frame
