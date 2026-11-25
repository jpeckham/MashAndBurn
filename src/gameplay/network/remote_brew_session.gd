extends "res://src/presentation/brew_session.gd"
## Existing brew-desk controls become intents; they never simulate or load a local batch.
var transport
var final_context: Dictionary = {}

func configure(network) -> void:
	transport = network

func apply_snapshot(snapshot: Dictionary, who: int) -> void:
	final_context = {}
	if snapshot.get("players",{}).has(who): state = snapshot.players[who].batch.duplicate(true)
	if snapshot.get("phase") == "finished" and snapshot.get("players",{}).has(who):
		for result in snapshot.get("results",[]):
			if result.player == who:
				final_context = {"result":result.judge.duplicate(true),"seed":state.seed,"style":snapshot.style}
				break
	if transport != null and transport is Node: message = transport.message

func judging_context() -> Dictionary:
	return final_context.duplicate(true)

func instructions() -> String:
	if state.stage == "judging" and final_context.is_empty(): return "Batch packaged. Await the server's final round result."
	return super.instructions()

func route(action: String, values: Dictionary = {}) -> bool:
	if transport == null:
		message = "Multiplayer transport is unavailable."
		return false
	var command := values.duplicate(true)
	command.action = action
	message = "Queued for server approval."
	return transport.send("brew",{"command":command})

func step(_ticks: int) -> void:
	message = "The server owns round time and 600x brewing speed."

func new_batch() -> void:
	message = "Leave the match to start a local batch."

func decode_save(_raw: String) -> bool:
	message = "Multiplayer state comes from the server; local loads are disabled."
	return false

func save_to(_path: String = "user://batch-v1.json") -> bool:
	message = "Local save/load is disabled during multiplayer."
	return false

func load_from(_path: String = "user://batch-v1.json") -> bool:
	message = "Local save/load is disabled during multiplayer."
	return false
