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
	var delta := Label.new(); delta.add_theme_color_override("font_color", GameLook.guess_color("correct")); content.add_child(delta)
	var score := Label.new(); score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; content.add_child(score)
	for control in [rank, avatar, names, player, note, delta, score]:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label in [player, score]: label.add_theme_color_override("font_color", Color("30324a"))
	var row := {"button": button, "content": content, "player": player, "score": score, "rank": rank, "avatar": avatar, "note": note, "delta": delta, "seat": seat, "identity": Color.WHITE, "pose": 0}
	button.pressed.connect(func() -> void: player_selected.emit(seat))
	avatar.draw.connect(func() -> void: GameLook.draw_table_avatar(avatar, Rect2(Vector2.ZERO, avatar.size), row.identity, row.pose))
	return row


func set_entries(entries: Array, active_seat := -1) -> void:
	var key := JSON.stringify([entries, active_seat, compact])
	if key == _entry_key: return
	_entry_key = key
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
		row.rank.visible = entry.has("rank")
		var rank := int(entry.get("rank", 0))
		row.rank.text = str(rank) + ("st" if rank == 1 else "nd" if rank == 2 else "rd" if rank == 3 else "th")
		var medal: String = entry.get("medal", "")
		row.rank.add_theme_color_override("font_color", GameLook.medal_color(medal))
		row.note.text = str(entry.get("note", ""))
		row.note.visible = not row.note.text.is_empty()
		row.note.add_theme_color_override("font_color", GameLook.guess_color(entry.get("quality", "wrong")))
		row.delta.text = "+%d" % int(entry.get("delta", 0))
		row.delta.visible = int(entry.get("delta", 0)) > 0
		row.button.custom_minimum_size.y = (44 if compact else 56) + (18 if row.note.visible else 0)
		for state in ["normal", "hover", "pressed", "disabled"]:
			row.button.add_theme_stylebox_override(state, GameLook.standings_row(row.seat == active_seat, medal, state == "hover"))
		row.button.accessibility_name = "%s, %s points%s. Open player statistics and history" % [row.player.text, row.score.text, ", " + row.rank.text + " place" if row.rank.visible else ""]