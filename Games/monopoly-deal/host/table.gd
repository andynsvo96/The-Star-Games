extends Control

signal card_selected(card: Dictionary)
signal card_inspected(card: Dictionary)
signal public_requested(seat: int)
signal group_requested(seat: int, group_id: int)
signal end_turn
var state: Dictionary = {}:
	set(value):
		state = value
		elapsed = float(state.get("motion", {}).get("elapsed", 0))
		motion_key = int(state.get("motion", {}).get("revision", -1))
		_refresh_activity.call_deferred()
var hits: Array = []
var hand_offset := 0
var armed_doubles: Array = []
var selected_card := -1
var selected_side := 0
var selected_group_seat := -1
var selected_group_id := -1
var action_row := GameActionRow.new()
var end_button := Button.new()
var previous := Button.new()
var next := Button.new()
var drag := GameDragScroll.new()
var hand_canvas := Control.new()
var hand_scroll := 0.0
var hand_step := 60.0
var hand_bounds := Rect2()
var hand_card_size := Vector2.ZERO
var deck_bounds := Rect2()
var discard_bounds := Rect2()
var seat_bounds: Dictionary = {}
var stack_bounds: Dictionary = {}
var group_bounds: Dictionary = {}
var elapsed := 0.0
var motion_key := -1
var action_key := ""
var activity_log := GameActivityLog.new()
var history_bounds := Rect2()
var shine_elapsed := 0.0


func _ready() -> void:
	theme = GameLook.make_theme("modern-table")
	resized.connect(queue_redraw)
	hand_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE; hand_canvas.clip_contents = true; add_child(hand_canvas); hand_canvas.draw.connect(_paint_hand)
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL; add_child(action_row)
	end_button.text = "▶  End Turn"; GameLook.table_action(end_button, "end"); action_row.add_child(end_button); end_button.pressed.connect(func() -> void: end_turn.emit())
	previous.text = "‹"; next.text = "›"
	for button in [previous, next]: button.custom_minimum_size = Vector2(44, 44); add_child(button)
	previous.pressed.connect(func() -> void: hand_scroll = maxf(0, hand_scroll - hand_step * 3); queue_redraw())
	next.pressed.connect(func() -> void: hand_scroll += hand_step * 3; queue_redraw())


func _refresh_activity() -> void:
	if activity_log.is_node_ready(): activity_log.set_entries(state.get("activity_entries", []), state.get("reduced_motion", false), state.get("paused", false))


func set_actions(commands: Array, key: String) -> void:
	if action_key == key: return
	action_key = key
	for child in action_row.get_children():
		if child != end_button and not child.get_meta("permanent_action", false): action_row.remove_child(child); child.queue_free()
	for command in commands:
		var button := Button.new(); button.text = str(command.label); button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; button.disabled = command.get("disabled", false)
		GameLook.table_action(button, str(command.get("kind", "play"))); button.pressed.connect(command.callback); action_row.add_child(button); action_row.move_child(button, action_row.get_child_count() - 2)


func _hand_count() -> int:
	return 4 if size.x < 550 else 7


func _label(text: String, point: Vector2, width: float, font_size := 16, color := Color.WHITE, centered := false) -> void:
	GameLook.draw_table_text(self, text, point, width, font_size, color, centered)


