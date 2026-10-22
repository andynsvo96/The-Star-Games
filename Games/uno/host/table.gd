extends Control

signal card_pressed(card_id: int)
signal draw_pressed
signal uno_pressed
signal keep_pressed
signal swap_pressed(target: int)
signal player_pressed(target: int)
signal viewer_pressed(target: int)
signal discard_pressed
const Rules = preload("res://Games/uno/host/rules.gd")
const Presentation = preload("res://Games/uno/host/presentation.gd")
var state: Dictionary = {}
var textures: Dictionary = {}
var hand_hits: Array = []
var seat_rects: Array = []
var deck_rect: Rect2
var top_rect: Rect2
var fan_centers: Array[Vector2] = []
var fan_angles: Array[float] = []
var fan_rects: Array[Rect2] = []
var orbit_rect: Rect2
var orbit_radii := Vector2.ZERO
var orbit_center := Vector2.ZERO
var orbit_top_radius := 0.0
var pile_caption_rects: Array[Rect2] = []
var hand_rect: Rect2
var notice_rect: Rect2
var flights: Array = []
var flight_age := 0.0
var previous_top: Dictionary = {}
var flip_before: Dictionary = {}
var arrow_phase := 0.0
var hand_drag := GameDragScroll.new()
var pointer_revision := -1
var uno_button: Button
var sort_button: Button
var draw_button: Button
var discard_button: Button
var replay_button: Button
var sort_mode := "color"
var last_size := Vector2.ZERO
var hand_start := 0
var hand_from := 0.0
var hand_age := 1.0
var hand_position := 0.0
var hand_spacing := 1.0
var hand_left: Button
var hand_right: Button
var pointer_hand := false
var effects: Array = []
var drawn_rect := Rect2()
var drawn_play: Button
var drawn_keep: Button
var deal_clock := 0.0
var swap_buttons: Array[Button] = []
var held_stack := 0
var hold_age := 0.0
const SUIT_COLORS := {"red": Color("ed202e"), "yellow": Color("f7cf05"), "green": Color("08a750"), "blue": Color("0869db"), "pink": Color("f03b8b"), "teal": Color("00a99d"), "orange": Color("f58220"), "purple": Color("8a4ed2")}
var UNO_LOGO = RuntimeAssets.texture("res://Games/uno/art/uno-logo.webp")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_resized)


func _resized() -> void:
	if last_size.x > 0 and last_size.y > 0:
		for flight in flights: flight.origin *= size / last_size
	last_size = size
	queue_redraw()


