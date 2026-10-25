class_name GameTurnStrip
extends HBoxContainer

# Public turn order, always in one row. Inactive names retain neutral white ink.
var players: Array = []
var active := -1
var tracked := false
var portraits: Array[Texture2D] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	if tracked: custom_minimum_size.y = 34
	resized.connect(_fit)
	sort_children.connect(queue_redraw)


func set_players(roster: Array, turn: int) -> void:
	players = roster
	active = turn if turn >= 0 and turn < players.size() and players[turn].get("alive", true) else -1
	custom_minimum_size.y = 48 if not portraits.is_empty() else 34 if tracked else 0
	while get_child_count() > players.size():
		var child := get_child(get_child_count() - 1); remove_child(child); child.queue_free()
	while get_child_count() < players.size():
		var label := Label.new(); label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	for index in players.size():
		var label: Label = get_child(index)
		label.text = str(players[index].display_name)
		var eliminated: bool = not players[index].get("alive", true)
		label.self_modulate = Color(.55, .55, .55) if eliminated else Color.WHITE
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if tracked or not portraits.is_empty() else VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("ffe18b") if tracked and index == active else Color(str(players[index].color)) if not tracked and index == active else Color.WHITE)
		label.accessibility_name = label.text + (", eliminated" if eliminated else ", current turn" if index == active else "")
		var emphasis := FontVariation.new(); emphasis.base_font = get_theme_font("font", "Label"); emphasis.variation_embolden = .8 if index == active else 0
		label.add_theme_font_override("font", emphasis)
	accessibility_name = "Player turn order"
	_fit()
	queue_redraw()


func _draw() -> void:
	if not portraits.is_empty():
		for index in mini(get_child_count(), portraits.size()):
			var label: Control = get_child(index)
			var bounds := Rect2(Vector2(label.position.x, 0), Vector2(label.size.x, size.y))
			draw_style_box(GameLook.asset_player_sheet(Color(str(players[index].color)), index == active, true), bounds.grow(-2))
			var edge := minf(28, size.y * .53)
			if portraits[index] != null: draw_texture_rect(portraits[index], Rect2(Vector2(bounds.get_center().x - edge / 2, 2), Vector2.ONE * edge), false)
		return
	if not tracked or get_child_count() == 0: return
	var first: Control = get_child(0); var last: Control = get_child(get_child_count() - 1)
	draw_line(Vector2(first.position.x + first.size.x / 2, 6), Vector2(last.position.x + last.size.x / 2, 6), Color("9ca9af"), 1)
	for index in get_child_count():
		var label: Control = get_child(index)
		var point := Vector2(label.position.x + label.size.x / 2, 6)
		var edge := Color("9ca9af").darkened(.45) if not players[index].get("alive", true) else Color("9ca9af")
		draw_circle(point, 4 if index == active else 3, Color("ffe18b") if index == active else Color("19374b"))
		draw_arc(point, 4 if index == active else 3, 0, TAU, 24, Color("ffe18b") if index == active else edge, 1, true)


func _fit() -> void:
	var font_size := 14 if not portraits.is_empty() else 17
	var available := maxf(1, (size.x - maxi(0, players.size() - 1) * 8) / maxi(1, players.size()))
	for label: Label in get_children():
		while font_size > 11 and label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available: font_size -= 1
	for label: Label in get_children(): label.add_theme_font_size_override("font_size", font_size)
	queue_redraw()
