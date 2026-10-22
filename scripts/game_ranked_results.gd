class_name GameRankedResults
extends Container

# Public, already-ranked results. The module owns ranking, privacy and rewards.
var entries: Array = []
var maximum_height := 420.0
var amount_icon: Texture2D
var columns := 1
var row_height := 78.0
var fitted_height := 0.0


class ResultRow extends Control:
	var entry: Dictionary = {}
	var amount_icon: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func card_rects() -> Array[Rect2]:
		var result: Array[Rect2] = []
		if entry.get("cards", []).is_empty(): return result
		var wide := size.x >= 310
		var gap := 3.0 if wide else 2.0
		var width := minf(46, minf((size.y - 14) / 1.5, (size.x * .49 - gap * 4) / 5)) if wide else minf(34, minf((size.x - 16 - gap * 4) / 5, maxf(12, size.y - 50) / 1.5))
		var left := size.x - 8 - width * 5 - gap * 4 if wide else (size.x - width * 5 - gap * 4) / 2
		var top := (size.y - width * 1.5) / 2 if wide else size.y - 6 - width * 1.5
		for index in entry.cards.size(): result.append(Rect2(Vector2(left + index * (width + gap), top), Vector2(width, width * 1.5)))
		return result

	func _draw() -> void:
		if entry.is_empty(): return
		draw_style_box(GameLook.casino_sheet(int(entry.get("amount", 0)) > 0, true), Rect2(Vector2.ZERO, size))
		var ink := get_theme_color("font_color", "Label")
		var gold := get_theme_color("gold", "GamePalette")
		var name_color := GameLook.readable_text_color(Color(str(entry.get("color", "#fff0cf"))), get_theme_color("panel", "GamePalette"))
		var wide := size.x >= 310
		var faces := card_rects()
		if wide:
			var font_size := 14 if size.y < 72 else 17
			var name_width := (faces[0].position.x - 46 if not faces.is_empty() else size.x - 48)
			GameLook.draw_table_text(self, str(entry.rank), Vector2(9, size.y / 2 + 7), 25, 21, gold, true)
			var top := (size.y - (51 if int(entry.get("amount", 0)) != 0 else 35)) / 2
			GameLook.draw_table_text(self, str(entry.name), Vector2(42, top + 16), name_width, font_size, name_color)
			GameLook.draw_table_text(self, str(entry.category), Vector2(42, top + 34), name_width, 12 if size.y < 72 else 14, ink)
			if int(entry.get("amount", 0)) != 0: _amount(Vector2(42, top + 39), name_width, 13)
		else:
			GameLook.draw_table_text(self, str(entry.rank), Vector2(6, 16), 18, 14, gold, true)
			GameLook.draw_table_text(self, str(entry.name), Vector2(28, 16), size.x - 34, 12, name_color)
			GameLook.draw_table_text(self, str(entry.category), Vector2(6, 29), size.x - 12, 11, ink, true)
			if int(entry.get("amount", 0)) != 0: _amount(Vector2(6, 31), size.x - 12, 11)
		for index in faces.size():
			var marked: bool = entry.get("marked_cards", []).has(index)
			GameCard.paint(self, faces[index], entry.cards[index], null, Color.WHITE, marked)
			if marked and not str(entry.get("card_mark", "")).is_empty():
				var mark := Rect2(faces[index].position + Vector2(2, faces[index].size.y * .67), Vector2(faces[index].size.x - 4, maxf(9, faces[index].size.x * .24)))
				draw_style_box(GameLook.box(gold, gold, 2, 0), mark)
				GameLook.draw_table_text(self, str(entry.card_mark), mark.position + Vector2(0, mark.size.y - 2), mark.size.x, maxi(6, int(mark.size.y - 2)), Color("24251e"), true)

	func _amount(point: Vector2, width: float, font_size: int) -> void:
		var label := str(entry.get("amount_text", ("+" if int(entry.amount) > 0 else "") + str(int(entry.amount))))
		if amount_icon != null: draw_texture_rect(amount_icon, Rect2(point, Vector2(14, 14)), false)
		GameLook.draw_table_text(self, label, point + Vector2(19, 12), width - 19, font_size, get_theme_color("loss" if int(entry.amount) < 0 else "gold", "GamePalette"))


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(queue_sort)


func _get_minimum_size() -> Vector2: return Vector2(0, fitted_height)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN: _fit()


func set_entries(value: Array) -> void:
	entries = value
	for child in get_children(): remove_child(child); child.queue_free()
	for entry in entries:
		var row := ResultRow.new(); row.entry = entry; row.amount_icon = amount_icon
		row.set_meta("result_seat", entry.get("seat", -1)); row.set_meta("result_rank", entry.rank)
		row.accessibility_name = "%s. %s. %s. %s chips." % [entry.rank, entry.name, entry.category, entry.get("amount", 0)]
		for index in entry.get("marked_cards", []):
			if int(index) >= 0 and int(index) < entry.get("cards", []).size(): row.accessibility_name += " %s: %s." % [entry.get("card_mark", "Highlighted card"), entry.cards[int(index)].get("name", "Card")]
		add_child(row)
	_fit.call_deferred()


func _fit() -> void:
	if entries.is_empty(): fitted_height = 0; update_minimum_size(); return
	columns = 1 if entries.size() <= 4 else 2
	if size.x >= 1000 and maximum_height < 360 and entries.size() > 6: columns = 3
	var rows := ceili(float(entries.size()) / columns)
	row_height = minf(86 if size.x / columns < 310 else 80, maxf(56, (maximum_height - (rows - 1) * 6) / rows))
	var width := maxf(0, (size.x - (columns - 1) * 8) / columns)
	for index in get_child_count():
		var row: Control = get_child(index)
		row.position = Vector2((index % columns) * (width + 8), (index / columns) * (row_height + 6))
		row.size = Vector2(width, row_height); row.queue_redraw()
	var height := rows * row_height + (rows - 1) * 6
	if not is_equal_approx(height, fitted_height): fitted_height = height; update_minimum_size()


func card_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for row in get_children():
		for rect in row.card_rects(): result.append(Rect2(row.position + rect.position, rect.size))
	return result