func _ready() -> void:
	get_window().focus_exited.connect(func() -> void: held_stack = 0)
	for seat in 6:
		var button := Button.new()
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for mode in ["normal", "hover", "pressed", "disabled"]: button.add_theme_stylebox_override(mode, StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", GameLook.box(Color.TRANSPARENT, GameLook.CREAM, 18, 3))
		add_child(button)
		button.hide()
		button.pressed.connect(func() -> void:
			if _player_target(seat):
				if _swap_target(seat): swap_pressed.emit(seat)
				else: player_pressed.emit(seat)
			elif _badge_viewable(seat): viewer_pressed.emit(seat)
		)
		swap_buttons.append(button)
	discard_button = Button.new()
	for mode in ["normal", "hover", "pressed", "disabled"]: discard_button.add_theme_stylebox_override(mode, StyleBoxEmpty.new())
	discard_button.add_theme_stylebox_override("focus", GameLook.box(Color.TRANSPARENT, GameLook.CREAM, 10, 2))
	discard_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	discard_button.accessibility_name = "Reopen this card's choice"
	discard_button.pressed.connect(func() -> void:
		if _discard_choice(): discard_pressed.emit()
	)
	add_child(discard_button)
	discard_button.hide()
	uno_button = Button.new()
	GameLook.illustrated_control(uno_button, UNO_LOGO, false, true)
	uno_button.add_theme_constant_override("icon_max_width", 106)
	uno_button.accessibility_name = "Declare UNO before playing your penultimate card"
	GameLook.party_action(uno_button, "call")
	GameLook.compact_control(uno_button)
	add_child(uno_button)
	uno_button.pressed.connect(func() -> void: uno_pressed.emit())
	uno_button.hide()
	sort_button = Button.new()
	sort_button.text = "⇅ COLOR"
	GameLook.party_action(sort_button, "sort")
	add_child(sort_button)
	sort_button.pressed.connect(func() -> void:
		if state.is_empty(): return
		sort_mode = "playable" if sort_mode == "color" else "color"
		hand_start = 0
		hand_position = 0
		hand_age = 1.0
		held_stack = 0
		_sort_hand()
		queue_redraw()
	)
	sort_button.hide()
	drawn_play = Button.new()
	drawn_play.text = "PLAY CARD"
	GameLook.action(drawn_play, true)
	GameLook.compact_control(drawn_play)
	add_child(drawn_play)
	drawn_play.pressed.connect(func() -> void: card_pressed.emit(int(state.drawn)))
	drawn_keep = Button.new()
	drawn_keep.text = "KEEP CARD"
	GameLook.action(drawn_keep, false)
	GameLook.compact_control(drawn_keep)
	add_child(drawn_keep)
	drawn_keep.pressed.connect(func() -> void: keep_pressed.emit())
	drawn_play.hide()
	drawn_keep.hide()
	for direction in [-1,1]:
		var button := Button.new()
		add_child(button)
		GameLook.action(button, false)
		GameLook.compact_control(button)
		button.custom_minimum_size = Vector2(44,44)
		# Keep the full end stack tappable around its smaller visible browse cue.
		for mode in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(mode, StyleBoxEmpty.new())
		button.hide()
		button.button_down.connect(func() -> void:
			held_stack = direction
			hold_age = 0.0
			_shift_hand(direction * 3)
		)
		button.button_up.connect(func() -> void: held_stack = 0)
		if direction < 0: hand_left = button
		else: hand_right = button


func card_texture(card: Dictionary, display_size := Vector2.ZERO) -> Texture2D:
	if _before_flip() and card.has("id"):
		var prior: Array = flip_before.get("hand", []).filter(func(face: Dictionary) -> bool: return face.id == card.id)
		if not prior.is_empty(): card = prior[0]
		elif card.has("opposite"): card = card.opposite
	var prefix := Rules.card_art_prefix(card, state.get("gamemode", "classic"))
	var key := prefix + "%s-%s" % [card.color, card.kind]
	if card.color == "wild" and card.get("selected_color", "") in Rules.COLORS + Rules.DARK_COLORS:
		key = prefix + "%s-%s-chosen" % [card.selected_color, card.kind]
	var requested_scale := clampi(ceili(maxf(display_size.x / 120, display_size.y / 180)), 1, 8)
	if not textures.has(key) or (textures[key] is DPITexture and int(textures[key].get_meta("svg_scale", 1)) < requested_scale):
		textures[key] = RuntimeAssets.scalable_texture("res://Games/uno/art/cards/%s.svg" % key, display_size)
	return textures[key]


func _before_flip() -> bool:
	for flight in flights:
		if flight.kind == "flip": return flight_age < flight.start + .24
	return false


func _visual_deck_back() -> Dictionary:
	return flip_before.get("deck_back", {"color":"wild","kind":"back"}) if _before_flip() else state.get("deck_back", {"color":"wild","kind":"back"})


func _visual_backs() -> Array:
	if not state.get("revealed_hands", []).is_empty(): return state.revealed_hands
	return flip_before.get("backs", []) if _before_flip() else state.get("backs", [])


func _badge_viewable(seat: int) -> bool:
	if state.is_empty() or state.viewer < 0 or state.paused or state.animating or _dealing() or not flights.is_empty() or state.phase == "finished": return false
	var offered: Dictionary = state.get("addon_choice", {})
	if offered.get("kind", "") == "chat_take": return offered.get("target", -1) == seat
	return offered.is_empty() and state.get("revealed_cards", {}).has(seat)


func _discard_choice() -> bool:
	return not state.is_empty() and state.viewer >= 0 and state.turn == state.viewer and not state.paused and not state.animating and not _dealing() and flights.is_empty() and (state.phase in ["opening_color", "drawn_color", "flip_color", "roulette_color"] or state.get("addon_choice", {}).get("kind", "") in ["text", "combo_color"])


func _draw_card(texture: Texture2D, rect: Rect2, transpose := false, modulate := Color.WHITE) -> void:
	var scale_x := 1.0
	for flight in flights:
		if flight.kind == "flip":
			var age: float = flight_age - flight.start
			if age >= 0 and age < .48: scale_x = maxf(.015, absf(cos(age / .48 * PI)))
	var shown := Rect2(rect.position + Vector2(rect.size.x * (1 - scale_x) / 2, 0), Vector2(rect.size.x * scale_x, rect.size.y))
	GameLook.draw_party_card(self, texture, shown, modulate)


func positions() -> Array:
	if state.viewer >= 0:
		if size.y < 300 and size.x > size.y * 1.8:
			var compact: Array = [Vector2(.73, 0)]
			for index in range(1, state.players.size()): compact.append(Vector2((index - .5) / (state.players.size() - 1) * .48, 0))
			return compact
		if size.x >= 800:
			var top_y := .04
			var owner_y := .55
			if state.players.size() == 4: return [Vector2(.5,owner_y), Vector2(.14,.20), Vector2(.5,top_y), Vector2(.86,.20)]
			if state.players.size() == 5: return [Vector2(.5,.06), Vector2(.14,.36), Vector2(.13,-.03), Vector2(.87,-.03), Vector2(.86,.36)]
			return [Vector2(.5,owner_y), Vector2(.14,.36), Vector2(.13,-.03), Vector2(.5,top_y), Vector2(.87,-.03), Vector2(.86,.36)]
		var result := [Vector2(.5, .17)]
		for index in range(1, state.players.size()): result.append(Vector2((index - .5) / (state.players.size() - 1), 0))
		return result
	if size.y < 300 and size.x > size.y * 1.8:
		var result: Array = []
		for index in state.players.size(): result.append(Vector2((index + .5) / state.players.size(), 0))
		return result
	if size.x < 500 and size.y > size.x:
		var top_count := ceili(state.players.size() / 2.0)
		var result: Array = []
		for index in state.players.size():
			var top: bool = index < top_count
			var column: int = index if top else index - top_count
			var columns: int = top_count if top else state.players.size() - top_count
			result.append(Vector2((column + .5) / columns, .02 if top else .75))
		return result
	if state.players.size() == 4: return [Vector2(.5,-.06), Vector2(.86,.35), Vector2(.5,.80), Vector2(.14,.35)]
	if state.players.size() == 5: return [Vector2(.5,-.10), Vector2(.87,.05), Vector2(.85,.53), Vector2(.15,.53), Vector2(.13,.05)]
	return [Vector2(.34,-.10), Vector2(.66,-.10), Vector2(.88,.07), Vector2(.88,.52), Vector2(.12,.52), Vector2(.12,.07)]


func spot(seat: int) -> Vector2:
	var index := posmod(seat - int(state.viewer), state.players.size()) if state.viewer >= 0 else seat
	var point: Vector2 = positions()[index] * size
	# Keep the complete top badge below the shared content viewport's clipped edge.
	if size.x >= 800: point.y = maxf(point.y, 24 - global_position.y)
	return point


func _ui_scale() -> float:
	return clampf(size.x / 1000.0, 1, 1.75)


func _action_height() -> float:
	return 48 * _ui_scale()


func show_state(next: Dictionary) -> void:
	var reset: bool = state.is_empty() or state.get("round_id", "") != next.get("round_id", "")
	var prior := state
	state = next.duplicate()
	if not state.has("player_choice"): state.player_choice = Presentation.player_choice(state)
	_sort_hand()
	var next_deal: Dictionary = next.get("deal", {})
	if next_deal.get("revision", -1) != prior.get("deal", {}).get("revision", -1): deal_clock = 0.0
	deal_clock = maxf(deal_clock,float(next_deal.get("elapsed", 0)))
	if next.paused or reset or prior.get("revision", -1) != next.revision: held_stack = 0
	if reset or next.paused: effects.clear()
	if not reset and not next.paused and next.get("feedback", {}).get("revision", -1) != prior.get("feedback", {}).get("revision", -1):
		for effect in next.get("feedback", {}).get("events", []):
			var visual: Dictionary = effect.duplicate()
			visual.age = 0.0
			visual.duration = .75 if effect.kind == "uno" else 1.1
			effects.append(visual)
	var prior_uno: Array = prior.get("uno_players", [])
	effects = effects.filter(func(effect: Dictionary) -> bool:
		return effect.kind != "uno" or (state.phase != "finished" and (effect.seat >= prior_uno.size() or not prior_uno[effect.seat] or _uno_active(effect.seat)))
	)
	for seat in state.players.size():
		if _uno_active(seat) and not effects.any(func(effect: Dictionary) -> bool: return effect.kind == "uno" and effect.seat == seat):
			# Refresh restores the hovering marker without repeating the declaration pop.
			effects.append({"kind":"uno", "seat":seat, "age":.75, "duration":.75})
	if reset or (sort_mode == "playable" and (prior.get("legal_cards", []) != state.get("legal_cards", []) or prior.get("hand", []) != state.hand or (prior.get("turn", -1) != state.turn and state.turn == state.viewer))): hand_start = 0
	hand_start = clampi(hand_start,0,maxi(0,state.hand.size() - 7))
	if reset or next.reduced_motion or next.paused or prior.get("hand", []) != next.hand:
		hand_from = hand_start
		hand_age = 1.0
		hand_position = hand_start; hand_drag.down = false
	if hand_drag.down and prior.get("revision", -1) != next.revision:
		hand_drag.down = false; hand_position = hand_start; hand_from = hand_start; hand_age = 1.0
	if reset or next.reduced_motion or next.paused:
		flip_before.clear()
		flights.clear()
		flight_age = 0
	else:
		if not next.motion.is_empty() and prior.get("motion", {}).get("revision", -1) != next.motion.revision:
			if next.motion.flights.any(func(flight: Dictionary) -> bool: return flight.kind == "flip"): flip_before = prior.duplicate(true)
			if flights.is_empty():
				flight_age = 0
				previous_top = prior.top.duplicate()
			var delay := 0.0
			if not flights.is_empty():
				for running in flights: delay = maxf(delay, running.start + running.duration)
			for flight in Rules.motion_timeline(next.motion).flights:
				if flight.count <= 0: continue
				var part: Dictionary = flight.duplicate(true)
				part.start = delay + flight.start
				part.origin = _hand_center(part.seat)
				if part.kind == "hand" and part.seat == state.viewer and hand_rect.has_area(): part.origin = hand_rect.get_center()
				if part.kind == "play" and part.seat == state.viewer:
					for hit in hand_hits:
						if hit.id == part.card.id: part.origin = hit.rect.get_center()
				flights.append(part)
	queue_redraw()


func _dealing() -> bool:
	return not state.get("reduced_motion", false) and deal_clock < float(state.get("deal", {}).get("duration", 0))


func _transferring(seat: int) -> bool:
	return flights.any(func(flight: Dictionary) -> bool: return flight.kind == "hand" and (flight.seat == seat or flight.target == seat) and flight_age < flight.start + flight.duration)


func _swap_target(seat: int) -> bool:
	return state.get("phase", "") == "swap" and state.get("swap_seat", -1) == state.get("viewer", -1) and state.get("viewer", -1) >= 0 and state.get("swap_targets", []).has(seat) and not state.paused and not state.animating and not _dealing() and flights.is_empty()


func _player_target(seat: int) -> bool:
	return not state.is_empty() and state.get("player_choice", {}).get("targets", []).has(seat) and not state.paused and not state.animating and not _dealing() and flights.is_empty()


func _visible_count(seat: int) -> int:
	for flight in flights:
		if flight.kind == "hand" and flight.seat == seat and flight_age < flight.start + flight.duration: return int(flight.get("hand_count", state.counts[seat]))
	return Rules.dealt_count(seat,state.deal,deal_clock) if _dealing() else int(state.counts[seat])


func _text(value: String, rect: Rect2, font_size: int, tint := Color.WHITE) -> void:
	var font := GameLook.party_font(get_theme_default_font())
	var text := value
	while font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x - 8 and text.length() > 3:
		text = text.left(text.length() - 2) + "…"
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := rect.position + Vector2((rect.size.x - width) / 2.0, rect.size.y / 2.0 + font_size * .35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 1, Color("12101ab0"))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)


