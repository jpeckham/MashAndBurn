extends Node
## Optional game→local daemon alert. No public services or operator credentials.
const Protocol = preload("res://src/contracts/protocol.gd")
const Bridge = preload("res://src/hardware/bridge_client.gd")
var enabled := false
var http: HTTPRequest
var endpoint := ""
var credential := ""
var destination := ""
var seen: Dictionary = {}
var queued: Array[Dictionary] = []
var pending := false
var sent_count := 0
var delivered_count := 0
var last_status := "Private alerts off"

func setup_environment() -> void:
	if OS.get_environment("MAB_PRIVATE_ALERTS") != "true": return
	var url := OS.get_environment("MAB_BRIDGE_URL")
	if url.is_empty(): url = "ws://127.0.0.1:27842/api/v1/telemetry"
	configure(url,OS.get_environment("MAB_BRIDGE_TOKEN"),OS.get_environment("MAB_PRIVATE_DESTINATION"),true)

func configure(url: String, token: String, channel: String, opt_in: bool) -> bool:
	enabled = false
	var guard := Bridge.new()
	var identifier := RegEx.new()
	identifier.compile("^[A-Za-z0-9_-]{1,32}$")
	if not opt_in or not guard.endpoint_allowed(url) or not guard.credential_allowed(token) or identifier.search(channel) == null: return false
	endpoint = url.replace("ws://","http://").trim_suffix("/telemetry")+"/psyops/roast"
	credential = token
	destination = channel
	enabled = true
	last_status = "Private alerts configured through local bridge"
	return true

func payload(result: Dictionary, seed_value: int) -> Dictionary:
	if not enabled or result.get("type") != "JudgeResult" or not Protocol.new().validate(result).is_empty(): return {}
	if result.score >= 45 and not ("diacetyl" in result.severe_flaws or "acetaldehyde" in result.severe_flaws): return {}
	var flaws: Array[String] = []
	for item in result.feedback.slice(0,16): flaws.append(str(item).left(100))
	return {"event_id":(result.batch_id+":"+str(seed_value)).sha256_text(),"destination":destination,"beer_name":("Garage "+result.batch_id).left(80),"score":float(result.score),"flaws":flaws}

func enqueue(result: Dictionary, seed_value: int) -> bool:
	var body := payload(result,seed_value)
	if body.is_empty() or seen.has(body.event_id) or seen.size() >= 4096 or queued.size() >= 2: return false
	seen[body.event_id] = true
	queued.append(body)
	process_next()
	return true

func process_next() -> void:
	if pending or queued.is_empty(): return
	if http == null:
		http = HTTPRequest.new()
		http.timeout = 8
		http.body_size_limit = 4096
		http.max_redirects = 0
		http.use_threads = true
		add_child(http)
		http.request_completed.connect(completed)
	var body: Dictionary = queued.pop_front()
	pending = true
	var headers := PackedStringArray(["Content-Type: application/json","Authorization: Bearer "+credential])
	if http.request(endpoint,headers,HTTPClient.METHOD_POST,JSON.stringify(body)) != OK:
		pending = false
		last_status = "Private alert could not be sent"
		process_next.call_deferred()
	else: sent_count += 1

func completed(result: int, status_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	pending = false
	var reply = JSON.parse_string(body.get_string_from_utf8())
	var delivered: bool = result == HTTPRequest.RESULT_SUCCESS and status_code >= 200 and status_code < 300 and reply is Dictionary and (reply.get("status") == "sent" or (reply.get("status") == "duplicate" and reply.get("previous") == "sent"))
	if delivered: delivered_count += 1
	last_status = "Private alert delivered" if delivered else "Private alert not delivered"
	process_next.call_deferred()