func _draw() -> void:
	hits.clear(); seat_bounds.clear(); stack_bounds.clear(); group_bounds.clear(); hand_canvas.hide(); previous.hide(); next.hide()
	if state.is_empty(): return
	end_button.text = "End Turn (%d/3)" % int(state.plays_left)
	if size.y < 300 and size.x >= 650 and int(state.winner) < 0:
		_draw_short_table(); _draw_motion(); return
	var local := int(state.viewer)
	var show_hand := local >= 0 and int(state.winner) < 0
	var hand_h := clampf(size.y * .28, 110, 220) if show_hand else 0.0
	var field := Rect2(0, 0, size.x, size.y - hand_h - (12 if show_hand else 0))
	var rail_w := 0.0
	field.position.x = rail_w + (14 if rail_w > 0 else 0); field.size.x -= field.position.x
	var count: int = state.players.size()
	var columns := 3 if field.size.x >= 650 and count != 3 else 2
	var cells := count + 1
	var rows := ceili(float(cells) / columns)
	var gap := 12.0
	var cell := Vector2((field.size.x - gap * (columns - 1)) / columns, (field.size.y - gap * (rows - 1)) / rows)
	var order: Array = range(count)
	if local >= 0: order.erase(local); order.append(local)
	var pile_slot := mini(cells - 2, columns + 1) if columns == 3 else cells - 1
	var seat_index := 0
	for slot in cells:
		var rect := Rect2(field.position + Vector2(slot % columns, slot / columns) * (cell + Vector2.ONE * gap), cell)
		if slot == pile_slot: _paint_piles(rect)
		else:
			_zone(int(order[seat_index]), rect); seat_index += 1
	end_button.visible = local >= 0 and local == int(state.turn) and state.phase == "play" and state.winner < 0
	end_button.disabled = state.paused or state.animating
	if show_hand: _draw_hand(Rect2(0, field.end.y + 12, size.x, hand_h))
	_draw_motion()


func _draw_short_table() -> void:
	var gap := 8.0
	var width: float = (size.x - gap * (state.players.size() - 1)) / state.players.size()
	for seat in state.players.size(): _zone(seat, Rect2(seat * (width + gap), 0, width, 78))
	var lower := Rect2(0, 90, size.x * .37 if int(state.viewer) >= 0 else size.x, maxf(54, size.y - 90))
	_paint_piles(lower)
	end_button.visible = int(state.viewer) >= 0 and int(state.viewer) == int(state.turn) and state.phase == "play" and state.winner < 0
	end_button.disabled = state.paused or state.animating
	if int(state.viewer) >= 0: _draw_hand(Rect2(size.x * .4, 90, size.x * .6, maxf(60, size.y - 90)))


func _draw_order(bounds: Rect2) -> void:
	draw_style_box(GameLook.modern_table_sheet(), bounds)
	_label("Turn order", bounds.position + Vector2(12, 24), bounds.size.x - 24, 16, get_theme_color("muted", "GamePalette"))
	for seat in state.players.size():
		var rect := Rect2(bounds.position + Vector2(8, 40 + seat * 58), Vector2(bounds.size.x - 16, 52))
		if seat == int(state.turn) and state.winner < 0 and not state.paused: draw_style_box(GameLook.modern_table_sheet(true), rect)
		GameLook.draw_table_avatar(self, Rect2(rect.position + Vector2(8, 9), Vector2(32, 32)), Color(state.players[seat].color), int(state.players[seat].get("pose", seat)))
		_label(str(state.players[seat].display_name), rect.position + Vector2(47, 24), rect.size.x - 50, 13)
		if seat == int(state.turn): _label("Playing", rect.position + Vector2(47, 41), rect.size.x - 50, 11, get_theme_color("gold", "GamePalette"))


func _paint_piles(bounds: Rect2) -> void:
	var h := maxf(24, minf(minf(170, bounds.size.y - 38), (bounds.size.x - 12) / (4.0 / 3.0)))
	var card_size := Vector2(h * 2 / 3, h)
	var start := bounds.get_center() - Vector2((card_size.x * 2 + 12) / 2, h / 2 + 15)
	deck_bounds = Rect2(start, card_size)
	discard_bounds = Rect2(start + Vector2(card_size.x + 12, 0), card_size)
	history_bounds = Rect2()
	for index in range(3, -1, -1): GameCard.paint(self, Rect2(deck_bounds.position + Vector2(-index * 1.5, index * 1.5), card_size), {"back": true}, art("back"), Color("173c45"))
	if not state.top.is_empty() and not _pending(int(state.top.id)): _face(state.top, discard_bounds)
	else: draw_style_box(GameLook.box(get_theme_color("panel", "GamePalette"), get_theme_color("panel_edge", "GamePalette"), 6, 1), discard_bounds)
	_label("DRAW · %d" % state.deck_count, Vector2(deck_bounds.position.x - 12, deck_bounds.end.y + 20), card_size.x + 24, 11, Color.WHITE, true)
	_label("DISCARD", Vector2(discard_bounds.position.x - 12, discard_bounds.end.y + 20), card_size.x + 24, 11, Color.WHITE, true)