func _sort_hand() -> void:
	state.hand = Rules.sorted_hand(state.hand, state.get("colors", Rules.COLORS), state.get("legal_cards", []) if sort_mode == "playable" else [])
	if sort_button != null:
		sort_button.text = "SORT: PLAYABLE" if sort_mode == "playable" else "SORT: COLOR"
		sort_button.accessibility_name = "Sort hand: playable cards first" if sort_mode == "playable" else "Sort hand: colors, numbers, actions, then Wilds"


func _hand_center(seat: int) -> Vector2:
	if seat == state.viewer: return hand_rect.get_center() if hand_rect.has_area() else Vector2(size.x * .5, size.y * .76)
	if seat < fan_centers.size(): return fan_centers[seat]
	return spot(seat) + Vector2(0, 90)


func _fan_bounds(card_size: Vector2, count: int, tilt: float) -> Rect2:
	var bounds := Rect2()
	var gap := card_size.x * (.50 if count < 7 else .42)
	for index in count:
		var offset := float(index) - (count - 1) / 2.0
		var point := Vector2(offset * gap, offset * offset * .65).rotated(tilt)
		var angle := tilt + offset * .035
		for corner in [Vector2(-.5, -.5), Vector2(.5, -.5), Vector2(.5, .5), Vector2(-.5, .5)]:
			var vertex: Vector2 = point + (corner * card_size).rotated(angle)
			bounds = Rect2(vertex, Vector2.ZERO) if index == 0 and corner == Vector2(-.5, -.5) else bounds.expand(vertex)
	return bounds



