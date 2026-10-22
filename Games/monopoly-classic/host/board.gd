extends Control

signal property_pressed(id: int)
var definition: Dictionary = {}
var state: Dictionary = {}
var players: Array = []
var labels: Dictionary = {}
var properties: Dictionary = {}
var selected := -1
var moves: Array = []
var rolls: Array = []
var elapsed := 0.0
var reduced_motion := false
var paused := false
var surface: Texture2D
var title_art: Texture2D
var tokens: Array[Texture2D] = []
var illustrations: Dictionary = {}
const CORNER := 138.0
const CELL := (1000.0 - CORNER * 2) / 9.0


func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func reload_assets() -> void:
	surface = RuntimeAssets.texture("res://Games/monopoly-classic/art/board-surface.svg")
	title_art = RuntimeAssets.texture("res://Games/monopoly-classic/art/collection-title.svg")
	tokens.clear()
	for name in ["hat", "car", "dog", "ship", "thimble", "boot"]: tokens.append(RuntimeAssets.texture("res://Games/monopoly-classic/art/token-%s.svg" % name))
	for name in ["chest", "railroad", "electric", "water", "parking", "jail", "go-to-jail", "luxury-tax", "income-tax", "chance", "go"]:
		illustrations[name] = RuntimeAssets.texture("res://Games/monopoly-classic/art/space-%s.svg" % name)
	queue_redraw()


func set_state(value: Dictionary, roster: Array, names: Dictionary) -> void:
	state = value; players = roster; labels = names
	queue_redraw()


static func cell_rect(index: int) -> Rect2:
	if index == 0: return Rect2(1000 - CORNER, 1000 - CORNER, CORNER, CORNER)
	if index == 10: return Rect2(0, 1000 - CORNER, CORNER, CORNER)
	if index == 20: return Rect2(0, 0, CORNER, CORNER)
	if index == 30: return Rect2(1000 - CORNER, 0, CORNER, CORNER)
	if index < 10: return Rect2(1000 - CORNER - index * CELL, 1000 - CORNER, CELL, CORNER)
	if index < 20: return Rect2(0, 1000 - CORNER - (index - 10) * CELL, CORNER, CELL)
	if index < 30: return Rect2(CORNER + (index - 21) * CELL, 0, CELL, CORNER)
	return Rect2(1000 - CORNER, CORNER + (index - 31) * CELL, CORNER, CELL)


func _draw() -> void:
	if definition.is_empty(): return
	var factor := minf(size.x, size.y) / 1000.0
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * factor)
	draw_style_box(GameLook.box(Color("d2e2ce"), Color("5d4430"), 12, 10), Rect2(0, 0, 1000, 1000))
	if surface != null: draw_texture_rect(surface, Rect2(8, 8, 984, 984), false)
	for index in 40: _draw_space(index, factor)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * factor)
	var center := Rect2(CORNER + 12, CORNER + 12, 1000 - CORNER * 2 - 24, 1000 - CORNER * 2 - 24)
	draw_rect(center, Color("586f5a"), false, 2)
	if title_art != null: draw_texture_rect(title_art, Rect2(245, 310, 510, 110), false)
	for pair in [["community", Vector2(230, 520)], ["chance", Vector2(640, 520)]]:
		var card: Texture2D = GameCard.artwork("res://Games/monopoly-classic/art/%s-back.svg" % pair[0])
		draw_texture_rect(card, Rect2(pair[1], Vector2(105, 157)), false)
	if not state.is_empty():
		for die in 2:
			var point := Vector2(393 + die * 117, 505)
			var value := int(state.dice[die]); var angle := 0.0
			for roll in rolls:
				if elapsed < float(roll.start): break
				value = int(roll.dice[die])
				var progress := (elapsed - float(roll.start)) / float(roll.duration)
				if progress >= 0 and progress < 1 and not reduced_motion:
					value = 1 + posmod(int((elapsed - float(roll.start)) * 20) + die * 3, 6)
					angle = sin(progress * TAU * 3 + die) * .65 * (1 - progress)
					point += Vector2(sin(progress * TAU * 4 + die) * 13, -absf(sin(progress * PI * 4)) * 35) * (1 - progress)
			_draw_die(point, value, angle)
		for seat in players.size():
			if not state.bankrupt[seat]: _draw_token(seat)
	draw_set_transform(Vector2.ZERO)