func _zone(seat: int, bounds: Rect2) -> void:
	var data: Dictionary = state.table[seat]; var owner: Dictionary = state.players[seat]
	seat_bounds[seat] = bounds
	hits.append({"rect":bounds, "seat":seat})
	draw_style_box(GameLook.modern_table_sheet(seat == int(state.turn) and state.winner < 0 and not state.paused), bounds)
	GameLook.draw_table_avatar(self, Rect2(bounds.position + Vector2(10, 9), Vector2(32, 32)), Color(owner.color), int(owner.get("pose", seat)))
	_label("%d  %s" % [seat + 1, owner.display_name], bounds.position + Vector2(50, 23), bounds.size.x - 60, 12 if bounds.size.x < 230 else 15)
	if int(state.winner) == seat:
		var crown := RuntimeAssets.texture("res://ui/playful/table-crown.svg")
		draw_texture_rect(crown, Rect2(bounds.position + Vector2(16, 0), Vector2(23, 17)), false)
	var winner: bool = int(state.winner) == seat
	var compact_winner: bool = winner and bounds.size.x < 300 and bounds.size.y >= 104
	var header_height := 71.0 if compact_winner else 51.0
	var count := int(data.count)
	if state.get("motion", {}).get("active", false):
		for flight in state.motion.flights:
			if flight.to.zone == "hand" and int(flight.to.seat) == seat and elapsed < float(flight.delay) + float(flight.duration): count -= 1
	GameLook.draw_table_stats(self, bounds.position + Vector2(50, 40), bounds.size.x - 60 - (86 if winner and not compact_winner else 0), [{"icon": "cash", "value": "$%d" % data.total}, {"icon": "cards", "value": maxi(0, count)}, {"icon": "house", "value": "%d/3" % data.sets}])
	if winner: GameLook.draw_table_winner(self, Rect2(bounds.position + (Vector2(50, 47) if compact_winner else Vector2(bounds.size.x - 94, 26)), Vector2(84, 19)), shine_elapsed, state.get("reduced_motion", false))
	hits.append({"rect": Rect2(bounds.position, Vector2(bounds.size.x, 46)), "seat": seat})
	if seat != int(state.viewer): stack_bounds[seat] = Rect2(bounds.position + Vector2(bounds.size.x - 28, 12), Vector2(16, 24))
	if data.groups.is_empty(): _label("No properties yet", bounds.position + Vector2(12, 72), bounds.size.x - 24, 12, get_theme_color("muted", "GamePalette")); return
	if bounds.size.y < 104 and not winner:
		_label("%d groups" % data.groups.size(), bounds.position + Vector2(12, 66), bounds.size.x - 24, 11, get_theme_color("selection", "GamePalette"))
		hits.append({"rect": bounds, "seat": seat}); return
	var available := Rect2(bounds.position + Vector2(10, header_height), bounds.size - Vector2(20, header_height + 8))
	var low := 4.0; var high := minf(180, available.size.y - 8)
	# Fit actual fan/building widths instead of charging every set for the
	# widest one. Larger shared card heights remain monotonic under wrapping.
	for step in 10:
		var candidate := (low + high) / 2
		if _group_tiles(data.groups, available, candidate).is_empty(): high = candidate
		else: low = candidate
	var tiles := _group_tiles(data.groups, available, low)
	for index in tiles.size(): _draw_group(seat, data.groups[index], tiles[index])