func _draw() -> void:
	if state.is_empty() or size.x <= 1 or size.y <= 1: return
	var scale := size.x / 1000.0
	var ui_scale := _ui_scale()
	var phone := size.x < 500 and size.y > size.x * .7
	var local: bool = state.viewer >= 0
	var short := size.y < 300 and size.x > size.y * 1.8
	var wide_local := local and size.x >= 800 and not short
	var label_scale := scale if phone or short else ui_scale
	var box := Vector2(maxf(128, 236 * ui_scale), maxf(48, (62 if state.players.size() == 6 else 66) * ui_scale))
	if phone:
		box.x = size.x / ceili(state.players.size() / 2.0) - 8
		box.y = 44 if local else 52
	if local: box.x = minf(240, (size.x - 12 * (state.players.size() - 2)) / (state.players.size() - 1))
	if local and size.x >= 800 and not short: box.x = 236 * ui_scale
	if wide_local: box.y = 60 * ui_scale
	if local and short: box.x = size.x * .48 / (state.players.size() - 1) - 8
	if short and not local: box.x = (size.x - 8 * (state.players.size() - 1)) / state.players.size()
	if short: box.y = 44
	var card_width := minf(maxf(54, (140 if local else 96) * scale), size.y * (.135 if local else .22))
	if wide_local: card_width = size.y * .10
	if phone: card_width = size.x * .21
	if short: card_width = minf(size.y * .25, maxf(28, (size.y - 88 - 28) / 1.5))
	var card_size := Vector2(card_width, card_width * 1.5)
	var pile_center := size.x * (.25 if local and short else .5)
	deck_rect = Rect2(Vector2(pile_center - card_width - 22 * scale, size.y * (.165 if local and not phone else .25 if local else .32)), card_size)
	if short: deck_rect.position.y = 88
	top_rect = Rect2(Vector2(pile_center + 22 * scale, deck_rect.position.y), card_size)
	var back := card_texture(_visual_deck_back(), card_size)
	pile_caption_rects.clear()
	for index in 2:
		var pile: Rect2 = [deck_rect, top_rect][index]
		var font_size := 10 if short else maxi(10, int(12 if phone else 15 * ui_scale))
		var caption_width := maxf(pile.size.x, GameLook.party_font(get_theme_default_font()).get_string_size("DRAW" if index == 0 else "DISCARD", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 12 * ui_scale)
		pile_caption_rects.append(Rect2(pile.position + Vector2((pile.size.x - caption_width) / 2, pile.size.y + 4 * ui_scale), Vector2(caption_width, 18 * ui_scale)))
	var ring_top := -INF
	if wide_local:
		var fan_width := minf(68 * scale, size.y * .10)
		var fan_height := _fan_bounds(Vector2(fan_width, fan_width * 1.5), 7, 0).size.y
		for seat in state.players.size():
			var point := spot(seat)
			if seat != state.viewer and point.x > size.x * .3 and point.x < size.x * .7:
				ring_top = point.y + box.y + fan_height + 6 * scale + 8 * ui_scale
	_draw_direction_ring(scale, box, ring_top)
	fan_centers.clear()
	fan_angles.clear()
	fan_rects.clear()
	seat_rects.clear()
	for seat in state.players.size():
		var player: Dictionary = state.players[seat]
		var center := spot(seat)
		var bounds := Rect2(center - Vector2(box.x / 2, 0), box)
		if local:
			if seat == state.viewer:
				var own_width := box.x if wide_local else minf(354 * ui_scale, size.x * (.44 if short else .76))
				var own_y := 0.0 if short else maxf(top_rect.end.y + 28 * ui_scale, orbit_rect.end.y + 6 * ui_scale)
				bounds = Rect2(Vector2(size.x * (.73 if short else .5) - own_width / 2, own_y), Vector2(own_width, box.y if wide_local else 32 if short else 38 * ui_scale if not phone else 50))
			else: bounds.position.x = clampf(bounds.position.x, 0, size.x - box.x)
		var top_seat: bool = size.x >= 800 and not short and center.x > size.x * .3 and center.x < size.x * .7 and seat != state.viewer
		if top_seat and not wide_local:
			var top_scale := minf(ui_scale, 1.2) if local else ui_scale
			bounds.size = Vector2(236, 52 if local else 60) * top_scale
			bounds.position.x = center.x - bounds.size.x / 2
		var seat_label_scale := label_scale
		seat_rects.append(bounds)
		var active: bool = state.turn == seat and not state.paused and not _dealing() and state.winner < 0
		GameLook.draw_party_player(self, bounds, Color(str(player.color)), active)
		var avatar_size := minf(minf(62 * ui_scale, bounds.size.y - 10 * ui_scale), bounds.size.x * .3)
		if short and not local: avatar_size = 20
		GameLook.draw_table_avatar(self, Rect2(bounds.position + Vector2(6, (bounds.size.y - avatar_size) / 2), Vector2.ONE * avatar_size), Color(str(player.color)), int(player.get("pose", 0)), true, seat == state.winner and not state.animating and flights.is_empty())
		var inset := avatar_size + 14 * ui_scale
		if short and not local: inset = 28
		var own_inline: bool = local and seat == state.viewer and not wide_local
		var name_rect := Rect2(bounds.position + Vector2(inset, 0 if own_inline else 2), Vector2(bounds.size.x - inset - (80 * ui_scale if own_inline else 6), bounds.size.y if own_inline else bounds.size.y * .44))
		_text(str(player.display_name), name_rect, maxi(11, int(22 * seat_label_scale)))
		swap_buttons[seat].visible = _player_target(seat) or _badge_viewable(seat)
		if swap_buttons[seat].visible:
			var target: Button = swap_buttons[seat]
			var extra_height := maxf(0, 44 - bounds.size.y)
			target.position = bounds.position - Vector2(0, extra_height / 2)
			target.size = bounds.size + Vector2(0, extra_height)
			target.accessibility_name = ("View cards shown by %s, %d cards" if _badge_viewable(seat) else "Swap hands with %s, %d cards" if _swap_target(seat) else "Choose %s, %d cards") % [player.display_name, state.counts[seat]]
			if state.player_choice.get("multiple", false): target.accessibility_name += ", draw %d; press to cycle from zero to four" % int(state.player_choice.amounts.get(seat, 0))
		if _badge_viewable(seat): GameLook.draw_turn_glow(self, bounds, get_theme_color("gold", "GamePalette"), .5 if state.reduced_motion else (sin(arrow_phase * 3) + 1) / 2)
		var icons: Array = []
		for effect: Dictionary in Presentation.relationships(state):
			if effect.seats.has(seat) and not icons.has(effect.icon): icons.append(effect.icon)
		if _badge_viewable(seat): icons.append("res://Games/uno/art/rules/addon-billie-eilish.svg")
		var icon_size := minf(18 * ui_scale, avatar_size * .55)
		for index in icons.size(): draw_texture_rect(RuntimeAssets.texture(icons[index]), Rect2(bounds.position + Vector2(6 + index * icon_size * .8, bounds.size.y - icon_size - 2), Vector2.ONE * icon_size), false)
		var count: int = _visible_count(seat)
		var out: bool = not state.get("eliminated", []).is_empty() and state.eliminated[seat]
		if seat == state.winner or out:
			var result_rect := Rect2(Vector2(bounds.end.x - 80 * ui_scale, bounds.position.y), Vector2(74 * ui_scale, bounds.size.y)) if own_inline else Rect2(bounds.position + Vector2(inset, bounds.size.y * .48), Vector2(bounds.size.x - inset, bounds.size.y * .48))
			_text("WINNER" if seat == state.winner else "OUT", result_rect, maxi(11, int(15 * ui_scale if own_inline else 17 * scale)))
		else:
			var count_origin := Vector2(bounds.end.x - 70 * ui_scale, bounds.position.y + bounds.size.y * .68) if own_inline else bounds.position + Vector2(inset + 8, bounds.size.y * .83)
			GameLook.draw_table_stats(self, count_origin, 64 * ui_scale if own_inline else bounds.size.x - inset - 10, [{"icon":"cards", "value":count}], maxi(13, int(28 * seat_label_scale)), true)
		if seat == state.viewer and active:
			var tab := Rect2(Vector2(bounds.get_center().x - 52 * ui_scale, bounds.end.y - 2), Vector2(104, 20) * ui_scale)
			tab.size.y = 16 * ui_scale
			draw_style_box(GameLook.box(get_theme_color("gold", "GamePalette"), Color("fff2b3"), 10, 1), tab)
			_text("YOUR TURN", tab, int(11 * ui_scale), GameLook.INK)
		elif seat == state.viewer and not state.paused and not _dealing() and state.winner < 0 and state.phase == "play":
			_text("%s's turn" % state.players[state.turn].display_name, Rect2(Vector2(bounds.position.x, bounds.end.y + 3), Vector2(bounds.size.x, 18 * ui_scale)), maxi(11, int(13 * ui_scale)), Color("d4e6f5"))
		var side := -1.0 if center.x < size.x * .3 else 1.0 if center.x > size.x * .7 else 0.0
		var tilt := side * .28 if size.x >= 800 and not short else 0.0
		var fan_width := clampf((48 if side == 0 else 60 if state.players.size() == 6 else 68) * scale, 22, 116)
		if wide_local: fan_width = minf(68 * scale, size.y * .10)
		if phone or short: fan_width = clampf(box.x * .25, 15, 28)
		if local and not wide_local and not short and not phone and side == 0 and seat != state.viewer:
			fan_width = minf(fan_width, maxf(16, (orbit_rect.position.y - maxf(8, 8.5 * scale) - bounds.end.y - 6 * scale) / 1.5))
		var fan_size := Vector2(fan_width, fan_width * 1.5)
		var shown := mini(count, 7)
		var fan_bounds := _fan_bounds(fan_size, shown, tilt)
		var anchor := Vector2(bounds.get_center().x - fan_bounds.get_center().x, bounds.end.y + 6 * scale - fan_bounds.position.y)
		fan_centers.append(anchor)
		fan_angles.append(tilt)
		fan_rects.append(Rect2(anchor + fan_bounds.position, fan_bounds.size))
		if seat == state.viewer or out or _transferring(seat): continue
		var gap := fan_width * (.50 if shown < 7 else .42)
		for index in shown:
			var offset := float(index) - (shown - 1) / 2.0
			var angle := tilt + offset * .035
			var point := anchor + Vector2(offset * gap, offset * offset * .65).rotated(tilt)
			draw_set_transform(point, angle)
			_draw_card(card_texture(_visual_backs()[seat][index], fan_size) if not _visual_backs().is_empty() and index < _visual_backs()[seat].size() else back, Rect2(-fan_size / 2, fan_size), false)
			draw_set_transform(Vector2.ZERO)
	GameLook.draw_party_card(self, back, deck_rect, Color.WHITE, clampf(card_width * .11, 5, 18), true)
	var face: Dictionary = state.top
	if _before_flip():
		for flight in flights:
			if flight.kind == "play": face = flight.card
	for flight in flights:
		if flight.kind == "play" and flight_age < flight.start + flight.duration:
			face = previous_top
			break
	var reveal := clampf((deal_clock - float(state.get("deal", {}).get("duration", 0)) + Rules.DEAL_REVEAL) / Rules.DEAL_REVEAL,0,1) if _dealing() else 1.0
	if reveal > 0:
		var reveal_rect := Rect2(top_rect.position + Vector2(top_rect.size.x * (1 - reveal) / 2,0),Vector2(top_rect.size.x * reveal,top_rect.size.y))
		GameLook.draw_party_card(self, card_texture(face, top_rect.size), reveal_rect, Color.WHITE, clampf(card_width * .06, 3, 9), true)
	if state.get("pending_draw", 0) > 0 and not _dealing():
		var badge := Rect2(top_rect.position + Vector2(top_rect.size.x * .42,-maxf(12,18 * scale)),Vector2(maxf(44,62 * scale),maxf(28,36 * scale)))
		draw_style_box(GameLook.box(GameLook.CREAM,SUIT_COLORS.get(state.color,GameLook.RED)),badge)
		_text("+%d" % state.pending_draw,badge,maxi(18,int(26 * scale)),GameLook.INK)
	discard_button.visible = _discard_choice()
	discard_button.position = top_rect.position
	discard_button.size = top_rect.size
	if discard_button.visible: GameLook.draw_turn_glow(self, top_rect, get_theme_color("gold", "GamePalette"), .5 if state.reduced_motion else (sin(arrow_phase * 3) + 1) / 2)
	for index in 2:
		_text("DRAW" if index == 0 else "DISCARD", pile_caption_rects[index], 10 if short else maxi(10, int(12 if phone else 15 * ui_scale)))
	hand_hits.clear()
	hand_rect = Rect2()
	if not local or state.hand.size() <= 7:
		hand_left.hide()
		hand_right.hide()
	if local and not state.hand.is_empty(): _draw_hand(scale)
	drawn_rect = Rect2()
	var draw_decision: bool = local and state.get("drawn", -1) >= 0 and state.turn == state.viewer and state.phase in ["play", "drawn_color"] and not state.paused
	drawn_play.visible = draw_decision
	drawn_keep.visible = draw_decision and not state.get("options", {}).get("force_play", false)
	if draw_decision:
		_draw_drawn_card(scale)
	var ready: bool = local and state.get("can_uno", state.hand.size() == 2) and (state.turn == state.viewer or not state.get("jump_cards", []).is_empty()) and not state.get("uno_armed", false) and not state.paused and not state.animating and not _dealing() and flights.is_empty()
	uno_button.visible = local
	GameLook.set_illustrated_control_disabled(uno_button, not ready)
	sort_button.visible = local and state.phase != "finished"
	# Sorting only changes presentation, so it stays available through turns and motion.
	var action_width := minf(158 * ui_scale, size.x * (.135 if short else .27))
	var action_y := size.y - _action_height() - 4
	var action_center := size.x * (.73 if short else .5)
	var action_step := minf(action_width + (6 if short else 12), size.x * .32)
	for item in [[uno_button, 0], [sort_button, 1]]:
		var button: Button = item[0]
		button.position = Vector2(action_center + action_step * item[1] - action_width / 2, action_y)
		button.position.x = clampf(button.position.x, 0, size.x - action_width)
		button.size = Vector2(action_width, _action_height())
		button.add_theme_font_size_override("font_size", 10 if short else 12 if phone else int(16 * ui_scale))
	if replay_button != null:
		replay_button.position = sort_button.position
		replay_button.size = sort_button.size
		replay_button.clip_text = true
		replay_button.add_theme_font_size_override("font_size", 10 if short else 12 if phone else int(16 * ui_scale))
	sort_button.text = "SORT\n" + ("PLAYABLE" if sort_mode == "playable" else "COLOR") if short else "SORT: PLAYABLE" if sort_mode == "playable" else "SORT: COLOR"
	uno_button.add_theme_constant_override("icon_max_width", int(minf(action_width - 12, 106 * ui_scale)))
	if draw_button != null:
		draw_button.position = Vector2(maxf(0, action_center - action_step - action_width / 2), action_y)
		draw_button.size = Vector2(action_width, _action_height())
		draw_button.clip_text = true
		var draw_caption := "+%d" if short else "DRAW %d"
		draw_button.text = draw_caption % state.pending_draw if state.pending_draw > 0 else "DRAW"
		draw_button.accessibility_name = "Draw %d cards" % state.pending_draw if state.pending_draw > 0 else "Draw one card"
		draw_button.add_theme_font_size_override("font_size", 10 if short else 12 if phone else int(16 * ui_scale))
		draw_button.add_theme_constant_override("icon_max_width", int(14 if short else 22 * ui_scale))
		GameLook.center_button_contents(draw_button)
	if ready: GameLook.draw_turn_glow(self, Rect2(uno_button.position, uno_button.size), GameLook.RED, .5 if state.reduced_motion else (sin(arrow_phase * 4) + 1) / 2)
	_draw_flights()
	_draw_deal()
	_draw_effects(scale)
	notice_rect = Rect2()
	if state.paused or (state.phase == "roulette_color" and not state.animating and flights.is_empty()) or (state.winner >= 0 and not state.animating and flights.is_empty() and (local or size.y >= 230)):
		var notice := Rect2(Vector2(size.x * (.46 if local and short else .22),size.y * (.50 if local and short else .64 if local else .82)),Vector2(size.x * .56,maxf(34,42 * scale)))
		if wide_local and state.winner >= 0:
			notice = Rect2(Vector2(size.x * .70, size.y * .68), Vector2(size.x * .28, maxf(34, 42 * scale)))
		notice_rect = notice
		draw_style_box(GameLook.modern_table_sheet(),notice)
		var caption: String = "Tap a glowing name to swap" if local and state.phase == "swap" and state.swap_seat == state.viewer and not state.paused else str(state.status)
		_text(caption,notice,maxi(12,int(20 * scale)))


func _draw_direction_ring(scale: float, badge_size: Vector2, minimum_top := -INF) -> void:
	var piles := deck_rect.merge(top_rect)
	var half_width := maxf(5, 8.5 * scale)
	var headroom := half_width * 3.3 + maxf(4, 4 * scale)
	var center := piles.get_center() + Vector2(0, piles.size.y * .36)
	var radii := Vector2(piles.size.x * 1.10, piles.size.x * .38)
	var short := size.y < 300 and size.x > size.y * 1.8
	if size.x >= 800 and not short:
		for seat in state.players.size():
			if seat == state.viewer: continue
			var point := spot(seat)
			if point.x < size.x * .3 or point.x > size.x * .7:
				var clearance := absf(point.x - center.x) - badge_size.x / 2 - headroom - 10 * _ui_scale()
				radii.x = minf(radii.x, clearance)
		radii.x = maxf(radii.x, piles.size.x * .5 + headroom)
	radii.x = minf(radii.x, maxf(piles.size.x * .5 + headroom, minf(center.x, size.x - center.x) - headroom))
	# One circle projected onto the tabletop keeps both halves on the same ellipse.
	# Offset its center toward the labels rather than stretching only the lower arc.
	radii.y = radii.x * .38
	for index in 2:
		var caption := pile_caption_rects[index]
		var font_size := 10 if short else 12 if size.x < 500 else int(15 * _ui_scale())
		var width := GameLook.party_font(get_theme_default_font()).get_string_size("DRAW" if index == 0 else "DISCARD", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 8
		var rect := Rect2(Vector2(caption.get_center().x - width / 2, caption.position.y), Vector2(width, caption.size.y))
		for corner in [rect.end, rect.position + Vector2(0, rect.size.y)]:
			var factor := sqrt(maxf(.1, 1 - pow((corner.x - center.x) / radii.x, 2)))
			radii.y = maxf(radii.y, (absf(corner.y - center.y) + half_width * 3.3 * .38 + 4 * scale) / factor)
	var outer := Vector2.ONE + Vector2.ONE * half_width * 3.3 / radii.x
	var extent := radii * outer
	var shift := maxf(0, minimum_top - (center.y - extent.y))
	if shift > 0:
		center.y += shift
		deck_rect.position.y += shift
		top_rect.position.y += shift
		for index in pile_caption_rects.size(): pile_caption_rects[index].position.y += shift
	orbit_center = center
	orbit_radii = radii
	orbit_top_radius = radii.y
	orbit_rect = Rect2(center - extent, extent * 2)
	var phase: float = -2.35 if state.reduced_motion else -2.35 + arrow_phase * .32 * state.direction
	var tint := Color("ffe37b")
	for ribbon in _direction_ribbons(scale, phase):
		draw_polyline(ribbon, Color(tint, .12), maxf(7, 8 * scale), true)
		draw_colored_polygon(ribbon, tint)


func _direction_ribbons(scale: float, phase: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var center := orbit_center
	var radii := orbit_radii
	var half_width := maxf(5, 8.5 * scale)
	var thickness := half_width / radii.x
	for section in 2:
		var ribbon := PackedVector2Array()
		var inner := PackedVector2Array()
		var arc := 2.35
		for step in 65:
			var angle: float = phase + section * PI + state.direction * step / 64.0 * arc
			var radial := Vector2(cos(angle), sin(angle))
			ribbon.append(center + radial * radii * (1 + thickness))
			inner.insert(0, center + radial * radii * (1 - thickness))
		var end_angle: float = phase + section * PI + state.direction * arc
		var radial := Vector2(cos(end_angle), sin(end_angle))
		var tangent: Vector2 = Vector2(-sin(end_angle), cos(end_angle)) * state.direction
		ribbon.append(center + radial * radii * (1 + thickness * 2.15))
		ribbon.append(center + (radial + tangent * thickness * 3.3) * radii)
		ribbon.append(center + radial * radii * (1 - thickness * 2.15))
		ribbon.append_array(inner)
		result.append(ribbon)
	return result


func _draw_hand(scale: float) -> void:
	var large: bool = state.hand.size() > 7
	var shown: int = state.hand.size()
	var short := size.y < 300 and size.x > size.y * 1.8
	var width := minf(maxf(52, 150 * scale), size.y * (.24 if short else .23))
	if size.x < 500 and size.y > size.x: width = size.x * .24
	var reserve := 18.0 if large else 0.0
	var bottom_room := _action_height() + 12
	if short:
		width = minf(width, maxf(28, (size.y - bottom_room - seat_rects[state.viewer].end.y - 24) / 1.5))
	else:
		width = minf(width, maxf(36, (size.y - bottom_room - seat_rects[state.viewer].end.y - 20 * _ui_scale()) / 1.5))
	var hand_width := size.x * (.45 if short else .94)
	var edge := width * .14
	var spacing := minf(width * .68, maxf(5, (hand_width - reserve * 2 - edge * 2 - width) / maxf(1, mini(7, shown) - 1)))
	hand_spacing = spacing
	var total_width := width + (mini(7, shown) - 1) * spacing + reserve * 2 + edge * 2
	var start := size.x * (.73 if short else .5) - total_width / 2
	var y := size.y - bottom_room - width * 1.5
	hand_rect = Rect2(Vector2(start, y - 16), Vector2(total_width, width * 1.5 + 22))
	var progress := clampf(hand_age / .26,0,1)
	var eased := progress * progress * (3 - 2 * progress)
	var offset := hand_position if hand_drag.down and hand_drag.dragged and pointer_hand else lerpf(hand_from,hand_start,eased)
	for piled in [true,false]:
		for index in mini(shown,_visible_count(state.viewer)):
			var is_piled: bool = index < hand_start or index >= hand_start + 7
			if is_piled != piled: continue
			var card: Dictionary = state.hand[index]
			var choices: Array = Presentation.hand_choice(state)
			var available: Array = choices if not choices.is_empty() else state.legal_cards
			var legal: bool = not is_piled and available.has(card.id) and not state.paused and not state.animating and not _dealing() and hand_age >= .26
			var selected: bool = state.get("selected_card", -1) == card.id
			var relative := index - offset
			var distance := relative if relative < 0 else relative - 6 if relative > 6 else 0.0
			var depth := minf(4,absf(distance))
			var x := start + edge + reserve + clampf(relative,0,6) * spacing + signf(distance) * depth * minf(4,width * .06)
			var fan_center := (mini(7, shown) - 1) / 2.0
			var fan_offset := clampf(relative, 0, mini(6, shown - 1)) - fan_center
			var angle := fan_offset * (.025 if short else .035)
			var curve: float = fan_offset * fan_offset * (1.0 if short else 1.4)
			var rect := Rect2(Vector2(x,y + curve + depth * 1.5 - (10 * scale if selected else 6 * scale if legal else 0)),Vector2(width,width * 1.5))
			if not _transferring(state.viewer):
				draw_set_transform(rect.get_center(), angle)
				var dim: bool = state.turn == state.viewer and (state.phase == "play" or not choices.is_empty()) and not state.paused and not state.animating and not _dealing() and flights.is_empty() and not available.has(card.id)
				_draw_card(card_texture(card, rect.size),Rect2(-rect.size / 2,rect.size),false,Color(.70,.70,.70) if dim else Color.WHITE)
				draw_set_transform(Vector2.ZERO)
			if not is_piled: hand_hits.append({"rect":rect,"angle":angle,"id":card.id,"legal":legal})
	if large:
		for direction in [-1,1]:
			var button := hand_left if direction < 0 else hand_right
			var amount: int = hand_start if direction < 0 else maxi(0,shown - hand_start - 7)
			button.visible = amount > 0
			button.text = ""
			button.position = Vector2(start if direction < 0 else start + total_width - 44,y)
			button.custom_minimum_size = Vector2.ZERO
			button.size = Vector2(44,maxf(44, width * 1.5))
			button.disabled = state.paused or state.animating or _dealing() or state.get("drawn", -1) >= 0
			button.accessibility_name = "Show %s cards; %d stacked" % ["previous" if direction < 0 else "next", amount]
			if button.visible and not _transferring(state.viewer): GameLook.draw_party_hand_hint(self, Rect2(button.position, button.size), direction, amount, button.disabled)


func _draw_drawn_card(scale: float) -> void:
	var own: Dictionary = state.hand.filter(func(card: Dictionary) -> bool: return card.id == state.drawn)[0]
	draw_style_box(GameLook.box(Color("100b1973"),Color.TRANSPARENT,12,0),hand_rect.grow(5))
	var width := minf(hand_rect.size.y * .66,maxf(64,112 * scale))
	var button_width := maxf(82,105 * scale)
	var left := hand_rect.get_center().x - (width + button_width + 10) / 2
	drawn_rect = Rect2(Vector2(left,hand_rect.get_center().y - width * .75 - 5),Vector2(width,width * 1.5))
	_draw_card(card_texture(own, drawn_rect.size),drawn_rect,false)
	for button in [drawn_play,drawn_keep]:
		button.disabled = state.animating or not flights.is_empty()
		button.size = Vector2(button_width,button.get_combined_minimum_size().y)
	drawn_play.position = Vector2(drawn_rect.end.x + 10,drawn_rect.get_center().y - drawn_play.size.y - 3)
	drawn_keep.position = Vector2(drawn_rect.end.x + 10,drawn_rect.get_center().y + 3)


func _draw_deal() -> void:
	if not _dealing(): return
	var back := card_texture(_visual_deck_back())
	if deal_clock < Rules.DEAL_SHUFFLE:
		for index in 4:
			var wave := sin(deal_clock * 26 + index * PI / 2)
			draw_set_transform(deck_rect.get_center() + Vector2(wave * deck_rect.size.x * .22,index * -2),wave * .12)
			_draw_card(back,Rect2(-deck_rect.size / 2,deck_rect.size),false)
			draw_set_transform(Vector2.ZERO)
		return
	for index in state.players.size() * 7:
		var age: float = deal_clock - Rules.DEAL_SHUFFLE - index * Rules.DEAL_STEP
		if age < 0 or age >= Rules.DEAL_FLIGHT: continue
		var seat := posmod(int(state.deal.dealer) + 1 + index,state.players.size())
		var target := _hand_center(seat)
		var t: float = age / Rules.DEAL_FLIGHT
		var eased: float = t * t * (3 - 2 * t)
		var point := deck_rect.get_center().lerp(target,eased) - Vector2(0,sin(t * PI) * size.y * .08)
		var width := lerpf(deck_rect.size.x,deck_rect.size.x * .7,t)
		draw_set_transform(point,sin(t * PI) * .18)
		_draw_card(card_texture(state.backs[seat][index / state.players.size()]) if not state.get("backs", []).is_empty() else back,Rect2(Vector2(-width / 2,-width * .75),Vector2(width,width * 1.5)),false)
		draw_set_transform(Vector2.ZERO)


func _uno_active(seat: int) -> bool:
	var declarations: Array = state.get("uno_players", [])
	return seat >= 0 and seat < declarations.size() and declarations[seat] and state.counts[seat] == 1 and state.phase != "finished"


func _uno_logo_rect(effect: Dictionary, scale: float) -> Rect2:
	var center := _hand_center(effect.seat)
	var logo_size := Vector2(maxf(64,110 * scale),maxf(34,58 * scale))
	var still: bool = state.reduced_motion or state.paused
	var pop := 1.0 if still else minf(1.15,.65 + effect.age / .75 * 5) if effect.age < .09 else 1.0
	if _uno_active(effect.seat):
		var settle := 1.0 if still else smoothstep(.35,.75,effect.age)
		var hover_size := logo_size * .62
		var hover := Vector2(spot(effect.seat).x,seat_rects[effect.seat].end.y + 4 * scale + hover_size.y / 2 + 2)
		if effect.seat == state.viewer:
			var card_rect: Rect2 = hand_hits[0].rect if not hand_hits.is_empty() else hand_rect
			var width := clampf(card_rect.size.x * .95,50,90)
			hover_size = Vector2(width,width * 58 / 110)
			hover = Vector2(card_rect.get_center().x,card_rect.position.y - hover_size.y / 2 - 6)
		center = center.lerp(hover,settle)
		logo_size = logo_size.lerp(hover_size,settle)
		if not still:
			var breath := sin(effect.age * TAU / 1.8) * settle
			center.y -= breath * maxf(1.5,2.5 * scale)
			pop *= 1 + breath * .035
	return Rect2(center - logo_size * pop / 2,logo_size * pop)


func _draw_effects(scale: float) -> void:
	for effect in effects:
		var center := _hand_center(effect.seat)
		if effect.seat == state.viewer: center = hand_rect.get_center() - Vector2(0,hand_rect.size.y * .15)
		else: center = Vector2(spot(effect.seat).x,seat_rects[effect.seat].end.y + maxf(12,22.5 * scale) + 4 * scale)
		if effect.kind != "uno" and effects.any(func(other: Dictionary) -> bool: return other.seat == effect.seat and other.kind == "uno"):
			center.y += maxf(26,35 * scale)
		var t: float = effect.age / effect.duration
		var pop := 1.0 if state.reduced_motion else minf(1.15,.65 + t * 5) if t < .12 else 1.0
		var alpha := 1.0 if state.reduced_motion else minf(1,(1 - t) * 5)
		if effect.kind == "uno":
			draw_texture_rect(UNO_LOGO,_uno_logo_rect(effect,scale),false,Color(1,1,1,1.0 if _uno_active(effect.seat) else alpha))
		else:
			var caption: String = {"skip":"⊘ SKIPPED", "reverse":"↔ REVERSE", "wild":str(effect.color).to_upper(), "stack":"+%d" % effect.amount, "draw":"+%d · SKIPPED" % effect.amount, "jump":"JUMP-IN", "seven":"7 · SWAP", "swap":"SWAPPED", "pass":"PASSED", "out":"OUT", "flip":str(state.get("side", "light")).to_upper() + " SIDE"}.get(effect.kind, "")
			var badge_size := Vector2(maxf(90,145 * scale),maxf(28,36 * scale)) * pop
			var badge := Rect2(center - badge_size / 2,badge_size)
			draw_style_box(GameLook.box(Color(GameLook.CREAM,alpha),Color(SUIT_COLORS.get(effect.color,GameLook.RED),alpha),12,2),badge)
			_text(caption,badge,maxi(11,int(16 * scale)),Color(GameLook.INK,alpha))


func _draw_flights() -> void:
	var back := card_texture(_visual_deck_back())
	for flight in flights:
		if flight.kind == "flip": continue
		if flight.kind == "hand":
			_draw_hand_flight(flight)
			continue
		for index in flight.count:
			var age: float = flight_age - flight.start - index * .10
			if age < 0 or age > .48: continue
			var t := clampf(age / .48,0,1)
			var eased := t * t * (3 - 2 * t)
			var origin: Vector2 = flight.origin if flight.kind in ["play", "hand"] else deck_rect.get_center()
			var target := top_rect.get_center() if flight.kind == "play" else _hand_center(flight.target if flight.kind == "hand" else flight.seat)
			var point := origin.lerp(target,eased) + Vector2(0,-sin(t * PI) * size.y * .13)
			var width := top_rect.size.x * (1 + sin(t * PI) * .12)
			draw_set_transform(point,sin(t * PI) * .18 * state.direction)
			_draw_card(card_texture(flight.card) if flight.kind == "play" else card_texture(flight.backs[index]) if flight.has("backs") else back,Rect2(Vector2(-width / 2,-width * .75),Vector2(width,width * 1.5)),false)
			draw_set_transform(Vector2.ZERO)


# One moving fan represents the complete hand, including its end stacks.
func _draw_hand_flight(flight: Dictionary) -> void:
	var age: float = flight_age - flight.start
	if age >= flight.duration: return
	var t := clampf(age / float(flight.duration), 0, 1)
	var eased := t * t * (3 - 2 * t)
	var point: Vector2 = flight.origin.lerp(_hand_center(flight.target), eased) - Vector2(0, sin(t * PI) * size.y * .10)
	var count: int = int(flight.get("hand_count", 1))
	var shown := mini(7, count)
	var small := maxf(16, 30 * size.x / 1000.0)
	var large: float = hand_hits[0].rect.size.x if not hand_hits.is_empty() else minf(maxf(48, 82 * size.x / 1000.0), size.y * .18)
	var width := lerpf(large if flight.seat == state.viewer else small, large if flight.target == state.viewer else small, eased)
	var spacing := width * (.68 if flight.seat == state.viewer else .34)
	spacing = lerpf(spacing, width * (.68 if flight.target == state.viewer else .34), eased)
	var backs: Array = flight.get("backs", [])
	var back := card_texture(_visual_deck_back())
	for index in shown:
		var face: Texture2D = card_texture(backs[index]) if index < backs.size() else back
		var offset := Vector2((index - (shown - 1) / 2.0) * spacing, 0)
		if count > 7 and index == shown - 1:
			for depth in range(mini(4, count - 7), 0, -1):
				draw_set_transform(point + offset + Vector2((-1 if index == 0 else 1) * depth * 3, depth * 1.5))
				draw_texture_rect(face, Rect2(Vector2(-width / 2, -width * .75), Vector2(width, width * 1.5)), false)
		draw_set_transform(point + offset, (index - (shown - 1) / 2.0) * .06 + sin(t * PI) * .08 * state.direction)
		draw_texture_rect(face, Rect2(Vector2(-width / 2, -width * .75), Vector2(width, width * 1.5)), false)
	draw_set_transform(Vector2.ZERO)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		held_stack = 0
	elif event is InputEventScreenTouch and not event.pressed:
		held_stack = 0


func _gui_input(event: InputEvent) -> void:
	if state.is_empty() or state.viewer < 0: return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_LEFT,MOUSE_BUTTON_WHEEL_RIGHT] and hand_rect.has_point(event.position) and state.hand.size() > 7:
		_shift_hand(-3 if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_LEFT] else 3)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_pointer(event.position)
		else: _end_pointer(event.position)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_drag_pointer(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed: _begin_pointer(event.position)
		else: _end_pointer(event.position)
	elif event is InputEventScreenDrag: _drag_pointer(event.position)


func _begin_pointer(point: Vector2) -> void:
	hand_drag.begin(point)
	pointer_revision = state.revision
	pointer_hand = hand_rect.has_point(point) and state.hand.size() > 7
	hand_position = hand_start


func _drag_pointer(point: Vector2) -> void:
	var delta := hand_drag.move(point)
	if pointer_hand and pointer_revision == state.revision and _can_browse_hand():
		hand_position = clampf(hand_position + delta / hand_spacing, 0, maxi(0, state.hand.size() - 7))
		hand_start = roundi(hand_position); queue_redraw()
	accept_event()


func _end_pointer(point: Vector2) -> void:
	var tapped := hand_drag.end()
	if pointer_revision != state.revision: return
	if not tapped:
		if pointer_hand:
			hand_from = hand_position; hand_age = 1.0 if state.reduced_motion else 0.0; queue_redraw()
		accept_event()
	else: _tap(point)


func _can_browse_hand() -> bool:
	return not state.paused and not state.animating and not _dealing() and flights.is_empty() and hand_age >= .26 and state.get("drawn", -1) < 0


func _shift_hand(distance: int) -> void:
	if not _can_browse_hand(): return
	var next := clampi(hand_start + distance,0,maxi(0,state.hand.size() - 7))
	if next == hand_start: return
	hand_from = hand_start
	hand_start = next
	hand_age = 1.0 if state.reduced_motion else 0.0
	queue_redraw()


func _tap(point: Vector2) -> void:
	if state.paused or state.animating or _dealing() or not flights.is_empty() or hand_age < .26: return
	if state.get("drawn", -1) >= 0:
		if drawn_rect.has_point(point): card_pressed.emit(int(state.drawn))
		accept_event()
		return
	for index in range(hand_hits.size() - 1,-1,-1):
		var hit: Dictionary = hand_hits[index]
		var local_point: Vector2 = (point - hit.rect.get_center()).rotated(-float(hit.get("angle", 0))) + hit.rect.get_center()
		if hit.rect.has_point(local_point):
			if hand_hits[index].legal: card_pressed.emit(hand_hits[index].id)
			accept_event()
			return
	if deck_rect.has_point(point) and not state.get("auto_draw", false): draw_pressed.emit()


func _process(delta: float) -> void:
	if state.is_empty() or state.paused: return
	hand_age += delta
	if _dealing(): deal_clock += delta
	if held_stack != 0:
		hold_age += delta
		if hold_age >= .30:
			hold_age = 0.0
			_shift_hand(held_stack * 3)
	for effect in effects: effect.age += delta
	effects = effects.filter(func(effect: Dictionary) -> bool: return effect.age < effect.duration or (effect.kind == "uno" and _uno_active(effect.seat)))
	if not state.reduced_motion:
		arrow_phase += delta
	if not flights.is_empty():
		flight_age += delta
		var end := 0.0
		for flight in flights: end = maxf(end, flight.start + flight.duration)
		if flight_age >= end:
			flights.clear()
			flip_before.clear()
	queue_redraw()


func stop_presentation() -> void:
	state.clear()
	flights.clear()
	effects.clear()
	held_stack = 0
	for button in swap_buttons + [uno_button, sort_button, drawn_play, drawn_keep, hand_left, hand_right, discard_button]: button.hide()
	set_process(false)
	queue_redraw()
