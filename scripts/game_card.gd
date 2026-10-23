class_name GameCard
extends Control

# Reusable composed card surface: semantic text stays separate from skin art.
var card: Dictionary = {}
var texture: Texture2D
var selected := false
var accent := Color("617c76")
static var schedule_bold: SystemFont


static func artwork(path: String) -> Texture2D:
	return RuntimeAssets.scalable_texture(path)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	paint(self, Rect2(Vector2.ZERO, size), card, texture, accent, selected)


static func paint(canvas: CanvasItem, rect: Rect2, data: Dictionary, artwork: Texture2D, tint: Color, chosen := false) -> void:
	if data.get("layout", "") == "character":
		_paint_character(canvas, rect, data, artwork, tint, chosen)
		return
	if data.get("layout", "") == "standard":
		_paint_standard(canvas, rect, data, chosen)
		return
	if artwork is DPITexture and artwork.has_meta("svg_path"):
		artwork = RuntimeAssets.scalable_texture(str(artwork.get_meta("svg_path")), rect.size)
	if data.get("layout", "") == "art":
		if artwork != null: canvas.draw_texture_rect(artwork, rect, false)
		return
	if data.get("layout", "") == "deal":
		if int(data.get("face_side", 0)) % 2 == 1:
			canvas.draw_set_transform(rect.get_center(), PI)
			_paint_deal(canvas, Rect2(-rect.size / 2, rect.size), data, artwork, tint, chosen)
			canvas.draw_set_transform(Vector2.ZERO)
		else: _paint_deal(canvas, rect, data, artwork, tint, chosen)
		if data.has("face_schedule"): _paint_face_schedule(canvas, rect, data.face_schedule)
		if data.has("deed_state"): _paint_deed_state(canvas, rect, data.deed_state)
		if data.get("mortgaged", false): _paint_mortgage(canvas, rect)
		return
	var style := GameLook.box(Color("fff4d9"), Color("ffda72") if chosen else Color("b69a6f"), 7, 3 if chosen else 1)
	style.shadow_size = 2
	canvas.draw_style_box(style, rect)
	var bounds := rect.grow(-4)
	if data.get("back", false):
		if artwork != null: canvas.draw_texture_rect(artwork, bounds, false)
		return
	var font := ThemeDB.fallback_font
	var compact := rect.size.y < 125
	var title_height := rect.size.y * 0.24
	canvas.draw_style_box(GameLook.box(tint, tint, 3, 0), Rect2(bounds.position, Vector2(bounds.size.x, title_height)))
	var title := str(data.get("display_name", data.get("name", "")))
	var font_size := clampi(int(rect.size.x / 9), 9, 17)
	var lines := _wrap(title, font, font_size, bounds.size.x - 6, 3)
	var text_color := GameLook.readable_text_color(Color("fff9e9"), tint)
	for index in lines.size():
		var text: String = lines[index]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		canvas.draw_string(font, Vector2(bounds.get_center().x - width / 2, bounds.position.y + 3 + font_size + index * font_size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	var image_top := bounds.position.y + title_height + 4
	var footer := 22.0 if compact else 42.0
	if artwork != null:
		canvas.draw_texture_rect(artwork, Rect2(Vector2(bounds.position.x, image_top), Vector2(bounds.size.x, maxf(0, bounds.end.y - image_top - footer))), false)
	var value := ("$%d" if data.get("currency", "") == "USD" else "%dM") % int(data.get("value", 0))
	var value_size := 14 if compact else 22
	var value_width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, value_size).x
	canvas.draw_string(font, Vector2(bounds.get_center().x - value_width / 2, bounds.end.y - (5 if compact else 23)), value, HORIZONTAL_ALIGNMENT_LEFT, -1, value_size, Color("2c392e"))
	if not compact:
		var note := str(data.get("foot", ""))
		var note_size := 10
		var note_width := font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, note_size).x
		canvas.draw_string(font, Vector2(bounds.get_center().x - note_width / 2, bounds.end.y - 6), note, HORIZONTAL_ALIGNMENT_LEFT, -1, note_size, Color("3d4b3b"))


