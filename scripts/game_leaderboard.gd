class_name GameLeaderboard
extends VBoxContainer

# Presentation only: callers supply accepted scores, ranks, deltas and notes.
signal player_selected(seat: int)
var rows: Array = []
var compact := false
var _entry_key := ""
var _rows_by_seat: Dictionary = {}


func _init() -> void:
	add_theme_constant_override("separation", 4)


func _create_row(seat: int) -> Dictionary:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(button)
	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 10; content.offset_right = -10
	content.add_theme_constant_override("separation", 10)
	button.add_child(content)
	var rank := Label.new(); rank.custom_minimum_size.x = 34; content.add_child(rank)
	var avatar := Control.new(); avatar.custom_minimum_size = Vector2(32, 32); avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER; content.add_child(avatar)
	var names := VBoxContainer.new(); names.alignment = BoxContainer.ALIGNMENT_CENTER; names.size_flags_horizontal = Control.SIZE_EXPAND_FILL; names.add_theme_constant_override("separation", 0); content.add_child(names)
	var player := Label.new(); player.clip_text = true; player.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; names.add_child(player)
	var note := Label.new(); note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; note.add_theme_font_size_override("font_size", 12); names.add_child(note)
	var speech := PanelContainer.new()
	speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speech.add_theme_stylebox_override("panel", GameLook.speech_bubble())
	speech.hide()
	content.add_child(speech)
	var speech_text := Label.new()
	speech_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speech_text.add_theme_font_size_override("font_size", 13)
	speech.add_child(speech_text)
	speech.draw.connect(func() -> void:
		var style: StyleBoxFlat = speech.get_theme_stylebox("panel")
		var pointer := PackedVector2Array([Vector2(1, 7), Vector2(-5, 12), Vector2(1, 17)])
		speech.draw_colored_polygon(pointer, style.bg_color)
		speech.draw_polyline(pointer, style.border_color, 1, true))
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.hide()
	content.add_child(spacer)
	var delta := Label.new(); delta.add_theme_color_override("font_color", GameLook.guess_color("correct")); content.add_child(delta)
	var score := Label.new(); score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; content.add_child(score)
	for control in [rank, avatar, names, player, note, delta, score]:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label in [player, score]: label.add_theme_color_override("font_color", Color("30324a"))
	var row := {"button": button, "content": content, "names": names, "spacer":spacer, "player": player, "score": score, "rank": rank, "avatar": avatar, "note": note, "bubble": {"panel":speech,"label":speech_text}, "delta": delta, "seat": seat, "identity": Color.WHITE, "pose": 0}
	button.pressed.connect(func() -> void: player_selected.emit(seat))
	button.resized.connect(func() -> void: _fit_speech(row))
	speech_text.minimum_size_changed.connect(func() -> void: _fit_speech.call_deferred(row))
	avatar.draw.connect(func() -> void: GameLook.draw_table_avatar(avatar, Rect2(Vector2.ZERO, avatar.size), row.identity, row.pose))
	return row


func _fit_speech(row: Dictionary) -> void:
	var spoken: bool = row.bubble.panel.visible
	row.spacer.visible = spoken
	row.names.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if spoken else Control.SIZE_EXPAND_FILL
	row.names.custom_minimum_size.x = 0
	var height := (44 if compact else 56) + (18 if row.note.visible else 0)
	if spoken:
		var name_font: Font = row.player.get_theme_font("font")
		var available := maxf(80, row.button.size.x - 112 - row.score.get_combined_minimum_size().x - (row.delta.get_combined_minimum_size().x if row.delta.visible else 0))
		var name_width := minf(available * .42, name_font.get_string_size(row.player.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14 if compact else 18).x)
		row.names.custom_minimum_size.x = name_width
		var text_width := maxf(32, minf(140, available - name_width - 16))
		row.bubble.label.custom_minimum_size.x = text_width
		var text_height: float = row.bubble.label.get_theme_font("font").get_multiline_string_size(row.bubble.label.text, HORIZONTAL_ALIGNMENT_LEFT, text_width, 13).y
		height = maxf(height, text_height + 14)
		height = maxf(height, row.bubble.panel.get_combined_minimum_size().y)
	row.button.custom_minimum_size.y = height


func set_entries(entries: Array, active_seat := -1) -> void:
	var key := JSON.stringify([entries, active_seat, compact])
	if key == _entry_key: return
	_entry_key = key
	var blue := get_theme_constant("blue_studio", "GamePalette") == 1
	rows.clear()
	for index in entries.size():
		var seat := int(entries[index].get("seat", index))
		if not _rows_by_seat.has(seat): _rows_by_seat[seat] = _create_row(seat)
		rows.append(_rows_by_seat[seat])
	for row in _rows_by_seat.values(): row.button.visible = rows.has(row)
	for index in rows.size():
		var row: Dictionary = rows[index]
		var entry: Dictionary = entries[index]
		if row.button.get_index() != index: move_child(row.button, index)
		row.identity = Color.from_string(str(entry.get("color", "#7860cc")), Color("7860cc"))
		row.pose = int(entry.get("pose", 0))
		row.avatar.queue_redraw()
		row.player.text = str(entry.get("display_name", "Player"))
		row.player.add_theme_font_size_override("font_size", 14 if compact else 18)
		row.score.text = str(entry.get("score", 0))
		row.score.add_theme_font_size_override("font_size", 16 if compact else 21)
		for label in [row.player, row.score]: label.add_theme_color_override("font_color", Color("e6effa") if blue else Color("30324a"))
		row.delta.add_theme_color_override("font_color", GameLook.guess_color("correct", blue))
		row.rank.visible = entry.has("rank")
		var rank := int(entry.get("rank", 0))
		row.rank.text = str(rank) + ("st" if rank == 1 else "nd" if rank == 2 else "rd" if rank == 3 else "th")
		var medal: String = entry.get("medal", "")
		row.rank.add_theme_color_override("font_color", GameLook.medal_color(medal, blue))
		row.note.text = str(entry.get("note", ""))
		row.note.visible = not row.note.text.is_empty()
		row.note.add_theme_color_override("font_color", GameLook.guess_color(entry.get("quality", "wrong"), blue))
		var speech: String = entry.get("speech", "")
		row.bubble.panel.visible = not speech.is_empty()
		row.bubble.label.text = speech
		row.bubble.label.add_theme_color_override("font_color", GameLook.guess_color(entry.get("quality", "wrong")))
		var bubble_style := GameLook.speech_bubble()
		if blue: bubble_style.bg_color = Color("e4f2ff")
		row.bubble.panel.add_theme_stylebox_override("panel", bubble_style)
		row.bubble.panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.bubble.label.custom_minimum_size.x = minf(100, row.bubble.label.get_theme_font("font").get_string_size(speech, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)
		row.names.size_flags_stretch_ratio = 1.0
		row.bubble.panel.size_flags_stretch_ratio = 1.0
		row.delta.text = "+%d" % int(entry.get("delta", 0))
		row.delta.visible = int(entry.get("delta", 0)) > 0
		row.button.custom_minimum_size.y = (44 if compact else 56) + (18 if row.note.visible else 0)
		for state in ["normal", "hover", "pressed", "disabled"]:
			row.button.add_theme_stylebox_override(state, GameLook.standings_row(row.seat == active_seat, medal, state == "hover", blue))
		row.button.accessibility_name = "%s, %s points%s. Open player statistics and history" % [row.player.text, row.score.text, ", " + row.rank.text + " place" if row.rank.visible else ""]
		_fit_speech.call_deferred(row)
