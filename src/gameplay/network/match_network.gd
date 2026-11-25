extends Node
## ENet transport. Only this server's authenticated sender IDs reach the authority.
const Authority = preload("res://src/gameplay/rounds/round_authority.gd")
signal changed
var authority := Authority.new()
var state: Dictionary = {}
var view: Dictionary = {}
var player_id := 0
var resume_token := ""
var message := "Offline. Host or join a trusted local/LAN session."
var reply_count := 0
var is_host := false
var session_connected := false
var pending := false
var queued: Array = []
var connection_name := "Brewer"
var reconnecting := false
var accumulator := 0.0
var unauthenticated: Dictionary = {}
var request_rates: Dictionary = {}

func _ready() -> void:
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	if multiplayer is SceneMultiplayer:
		multiplayer.allow_object_decoding = false
		multiplayer.server_relay = false

func host(port: int = 27841, player_name: String = "Host", playing: bool = true) -> Error:
	shutdown()
	if port < 1024 or port > 65535:
		message = "Use a port from 1024 to 65535."
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	# One extra connection can receive an application-level full-lobby rejection.
	var error := peer.create_server(port,9,2)
	if error != OK:
		message = "Could not host on UDP port %d (error %d)." % [port,error]
		changed.emit()
		return error
	multiplayer.multiplayer_peer = peer
	is_host = true
	session_connected = true
	var seed_value: int = Crypto.new().generate_random_bytes(4).decode_u32(0)%2147483647
	state = authority.initial_state(seed_value)
	if playing:
		var result: Dictionary = authority.join(state,1,player_name,credential())
		if not result.ok:
			shutdown()
			message = result.error
			return ERR_INVALID_PARAMETER
		state = result.state
		player_id = result.player_id
		resume_token = result.resume_token
	message = "Hosting UDP %d. Every brewer must ready before the host starts." % port
	publish()
	return OK

func connect_to(address: String, port: int, player_name: String, resume: bool = false) -> Error:
	if address.strip_edges().is_empty() or port < 1024 or port > 65535: return ERR_INVALID_PARAMETER
	var saved_token := resume_token if resume else ""
	shutdown()
	resume_token = saved_token
	connection_name = player_name.left(32)
	reconnecting = resume
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(),port,2)
	if error != OK:
		message = "Connection setup failed (error %d)." % error
		changed.emit()
		return error
	multiplayer.multiplayer_peer = peer
	message = "Connecting…"
	changed.emit()
	return OK

func credential() -> String:
	return Crypto.new().generate_random_bytes(24).hex_encode()

func _connected() -> void:
	_hello.rpc_id(1,{"version":1,"name":connection_name,"reconnect":reconnecting,"token":resume_token})

func _connection_failed() -> void:
	_drop_connection("Connection failed. Check the host address and UDP port.")

func _server_disconnected() -> void:
	_drop_connection("Server disconnected. No local authority fallback; reconnect or leave.")

func _drop_connection(reason: String) -> void:
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	session_connected = false
	pending = false
	queued.clear()
	message = reason
	changed.emit()

func _peer_connected(peer: int) -> void:
	if is_host: unauthenticated[peer] = Time.get_ticks_msec()

func _peer_disconnected(peer: int) -> void:
	if not is_host: return
	unauthenticated.erase(peer)
	request_rates.erase(peer)
	if state.get("peer_players",{}).has(peer):
		var result: Dictionary = authority.disconnect_peer(state,peer)
		state = result.state
		publish()

@rpc("any_peer","call_remote","reliable",0)
func _hello(info: Dictionary) -> void:
	if not is_host: return
	var peer: int = multiplayer.get_remote_sender_id()
	if not unauthenticated.has(peer): return
	if var_to_bytes(info).size() > 2048 or info.get("version") != 1 or not info.get("name") is String or not info.get("token") is String or not info.get("reconnect") is bool:
		_welcome.rpc_id(peer,0,"","Unsupported join protocol.",{})
		return
	var token: String = info.token if info.reconnect else credential()
	var result: Dictionary = authority.join(state,peer,info.name,token,info.reconnect)
	if result.ok:
		state = result.state
		unauthenticated.erase(peer)
		_welcome.rpc_id(peer,result.player_id,result.resume_token,"",authority.snapshot(state))
		publish()
	else: _welcome.rpc_id(peer,0,"",result.error,{})

@rpc("authority","call_remote","reliable",0)
func _welcome(id: int, token: String, error: String, snapshot: Dictionary) -> void:
	if is_host: return
	if id == 0:
		_drop_connection(error)
		return
	player_id = id
	session_connected = true
	resume_token = token
	message = "Joined as brewer %d. Ready when your recipe is set." % id
	accept_view(snapshot)

