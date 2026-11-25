extends RefCounted
## Opt-in loopback transport. Holds only the telemetry credential, never operator authority.
const Protocol = preload("res://src/contracts/protocol.gd")
var peer: WebSocketPeer
var ready := false
var error := ""
var last_reply: Dictionary = {}
var frames_sent := 0

func endpoint_allowed(url: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^ws://(127\\.0\\.0\\.1|\\[::1\\]):([0-9]{4,5})/api/v1/telemetry$")
	var match_value := pattern.search(url)
	return match_value != null and match_value.get_string(2).to_int() >= 1024 and match_value.get_string(2).to_int() <= 65535

func start(url: String, credential: String) -> bool:
	stop()
	error = ""
	if not endpoint_allowed(url):
		error = "Only an explicit loopback companion endpoint is supported."
		return false
	if credential.length() < 32 or credential.length() > 256:
		error = "Configure a local telemetry credential before connecting."
		return false
	for i in range(credential.length()):
		if credential.unicode_at(i) < 33 or credential.unicode_at(i) > 126:
			error = "Invalid telemetry credential format."
			return false
	peer = WebSocketPeer.new()
	peer.handshake_headers = PackedStringArray(["Authorization: Bearer "+credential])
	peer.inbound_buffer_size = 16384
	peer.outbound_buffer_size = 16384
	peer.max_queued_packets = 16
	if peer.connect_to_url(url) != OK:
		error = "Companion connection could not start."
		stop()
		return false
	return true

func stop() -> void:
	ready = false
	last_reply = {}
	if peer != null:
		peer.close(1000,"Telemetry stopped")
		peer = null

func poll() -> void:
	if peer == null: return
	peer.poll()
	if peer.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		error = "Companion disconnected; requests remain latched off."
		stop()
		return
	if peer.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	var count := 0
	while peer.get_available_packet_count() > 0 and count < 16:
		count += 1
		var raw := peer.get_packet()
		if raw.size() > 4096:
			error = "Oversized companion response."
			stop()
			return
		var packet = JSON.parse_string(raw.get_string_from_utf8())
		if not packet is Dictionary or not packet.get("armed") is bool:
			error = "Malformed companion response."
			stop()
			return
		if packet.has("protocol"):
			# Godot's JSON parser represents numeric literals as floats, including 1.
			if not (packet.protocol is int or packet.protocol is float) or packet.protocol != 1 or packet.armed != false or not packet.get("transport") is String or not packet.transport.begins_with("mock-"):
				error = "An authenticated mock companion is required."
				stop()
				return
			ready = true
		elif not packet.get("ok") is bool or not packet.get("fault") is String:
			error = "Unsupported companion response."
			stop()
			return
		last_reply = packet.duplicate(true)

func send_frame(frame: Dictionary) -> bool:
	if not ready or peer == null or peer.get_ready_state() != WebSocketPeer.STATE_OPEN: return false
	if frame.get("type") != "HardwareFrame" or not Protocol.new().validate(frame).is_empty(): return false
	var raw := JSON.stringify(frame)
	if raw.to_utf8_buffer().size() > 4096 or peer.send_text(raw) != OK:
		error = "Companion send failed; requests remain latched off."
		stop()
		return false
	frames_sent += 1
	return true
