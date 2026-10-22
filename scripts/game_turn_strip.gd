class_name GameTurnStrip
extends HBoxContainer

# Public turn order, always in one row. Inactive names retain neutral white ink.
var players: Array = []
var active := -1
var tracked := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	if tracked: custom_minimum_size.y = 34
	resized.connect(_fit)
	sort_children.connect(queue_redraw)


func set_players(roster: Array, turn: int) -> void:
	players = roster; active = turn
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
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if tracked else VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("ffe18b") if tracked and index == active else Color(str(players[index].color)) if not tracked and index == active else Color.WHITE)
		label.accessibility_name = label.text + (", current turn" if index == active else "")
		var emphasis := FontVariation.new(); emphasis.base_font = get_theme_font("font", "Label"); emphasis.variation_embolden = .8 if index == active else 0
		label.add_theme_font_override("font", emphasis)
	accessibility_name = "Player turn order"
	_fit()
	queue_redraw()


func _draw() -> void:
	if not tracked or get_child_count() == 0: return
	var first: Control = get_child(0); var last: Control = get_child(get_child_count() - 1)
	draw_line(Vector2(first.position.x + first.size.x / 2, 6), Vector2(last.position.x + last.size.x / 2, 6), Color("9ca9af"), 1)
	for index in get_child_count():
		var label: Control = get_child(index)
		var point := Vector2(label.position.x + label.size.x / 2, 6)
		draw_circle(point, 4 if index == active else 3, Color("ffe18b") if index == active else Color("19374b"))
		draw_arc(point, 4 if index == active else 3, 0, TAU, 24, Color("ffe18b") if index == active else Color("9ca9af"), 1, true)


func _fit() -> void:
	var font_size := 17
	var available := maxf(1, (size.x - maxi(0, players.size() - 1) * 8) / maxi(1, players.size()))
	for label: Label in get_children():
		while font_size > 11 and label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available: font_size -= 1
	for label: Label in get_children(): label.add_theme_font_size_override("font_size", font_size)
	queue_redraw()