func send(action: String, data: Dictionary = {}) -> bool:
	if not session_connected:
		message = "Disconnected; reconnect or leave."
		return false
	if player_id == 0 or not view.get("players",{}).has(player_id) or not view.players[player_id].connected:
		message = "No connected brewer identity."
		return false
	if not is_host and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED: return false
	if action == "move":
		for item in queued:
			if item.action == "move":
				item.data = data.duplicate(true)
				return true
	if queued.size() >= 32:
		message = "Input queue full; wait for the server."
		return false
	queued.append({"action":action,"data":data.duplicate(true)})
	flush()
	return true

func flush() -> void:
	if pending or queued.is_empty() or not view.get("players",{}).has(player_id): return
	var item: Dictionary = queued.pop_front()
	var command: Dictionary = item.data.duplicate(true)
	command.merge({"version":1,"round_id":view.round_id,"seq":view.players[player_id].seq+1,"tick":view.tick,"action":item.action},true)
	pending = true
	if is_host:
		var result: Dictionary = authority.submit(state,1,command)
		if result.ok: state = result.state
		handle_reply(result.ok,result.error,authority.snapshot(state))
		if result.ok: publish()
	else: _intent.rpc_id(1,JSON.stringify(command).to_utf8_buffer())

@rpc("any_peer","call_remote","reliable",0)
func _intent(raw: PackedByteArray) -> void:
	if not is_host: return
	var peer: int = multiplayer.get_remote_sender_id()
	if not state.get("peer_players",{}).has(peer): return
	var now := Time.get_ticks_msec()
	var rate: Dictionary = request_rates.get(peer,{"start":now,"count":0})
	if now-rate.start >= 1000: rate = {"start":now,"count":0}
	rate.count += 1
	request_rates[peer] = rate
	if raw.size() > 4096 or rate.count > 40:
		_reply.rpc_id(peer,false,"Input exceeds size/rate limit.",authority.snapshot(state))
		return
	var parser := JSON.new()
	var parsed = null
	if parser.parse(raw.get_string_from_utf8()) == OK: parsed = parser.data
	var result: Dictionary = authority.submit(state,peer,parsed)
	if result.ok: state = result.state
	_reply.rpc_id(peer,result.ok,result.error,authority.snapshot(state))
	if result.ok: publish()

@rpc("authority","call_remote","reliable",0)
func _reply(ok: bool, error: String, snapshot: Dictionary) -> void:
	if not is_host: handle_reply(ok,error,snapshot)

func handle_reply(ok: bool, error: String, snapshot: Dictionary) -> void:
	reply_count += 1
	pending = false
	message = "Server accepted input." if ok else error
	accept_view(snapshot)
	flush()

@rpc("authority","call_remote","reliable",1)
func _snapshot(snapshot: Dictionary) -> void:
	if not is_host: accept_view(snapshot)

@rpc("authority","call_remote","reliable",0)
func _critical_snapshot(snapshot: Dictionary) -> void:
	if not is_host: accept_view(snapshot)

func accept_view(snapshot: Dictionary) -> void:
	if snapshot.get("version") != 1 or not snapshot.get("players") is Dictionary: return
	if not view.is_empty() and snapshot.round_id == view.round_id:
		if snapshot.tick < view.tick or (snapshot.tick == view.tick and snapshot.event_id < view.event_id): return
	view = snapshot.duplicate(true)
	changed.emit()

func publish() -> void:
	if not is_host: return
	var snapshot: Dictionary = authority.snapshot(state)
	var critical: bool = snapshot.phase != view.get("phase") or snapshot.phase == "finished"
	accept_view(snapshot)
	for peer in state.peer_players:
		if peer == 1: continue
		if critical: _critical_snapshot.rpc_id(peer,snapshot)
		else: _snapshot.rpc_id(peer,snapshot)

func start_round(style: String = "pale_ale") -> bool:
	if not is_host:
		message = "Only the host may start."
		return false
	var result: Dictionary = authority.begin(state,1,style)
	message = "Round started. Server brewing speed is 600x." if result.ok else result.error
	if result.ok: state = result.state
	publish()
	return result.ok

func _physics_process(delta: float) -> void:
	if not is_host: return
	for peer in unauthenticated.keys():
		if Time.get_ticks_msec()-unauthenticated[peer] > 5000:
			multiplayer.multiplayer_peer.disconnect_peer(peer)
			unauthenticated.erase(peer)
	if state.get("phase") not in ["running","settling"]: return
	accumulator += delta
	var steps := 0
	while accumulator >= .1 and steps < 5 and state.phase in ["running","settling"]:
		state = authority.advance(state,.1).state
		accumulator -= .1
		steps += 1
	if steps > 0: publish()

func shutdown() -> void:
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_host = false
	session_connected = false
	player_id = 0
	resume_token = ""
	pending = false
	queued.clear()
	unauthenticated.clear()
	request_rates.clear()
	view = {}
	state = {}
	accumulator = 0.0
