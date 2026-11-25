extends Node
const Judge = preload("res://src/social/beer_judge.gd")
const Feed = preload("res://src/social/social_psyops_service.gd")
var garage: Node
var service := Feed.new()
var judge := Judge.new()
var current: Dictionary = {}
var observed_id := ""
var panel: PanelContainer
var summary: Label
var feedback: Label
var page_label: Label
var rows: VBoxContainer
var page_index := 0
var show_button: Button
var feed_active := false

func setup(host: Node) -> void:
	garage = host
	show_button = garage.button("Open tasting & local feed",garage.module_slot,func(): panel.visible = true)
	show_button.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	panel = PanelContainer.new()
	panel.position = Vector2(245,62)
	panel.size = Vector2(875,620)
	panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101f28")
	style.border_color = Color("d9af61")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	for side in ["left","right","top","bottom"]: style.set("content_margin_"+side,18)
	panel.add_theme_stylebox_override("panel",style)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation",8)
	panel.add_child(v)
	var heading = garage.row(v)
	garage.label("THE TASTING ROOM",heading,24,Color("efc16c")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	garage.button("Back to garage",heading,func(): panel.visible = false)
	summary = garage.label("",v,17)
	feedback = garage.label("",v,14)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.x = 830
	garage.label("HOPWIRE  /  FICTIONAL LOCAL SANDBOX",v,16,Color("efc16c"))
	var nav = garage.row(v)
	garage.button("← Previous",nav,func(): page_index = maxi(0,page_index-1); render_page())
	page_label = garage.label("",nav,14)
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	garage.button("Next →",nav,func(): page_index = mini(31,page_index+1); render_page())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 280
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",8)
	scroll.add_child(rows)
	garage.label("512 procedural personas · at most 16 visible posts · no outbound dispatch",v,12,Color("a9bfc2"))

func on_state(s: Dictionary) -> void:
	if garage.session.has_method("judging_context"):
		var context: Dictionary = garage.session.judging_context()
		if context.is_empty():
			show_button.visible = false
			panel.visible = false
			return
		present(context.result,context.seed,context.style)
		return
	if s.stage != "judging":
		show_button.visible = false
		panel.visible = false
		return
	present(judge.evaluate(s),s.seed,"pale_ale")

func present(result: Dictionary, seed_value: int, style_name: String) -> void:
	show_button.visible = true
	if observed_id == result.batch_id: return
	observed_id = result.batch_id
	current = result.duplicate(true)
	feed_active = service.submit(current,seed_value)
	if not feed_active: feed_active = service.select_batch(current,seed_value)
	page_index = 0
	var c: Dictionary = current.categories
	summary.text = "%.1f / 100    ·    Fictional %s rubric\nAroma %.1f  /  Appearance %.1f  /  Flavor %.1f  /  Mouthfeel %.1f  /  Style %.1f\nEach category is worth 20 points." % [current.score,style_name.replace("_"," "),c.aroma,c.appearance,c.flavor,c.mouthfeel,c.style_accuracy]
	feedback.text = "\n".join(current.feedback)
	render_page()
	panel.visible = true
	garage.paused = true

func render_page() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	if not feed_active:
		page_label.text = "No feed triggered"
		garage.label("No local swarm: this batch scored at least 45 without severe butter/green-apple flaws.",rows,14)
		return
	page_label.text = "Page %d / 32   ·   512 fictional personas" % [page_index+1]
	for post in service.page(page_index):
		var r = garage.row(rows)
		var avatar = garage.label("["+post.avatar+"]",r,22,Color(post.color))
		avatar.custom_minimum_size.x = 44
		var content := VBoxContainer.new()
		r.add_child(content)
		garage.label(post.handle + "  ·  SIMULATED",content,13,Color(post.color))
		garage.label(post.text,content,14)
