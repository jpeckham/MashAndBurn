extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run_suites")

func run_suites() -> void:
	var args := OS.get_cmdline_user_args()
	var suites := ["chemistry", "contracts", "presentation", "social", "gameplay", "network", "client", "visuals", "hardware"]
	if "--suite" in args:
		suites = [args[args.find("--suite") + 1]]
	for suite in suites:
		var path: String = "res://tests/%s/test_%s.gd" % [suite, suite]
		if not FileAccess.file_exists(path):
			check(false, "missing suite " + suite)
			continue
		var script = load(path)
		if script == null or not script.can_instantiate():
			check(false, "suite parses " + suite)
			continue
		await script.new().run(self)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