func space_content(index: int) -> Dictionary:
	var bounds := cell_rect(index)
	var tall := bounds.size.y > bounds.size.x
	var street: bool = properties.has(index) and properties[index].group not in ["railroad", "utility"]
	if index % 10 == 0:
		return {"name": Rect2(bounds.position + Vector2(7, 5), Vector2(bounds.size.x - 14, 31)), "icon": Rect2(bounds.position + Vector2(22, 40), Vector2(94, 76)), "price": Rect2(bounds.position + Vector2(6, 117), Vector2(bounds.size.x - 12, 16))}
	if street:
		return {"name": Rect2(bounds.position + Vector2(5, 29 if tall else 17), Vector2(bounds.size.x - 10, 69 if tall else 34)), "icon": Rect2(), "price": Rect2(bounds.position + Vector2(4, 108 if tall else 55), Vector2(bounds.size.x - 8, 20 if tall else 16))}
	return {"name": Rect2(bounds.position + Vector2(4, 5), Vector2(bounds.size.x - 8, 36 if tall else 23)), "icon": Rect2(bounds.position + (Vector2(7, 47) if tall else Vector2(8, 30)), Vector2(bounds.size.x - 14, 58) if tall else Vector2(58, 44)), "price": Rect2(bounds.position + (Vector2(4, 109) if tall else Vector2(70, 42)), Vector2(bounds.size.x - 8, 20) if tall else Vector2(62, 24))}


func _draw_space(index: int, factor: float) -> void:
	var bounds := cell_rect(index)
	var areas := space_content(index)
	var ink := Color("253428")
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * factor)
	draw_rect(bounds, Color("fffcef")); draw_rect(bounds, ink, false, 1.5)
	var space: Dictionary = definition.board[index]
	var title := str(space.name).to_upper()
	var icon := ""
	if properties.has(index):
		var property: Dictionary = properties[index]
		title = str(labels.get(property.key, property.name)).to_upper()
		if property.group == "railroad": icon = "railroad"
		elif property.group == "utility": icon = "electric" if index == 12 else "water"
		else:
			var band := Rect2(bounds.position, Vector2(bounds.size.x, 23 if bounds.size.y > bounds.size.x else 13))
			draw_rect(band, Color(property.color)); draw_rect(band, ink, false, 1)
			if not state.is_empty():
				var count := int(state.levels[index])
				for house in (1 if count == 5 else count):
					var point := band.position + Vector2(6 + house * 16, 1)
					var color := Color("cd3030") if count == 5 else Color("18763f")
					draw_rect(Rect2(point + Vector2(0, 5), Vector2(23 if count == 5 else 12, 8)), color)
					draw_colored_polygon(PackedVector2Array([point + Vector2(-1, 5), point + Vector2(12 if count == 5 else 6, 0), point + Vector2(24 if count == 5 else 13, 5)]), color)
		_text("$%d" % int(property.price), areas.price, 18, ink, 1)
		if not state.is_empty():
			var owner := int(state.owners[index])
			if owner >= 0: draw_rect(Rect2(bounds.position + Vector2(3, bounds.size.y - 6), Vector2(bounds.size.x - 6, 4)), Color(str(players[owner].color)))
			if state.mortgaged[index]:
				draw_line(bounds.position + Vector2(7, 43), bounds.position + Vector2(bounds.size.x - 7, 65), Color("ae3333"), 3)
	else:
		match str(space.kind):
			"community": title = "COMMUNITY\nCHEST"; icon = "chest"
			"chance": title = "CHANCE"; icon = "chance"
			"tax": title = str(space.name).to_upper().replace(" ", "\n"); icon = "income-tax" if index == 4 else "luxury-tax"
			"go":
				title = "COLLECT $200"; icon = "go"
				_text("GO", Rect2(bounds.position + Vector2(12, 42), Vector2(bounds.size.x - 24, 46)), 43, ink, 1)
			"jail": title = "JAIL"; icon = "jail"; _text("JUST VISITING", areas.price, 15, ink, 1)
			"parking": title = "FREE PARKING"; icon = "parking"
			"go_to_jail": title = "GO TO JAIL"; icon = "go-to-jail"
		if int(space.get("amount", 0)) > 0: _text("$%d" % int(space.amount), areas.price, 18, ink, 1)
	if not icon.is_empty() and illustrations.has(icon):
		var region: Rect2 = areas.icon
		if not properties.has(index) and space.kind in ["community", "chance"] and bounds.size.x > bounds.size.y: region.position.x = bounds.get_center().x - region.size.x / 2
		draw_texture_rect(illustrations[icon], region, false)
	_text(title, areas.name, 20 if index % 10 == 0 else 17, ink, 3)
	if index == selected: draw_rect(bounds.grow(-3), Color("ffcc50"), false, 5)