func _group_tiles(groups: Array, available: Rect2, height: float) -> Array[Rect2]:
	var tiles: Array[Rect2] = []; var offset := Vector2.ZERO
	for group in groups:
		var width: float = height * 2 / 3 + 10 + maxi(0, group.cards.size() - 1) * 4 + (26 if not group.buildings.is_empty() else 0)
		if width > available.size.x + .01: return []
		if offset.x > 0 and offset.x + width > available.size.x + .01: offset.x = 0; offset.y += height + 8
		if offset.y + height + 8 > available.size.y + .01: return []
		tiles.append(Rect2(available.position + offset, Vector2(width, height + 8))); offset.x += width
	return tiles


func _draw_group(seat: int, group: Dictionary, tile: Rect2) -> void:
	var stack_width := maxi(0, group.cards.size() - 1) * 4
	var building_space := 26 if not group.buildings.is_empty() else 0
	var h := maxf(4, minf(minf(180, tile.size.y - 8), (tile.size.x - 10 - stack_width - building_space) * 1.5))
	var w := h * 2 / 3
	var origin := tile.position + Vector2(5, 1)
	var outlined := Rect2(origin - Vector2(3, 3), Vector2(w + stack_width + 6, h + 6))
	if group.complete: draw_style_box(GameLook.box(Color("ffd44722"), get_theme_color("gold", "GamePalette"), 7, 2), outlined)
	elif selected_group_seat == seat and selected_group_id == int(group.id): draw_style_box(GameLook.box(get_theme_color("selection_fill", "GamePalette"), get_theme_color("selection", "GamePalette"), 7, 1), outlined)
	for index in range(group.cards.size() - 1, -1, -1):
		var card: Dictionary = group.cards[index].duplicate(true)
		if _pending(int(card.id)): continue
		if card.kind == "wild" and card.colors.size() == 2: card.face_side = int(group.color == card.colors[1])
		_face(card, Rect2(origin + Vector2(index * 4, 0), Vector2(w, h)), face_schedule(group, card))
	for index in group.buildings.size():
		GameLook.draw_table_building(self, Rect2(origin + Vector2(w + stack_width + 8, 20 + index * 21), Vector2(18, 18)), str(group.buildings[index].kind))
	group_bounds["%d:%d" % [seat, group.id]] = Rect2(origin, Vector2(w, h))


func face_schedule(group: Dictionary, card: Dictionary) -> Dictionary:
	var spec: Dictionary = state.colors[group.color]
	var rows: Array = []
	for index in spec.rent.size():
		var active: bool = index + 1 == mini(group.cards.size(), int(spec.size))
		rows.append({"label": str(index + 1), "count": index + 1, "value": "$%d" % (int(group.rent) if active else int(spec.rent[index])), "active": active})
	var compact: bool = card.kind == "wild" and card.colors.size() == 2
	var area := Rect2(22.0/240, 90.0/360, 200.0/240, 250.0/360)
	if card.kind == "wild": area = Rect2(43.0/240, 86.0/360, 156.0/240, 88.0/360) if compact else Rect2(18.0/240, 104.0/360, 204.0/240, 236.0/360)
	return {"area": area, "rows": rows, "accent": spec.color, "compact": compact, "dim_regions": [Rect2(41.0/240, 186.0/360, 158.0/240, 88.0/360)] if compact else []}


func clear_group_selection() -> void:
	selected_group_seat = -1; selected_group_id = -1; queue_redraw()


