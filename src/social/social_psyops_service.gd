extends RefCounted
## Entirely local, lazy procedural fiction. No network APIs, credentials, real accounts or image downloads.
const Protocol = preload("res://src/contracts/protocol.gd")
const PAGE_SIZE := 16
const PERSONAS := 512
const MAX_BATCHES := 4096
const NOUNS = ["MaltMoth","FoamGoblin","CopperBadger","YeastComet","HopsOtter","GrainGhost","KettleDuck","WortWizard"]
const LINES = ["My imaginary carboy requested a transfer after tasting this.","The foam filed a fictional noise complaint.","This recipe has more plot twists than my sanitation checklist.","A simulated kettle just asked for a second opinion.","The garage has entered its experimental flavor era.","My procedural taste buds are requesting a reroll.","Even the imaginary yeast wants another cleanup day.","A fictional hop has volunteered to supervise the next batch."]
var seen: Dictionary = {}
var active_result: Dictionary = {}
var seed_value := 0
var persona_count := 0

func submit(result: Dictionary, seed: int) -> bool:
	if not Protocol.new().validate(result).is_empty() or result.get("type") != "JudgeResult": return false
	if seen.has(result.batch_id) or seen.size() >= MAX_BATCHES: return false
	seen[result.batch_id] = true
	return select_batch(result, seed)

func select_batch(result: Dictionary, seed: int) -> bool:
	if not Protocol.new().validate(result).is_empty() or result.get("type") != "JudgeResult": return false
	if not seen.has(result.batch_id): return false
	var severe: Array = result.severe_flaws
	if result.score >= 45 and not ("diacetyl" in severe or "acetaldehyde" in severe): return false
	active_result = result.duplicate(true)
	seed_value = seed
	persona_count = PERSONAS
	return true

func page(index: int) -> Array:
	if index < 0 or index >= PERSONAS/PAGE_SIZE or persona_count == 0: return []
	var posts: Array = []
	for id in range(index*PAGE_SIZE, (index+1)*PAGE_SIZE):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + id*104729
		var name: String = NOUNS[rng.randi_range(0,NOUNS.size()-1)]
		posts.append({"id":id,"fictional":true,"handle":"sim_%s_%03d" % [name,id],"avatar":name.left(1),"color":Color.from_hsv(rng.randf(),.45,.9).to_html(),"text":LINES[rng.randi_range(0,LINES.size()-1)],"batch_id":active_result.batch_id})
	return posts