func _draw_token(seat: int) -> void:
	var position := int(state.positions[seat])
	var center := cell_rect(position).get_center()
	for move in moves:
		if int(move.seat) != seat: continue
		if elapsed < float(move.start): center = cell_rect(int(move.from)).get_center(); break
		if elapsed < float(move.start) + float(move.duration):
			var progress := clampf((elapsed - float(move.start)) / float(move.duration), 0, 1)
			if move.get("teleport", false): center = cell_rect(int(move.from)).get_center().lerp(cell_rect(int(move.to)).get_center(), progress)
			else:
				var steps := posmod(int(move.from) - int(move.to), 40) if move.get("backwards", false) else posmod(int(move.to) - int(move.from), 40)
				var step := progress * steps; var whole_step := int(floor(step)); var direction := -1 if move.get("backwards", false) else 1
				var first := posmod(int(move.from) + whole_step * direction, 40); var second := posmod(first + direction, 40)
				var fraction := step - whole_step
				center = cell_rect(first).get_center().lerp(cell_rect(second).get_center(), smoothstep(0, 1, fraction))
				center.y -= sin(fraction * PI) * 10
			break
		center = cell_rect(int(move.to)).get_center()
	var offset := Vector2((seat % 3 - 1) * 24, (int(seat / 3) - .5) * 25 + 22)
	center += offset
	draw_circle(center + Vector2(0, 8), 20, Color(0, 0, 0, .22))
	draw_circle(center, 20, Color(str(players[seat].color)))
	draw_arc(center, 20, 0, TAU, 32, Color("fff5d1"), 2, true)
	if seat < tokens.size(): draw_texture_rect(tokens[seat], Rect2(center - Vector2(22, 25), Vector2(44, 44)), false)


func _draw_die(point: Vector2, value: int, angle := 0.0) -> void:
	var factor := minf(size.x, size.y) / 1000
	draw_set_transform((point + Vector2(41.5, 41.5)) * factor, angle, Vector2.ONE * factor)
	point = -Vector2(41.5, 41.5)
	draw_style_box(GameLook.box(Color("fffdf2"), Color("c0b59c"), 13, 2), Rect2(point, Vector2(83, 83)))
	var positions: Array = []
	if value % 2 == 1: positions.append(Vector2(.5, .5))
	if value >= 2: positions.append_array([Vector2(.25, .25), Vector2(.75, .75)])
	if value >= 4: positions.append_array([Vector2(.75, .25), Vector2(.25, .75)])
	if value == 6: positions.append_array([Vector2(.25, .5), Vector2(.75, .5)])
	for pip in positions: draw_circle(point + pip * 83, 6, Color("28352e"))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * factor)


func _text(value: String, rect: Rect2, font_size: int, color: Color, max_lines: int) -> void:
	var font := get_theme_font("font")
	var fitted := fit_text(value, rect, font_size, max_lines)
	var lines: Array = fitted.lines; font_size = int(fitted.font_size)
	var top := rect.get_center().y - lines.size() * font_size * .56
	for index in lines.size():
		var line: String = lines[index]; var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(rect.get_center().x - minf(width, rect.size.x) / 2, top + font_size * .85 + index * font_size * 1.12), line, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, font_size, color)


func fit_text(value: String, rect: Rect2, font_size: int, max_lines: int) -> Dictionary:
	var font := get_theme_font("font")
	var lines: Array[String] = []
	while true:
		lines.clear()
		# Explicit line breaks must survive wrapping (Community / Chest).
		for paragraph in value.split("\n"):
			var line := ""
			for word in paragraph.split(" ", false):
				if not line.is_empty() and font.get_string_size(line + " " + word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x:
					lines.append(line); line = word
				else: line += (" " if not line.is_empty() else "") + word
			if not line.is_empty(): lines.append(line)
		if font_size <= 6 or (lines.size() <= max_lines and lines.size() * font_size * 1.12 <= rect.size.y and lines.all(func(line: String) -> bool: return font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= rect.size.x)): break
		font_size -= 1
	return {"lines": lines.slice(0, maxi(1, mini(max_lines, int(rect.size.y / (font_size * 1.12))))), "font_size": font_size}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var point: Vector2 = event.position / (minf(size.x, size.y) / 1000)
		for id in properties:
			if cell_rect(int(id)).has_point(point): property_pressed.emit(int(id)); accept_event(); return