func inspector_data(seat: int, group: Dictionary) -> Dictionary:
	var spec: Dictionary = state.colors[group.color]; var items: Array = []
	for source in group.cards + group.buildings:
		var card: Dictionary = source.duplicate(true); card.display_name = state.theme.labels.get(card.key, card.name)
		if card.kind == "wild" and card.colors.size() == 2: card.face_side = int(group.color == card.colors[1])
		items.append({"card": card, "texture": art(card.key), "tint": Color(spec.color)})
	for index in maxi(0, int(spec.size) - group.cards.size()): items.insert(group.cards.size(), {"placeholder": true})
	var rows: Array = [["Owner", state.players[seat].display_name], ["Current rent", "$%d" % group.rent], ["Full set", "$%d" % spec.rent[-1]]]
	if not group.color in ["railroad", "utility"]: rows.append_array([["With House (+$3)", "$%d" % (spec.rent[-1] + 3)], ["With House + Hotel", "$%d" % (spec.rent[-1] + 7)]])
	rows.append(["Buildings", ", ".join(group.buildings.map(func(card: Dictionary) -> String: return str(state.theme.labels.get(card.key, card.name)))) if not group.buildings.is_empty() else "None"])
	return {"title": str(spec.name) + " Set", "subtitle": "%d / %d · %s" % [group.cards.size(), spec.size, "Complete" if group.complete else "In progress"], "items": items, "rows": rows, "slots": int(spec.size)}


func _activate(point: Vector2) -> void:
	for index in range(hits.size() - 1, -1, -1):
		var hit: Dictionary = hits[index]
		if not hit.rect.has_point(point): continue
		if hit.has("card"): card_selected.emit(hit.card)
		elif hit.has("group"):
			selected_group_seat = int(hit.seat); selected_group_id = int(hit.group); queue_redraw()
			group_requested.emit(selected_group_seat, selected_group_id)
		else: public_requested.emit(int(hit.seat))
		return


func _flight_rect(zone: Dictionary) -> Rect2:
	if zone.zone == "deck": return deck_bounds
	if zone.zone == "discard": return discard_bounds
	if zone.zone == "hand" and int(zone.seat) == int(state.viewer): return Rect2(hand_bounds.get_center() - hand_card_size / 2, hand_card_size)
	if zone.zone == "hand" and stack_bounds.has(int(zone.seat)): return stack_bounds[int(zone.seat)]
	var key := "%d:%d" % [int(zone.seat), int(zone.get("group", -1))]
	if group_bounds.has(key): return group_bounds[key]
	var bounds: Rect2 = seat_bounds.get(int(zone.seat), Rect2())
	return Rect2(bounds.position + Vector2(12, 52), Vector2(40, 60))



func _process(delta: float) -> void:
	if not state.get("paused", false) and int(state.get("winner", -1)) >= 0 and not state.get("reduced_motion", false): shine_elapsed += delta; queue_redraw()
	var motion: Dictionary = state.get("motion", {})
	if int(motion.get("revision", -1)) != motion_key:
		motion_key = int(motion.get("revision", -1)); elapsed = float(motion.get("elapsed", 0))
	if motion.get("active", false) and not state.get("paused", false):
		elapsed = minf(float(motion.duration), elapsed + delta); queue_redraw()


func _pending(id: int) -> bool:
	if not state.get("motion", {}).get("active", false): return false
	for flight in state.motion.flights:
		if int(flight.card.get("id", -1)) == id and elapsed < float(flight.delay) + float(flight.duration): return true
	return false


func art(key: String) -> Texture2D:
	return GameCard.artwork("res://Games/monopoly-deal/art/%s.svg" % key)


func _face(card: Dictionary, bounds: Rect2, schedule: Dictionary = {}) -> void:
	var data := card.duplicate(true); data.display_name = state.theme.labels.get(card.key, card.name)
	if not schedule.is_empty(): data.face_schedule = schedule
	GameCard.paint(self, bounds, data, art(card.key), Color(state.colors[card.colors[0]].color) if not card.colors.is_empty() else Color("17594d"), armed_doubles.has(int(card.id)))