static func _paint_character(canvas: CanvasItem, rect: Rect2, data: Dictionary, artwork: Texture2D, tint: Color, chosen: bool) -> void:
	canvas.draw_style_box(GameLook.box(Color("131820"), Color("ffda72") if chosen else tint, 6, 3 if chosen else 1), rect)
	var bounds := rect.grow(-2)
	if artwork != null:
		var source := Rect2(Vector2.ZERO, artwork.get_size())
		var factor := maxf(bounds.size.x / source.size.x, bounds.size.y / source.size.y)
		source.size = bounds.size / factor
		source.position = (artwork.get_size() - source.size) / 2
		canvas.draw_texture_rect_region(artwork, bounds, source)
	if data.get("back", false): return
	var band := Rect2(Vector2(bounds.position.x, bounds.end.y - bounds.size.y * .27), Vector2(bounds.size.x, bounds.size.y * .27))
	canvas.draw_rect(band, Color("131820f2"))
	canvas.draw_rect(Rect2(band.position, Vector2(band.size.x, maxf(2, rect.size.y * .009))), tint)
	var font := ThemeDB.fallback_font
	var font_size := maxi(5, int(rect.size.x * .105))
	var title := str(data.get("display_name", data.get("name", "")))
	while font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > band.size.x - 6 and font_size > 4: font_size -= 1
	canvas.draw_string(font, band.position + Vector2(4, band.size.y * .39), title, HORIZONTAL_ALIGNMENT_CENTER, band.size.x - 8, font_size, Color("fff5dc"))
	for index in 2:
		var text := str(data.get("detail" if index == 0 else "foot", ""))
		var small := maxi(3, int(rect.size.x * .054))
		while font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x > band.size.x - 6 and small > 3: small -= 1
		canvas.draw_string(font, band.position + Vector2(3, band.size.y * (.64 + index * .22)), text, HORIZONTAL_ALIGNMENT_CENTER, band.size.x - 6, small, Color("e0e5ec"))