func _draw_hand(bounds: Rect2) -> void:
	var shown := mini(_hand_count(), state.hand.size())
	_label("YOUR HAND", bounds.position + Vector2(0, 13), bounds.size.x, 10, get_theme_color("ink", "GamePalette"), true)
	var card_h := maxf(36, bounds.size.y - 23); var card_w := card_h * 2 / 3
	var arrows: bool = state.hand.size() > shown
	var inset := 48.0 if arrows else 2.0
	var step := minf(card_w + 8, (bounds.size.x - inset * 2 - card_w) / maxf(1, shown - 1))
	hand_step = step; hand_card_size = Vector2(card_w, card_h)
	hand_bounds = Rect2(bounds.position + Vector2(inset, 20), Vector2(bounds.size.x - inset * 2, card_h))
	hand_canvas.position = hand_bounds.position; hand_canvas.size = hand_bounds.size; hand_canvas.show()
	hand_scroll = clampf(hand_scroll, 0, maxf(0, (state.hand.size() - 1) * step + card_w - hand_bounds.size.x))
	hand_offset = int(hand_scroll / maxf(1, step)); hand_canvas.queue_redraw()
	if arrows:
		previous.show(); next.show(); previous.size = Vector2(44, 44); next.size = Vector2(44, 44)
		previous.position = Vector2(bounds.position.x, bounds.get_center().y - 10); next.position = Vector2(bounds.end.x - 44, bounds.get_center().y - 10)


func _paint_hand() -> void:
	if state.is_empty() or not state.has("hand"): return
	var start := maxf(0, (hand_bounds.size.x - ((state.hand.size() - 1) * hand_step + hand_card_size.x)) / 2)
	for index in state.hand.size():
		var card: Dictionary = state.hand[index]
		var rect := Rect2(Vector2(start + index * hand_step - hand_scroll, 0), hand_card_size)
		if rect.end.x < 0 or rect.position.x > hand_bounds.size.x or _pending(int(card.id)): continue
		var data := card.duplicate(true)
		if int(card.id) == selected_card and card.kind == "wild" and card.colors.size() == 2: data.face_side = selected_side
		data.display_name = state.theme.labels.get(card.key, card.name)
		GameCard.paint(hand_canvas, rect, data, art(card.key), Color(state.colors[card.colors[0]].color) if not card.colors.is_empty() else Color("17594d"), int(card.id) == selected_card or armed_doubles.has(int(card.id)))
		hits.append({"rect": Rect2(rect.position + hand_bounds.position, rect.size).intersection(hand_bounds), "card": card})


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: drag.begin(event.position); accept_event(); return
		if not drag.end(): accept_event(); return
		_activate(event.position)
		accept_event(); return
	if event is InputEventMouseMotion and drag.down:
		var delta := drag.move(event.position)
		if hand_bounds.has_point(drag.origin): hand_scroll += delta; queue_redraw()
		accept_event()
	if event is InputEventScreenTouch:
		if event.pressed: drag.begin(event.position)
		elif drag.end():
			_activate(event.position)
		accept_event()
	if event is InputEventScreenDrag and drag.down:
		var delta := drag.move(event.position)
		if hand_bounds.has_point(drag.origin): hand_scroll += delta; queue_redraw()
		accept_event()


func _draw_motion() -> void:
	var event: Dictionary = state.get("motion", {})
	if not event.get("active", false): return
	if elapsed < float(event.shuffle):
		for index in 5:
			var offset := Vector2(sin(elapsed * 24 + index * 1.9) * (18 + index * 3), -index * 1.5)
			GameCard.paint(self, Rect2(deck_bounds.position + offset, deck_bounds.size), {"back": true}, art("back"), Color("173c45"))
	for flight in event.flights:
		var progress_value := GameCardMotion.progress(flight, elapsed)
		if elapsed < float(flight.delay) or progress_value >= 1: continue
		var rect := GameCardMotion.travel(_flight_rect(flight.from), _flight_rect(flight.to), progress_value)
		if flight.card.get("back", false): GameCard.paint(self, rect, flight.card, art("back"), Color("173c45"))
		else: _face(flight.card, rect)