static func _paint_standard(canvas: CanvasItem, rect: Rect2, data: Dictionary, chosen: bool) -> void:
	var back: bool = data.get("back", false)
	var style := GameLook.box(Color("201b19") if back else Color("fff1d9"), Color("ffe18a") if chosen else Color("b98b4c"), 7, 3 if chosen else 1)
	style.shadow_size = 3; style.shadow_color = Color(0, 0, 0, .4)
	canvas.draw_style_box(style, rect)
	var font := ThemeDB.fallback_font
	var symbols := {"clubs": "♣", "diamonds": "♦", "hearts": "♥", "spades": "♠"}
	var symbol: String = symbols.get(str(data.get("suit", "spades")), "♠")
	var ink := Color("a51b22") if data.get("suit", "") in ["diamonds", "hearts"] else Color("171b19")
	if back:
		canvas.draw_style_box(GameLook.box(Color("2a2421"), Color("98713a"), 5, 1), rect.grow(-rect.size.x * .08))
		for index in 7:
			var x := rect.position.x + rect.size.x * (.15 + index * .116)
			canvas.draw_line(Vector2(x, rect.position.y + rect.size.y * .12), Vector2(minf(rect.end.x - rect.size.x * .12, x + rect.size.x * .35), rect.end.y - rect.size.y * .12), Color("695033"), 1)
		ink = Color("cba361"); symbol = "♠"
	var central_size := maxi(8, int(rect.size.x * (.57 if back else .60)))
	var width := font.get_string_size(symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, central_size).x
	canvas.draw_string(font, rect.get_center() + Vector2(-width / 2, central_size * .32), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, central_size, ink)
	if back: return
	var font_size := maxi(7, int(rect.size.x * .28))
	var rank := str(data.get("rank", ""))
	canvas.draw_string(font, rect.position + Vector2(rect.size.x * .09, font_size + rect.size.y * .035), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	canvas.draw_string(font, rect.position + Vector2(rect.size.x * .10, font_size * 1.75 + rect.size.y * .035), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(6, int(font_size * .72)), ink)
	var rank_width := font.get_string_size(rank, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(font, rect.end - Vector2(rank_width + rect.size.x * .09, rect.size.y * .06), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


static func _paint_deal(canvas: CanvasItem, rect: Rect2, data: Dictionary, artwork: Texture2D, tint: Color, chosen: bool) -> void:
	var style := GameLook.box(Color("fffef7"), Color("ffcf57") if chosen else Color("8c866d"), 5, 3 if chosen else 1)
	style.shadow_size = 3; style.shadow_color = Color(0, 0, 0, .25)
	canvas.draw_style_box(style, rect)
	if artwork != null: canvas.draw_texture_rect(artwork, rect, false)
	# Complete faces already contain outlined lettering. Tiny public previews must
	# not add a minimum-size live heading that spills beyond the face's borders.
	if artwork != null and rect.size.x < 64: return
	var kind := str(data.get("kind", ""))
	if kind in ["money", "reference"]: return
	var title := str(data.get("display_name", data.get("name", "")))
	var area := Rect2(.18, .096, .68, .132)
	var ink := Color("263126")
	var font_size := 21
	if kind == "property":
		ink = Color.WHITE if GameLook.text_contrast(Color.WHITE, tint) > GameLook.text_contrast(ink, tint) else ink
	elif kind == "wild":
		if title == str(data.get("name", "")): return
		area = Rect2(.14, .465, .72, .065); font_size = 11
	else:
		area = Rect2(.23, .365, .54, .22); font_size = 32
		if kind in ["house", "hotel"]: area = Rect2(.23, .56, .54, .10); font_size = 24
		if kind == "pass-go": area = Rect2(.26, .375, .48, .20); font_size = 32
		if kind == "birthday": area = Rect2(.24, .35, .52, .18)
		if kind == "rent": title = "RENT"; font_size = 32
	var target := Rect2(rect.position + area.position * rect.size, area.size * rect.size)
	var font := ThemeDB.fallback_font
	var scaled := maxi(5, int(font_size * rect.size.x / 240.0))
	var lines := _wrap(title.to_upper(), font, scaled, target.size.x - 2, 4)
	while (lines.size() * scaled > target.size.y or lines.any(func(line: String) -> bool: return font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled).x > target.size.x)) and scaled > 5:
		scaled -= 1; lines = _wrap(title.to_upper(), font, scaled, target.size.x - 2, 4)
	var top := target.get_center().y - lines.size() * scaled / 2.0
	for index in lines.size():
		var width := font.get_string_size(lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, scaled).x
		canvas.draw_string(font, Vector2(target.get_center().x - width / 2, top + (index + .83) * scaled), lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, scaled, ink)


static func _schedule_text(canvas: CanvasItem, rect: Rect2, point: Vector2, value: String, font_size: float, ink: Color, active := false) -> void:
	if schedule_bold == null:
		schedule_bold = SystemFont.new(); schedule_bold.font_names = PackedStringArray(["Arial", "Helvetica", "sans-serif"]); schedule_bold.font_weight = 800
	var font: Font = schedule_bold if active else ThemeDB.fallback_font
	var scaled := maxi(1, roundi(font_size * rect.size.x / 240))
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled).x
	canvas.draw_string(font, rect.position + point * rect.size / Vector2(240, 360) - Vector2(width / 2, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled, ink)


static func _paint_deed_state(canvas: CanvasItem, rect: Rect2, state: Dictionary) -> void:
	var scale := rect.size / Vector2(240, 360)
	var area: Array = state.area
	var design := Rect2(area[0], area[1], area[2], area[3])
	canvas.draw_rect(Rect2(rect.position + design.position * scale, design.size * scale), Color("fffef7"))
	var rows: Array = state.rows
	for index in rows.size():
		var row: Dictionary = rows[index]; var active: bool = row.active
		var y := design.position.y + design.size.y * (index + .5) / rows.size()
		var ink := Color("263126") if active else Color("b6bcb5")
		if active: canvas.draw_rect(Rect2(rect.position + Vector2(design.position.x, y - 11) * scale, Vector2(design.size.x, 23) * scale), Color(Color(state.accent), .12))
		var font: Font = ThemeDB.fallback_font
		var font_size := maxi(1, roundi((12 if active else 11) * scale.x))
		canvas.draw_string(font, rect.position + Vector2(29, y + 4) * scale, str(row.label), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		_schedule_text(canvas, rect, Vector2(183, y + 5), str(row.value), 16 if active else 14, ink, active)
	if not str(state.get("badge", "")).is_empty():
		canvas.draw_rect(Rect2(rect.position + Vector2(25, 92) * scale, Vector2(190, 25) * scale), Color("fffef7"))
		GameLook.draw_table_building(canvas, Rect2(rect.position + Vector2(51, 95) * scale, Vector2(16, 16) * scale), str(state.icon))
		_schedule_text(canvas, rect, Vector2(132, 108), str(state.badge), 13, Color("263126"), true)


static func _paint_mortgage(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color("00101c99"))
	canvas.draw_set_transform(rect.get_center(), -.42)
	var banner := Rect2(Vector2(-rect.size.x * .46, -rect.size.x * .095), Vector2(rect.size.x * .92, rect.size.x * .19))
	canvas.draw_style_box(GameLook.box(Color("16303c"), Color("ffb5ad"), 2, 1), banner)
	var font := ThemeDB.fallback_font; var font_size := maxi(1, int(rect.size.x * .115))
	var width := font.get_string_size("MORTGAGED", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(font, Vector2(-width / 2, font_size * .36), "MORTGAGED", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("fff1df"))
	canvas.draw_set_transform(Vector2.ZERO)


static func _paint_face_schedule(canvas: CanvasItem, rect: Rect2, schedule: Dictionary) -> void:
	# Opt-in live rows are drawn upright after the artwork's face rotation. The
	# module supplies normalized regions; readers and other cards keep their art.
	var paper := Color(schedule.get("paper", "fffef7"))
	for region: Rect2 in schedule.get("dim_regions", []):
		canvas.draw_rect(Rect2(rect.position + region.position * rect.size, region.size * rect.size), Color(paper, .78))
	var area: Rect2 = schedule.area
	canvas.draw_rect(Rect2(rect.position + area.position * rect.size, area.size * rect.size), paper)
	var compact: bool = schedule.get("compact", false)
	var rows: Array = schedule.rows
	if rows.is_empty(): return
	var design := Rect2(area.position * Vector2(240, 360), area.size * Vector2(240, 360))
	var ink := Color("263126"); var muted := Color("b8bcb6")
	var left := design.position.x + design.size.x * .17; var right := design.position.x + design.size.x * (.84 if compact else .81)
	var header := 0.0 if compact else 34.0
	if not compact:
		_schedule_text(canvas, rect, Vector2(left, design.position.y + 15), "CARDS", 11, ink)
		_schedule_text(canvas, rect, Vector2(left, design.position.y + 29), "IN SET", 11, ink)
		_schedule_text(canvas, rect, Vector2(right, design.position.y + 26), "RENT", 24, ink, true)
	# Keep short schedules at the top instead of spreading two rows over a face.
	var row_height := minf((design.size.y - header) / rows.size(), 48.0) if not compact else (design.size.y - header) / rows.size()
	var scale := rect.size / Vector2(240, 360)
	for index in rows.size():
		var row: Dictionary = rows[index]; var active: bool = row.get("active", false)
		var color := ink if active else muted
		var y := design.position.y + header + row_height * (index + .5)
		var icon_size := Vector2(23, 19) if compact else Vector2(28, 36)
		var count := 1 if compact else int(row.get("count", index + 1))
		for layer in range(count - 1, -1, -1):
			var marker := Rect2(Vector2(left - icon_size.x / 2 - layer * 4, y - icon_size.y / 2 - layer * 3), icon_size)
			canvas.draw_rect(Rect2(rect.position + marker.position * scale, marker.size * scale), paper)
			canvas.draw_rect(Rect2(rect.position + marker.position * scale, marker.size * scale), color, false, maxf(.5, scale.x))
			if not compact:
				var bar := Rect2(marker.position, Vector2(marker.size.x, 6))
				canvas.draw_rect(Rect2(rect.position + bar.position * scale, bar.size * scale), Color(schedule.get("accent", "617c76")) if active else Color("d5d8d2"))
		_schedule_text(canvas, rect, Vector2(left, y + (6 if compact else 10)), str(row.get("label", index + 1)), (17 if compact else 26) if active else (15 if compact else 24), color, active)
		_schedule_text(canvas, rect, Vector2(right, y + (6 if compact else 10)), str(row.value), (19 if compact else 28) if active else (17 if compact else 25), color, active)
		var dot_start := Vector2(left + icon_size.x / 2 + 9, y); var dot_end := Vector2(right - 23, y)
		canvas.draw_dashed_line(rect.position + dot_start * scale, rect.position + dot_end * scale, color, maxf(.4, scale.x * .8), maxf(1, scale.x * 2))


static func _wrap(value: String, font: Font, font_size: int, width: float, maximum: int) -> Array[String]:
	var result: Array[String] = []
	var line := ""
	for word in value.split(" "):
		var next := word if line.is_empty() else line + " " + word
		if font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and not line.is_empty():
			result.append(line); line = word
		else: line = next
	if not line.is_empty(): result.append(line)
	if result.size() > maximum: result.resize(maximum)
	return result
