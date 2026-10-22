extends RefCounted

# Host-only Classic, Flip and No Mercy rules. Wild draw cards have no challenge phase.
enum Difficulty { EASY, MEDIUM, HARD }
const AddOns = preload("res://Games/uno/host/addons.gd")
const COLORS := ["red", "yellow", "green", "blue"]
const DARK_COLORS := ["pink", "teal", "orange", "purple"]
const GAMEMODES := ["classic", "flip", "no_mercy"]
const DRAW_AMOUNTS := {"draw1": 1, "draw2": 2, "draw4": 4, "draw5": 5, "reverse_draw4": 4, "draw6": 6, "draw10": 10}
const DEAL_SHUFFLE := .55
const DEAL_STEP := .065
const DEAL_FLIGHT := .36
const DEAL_REVEAL := .18
var gamemode := "classic"
var side := "light"
var built_mode := ""
var enabled_addons: Dictionary = AddOns.defaults()
var built_addons := ""
var addons = AddOns.new()
var flip_faces: Array = []
var flip_next := -1
var pending_color := ""
var cards: Array = []
var hands: Array = []
var deck: Array = []
var discard: Array = []
var turn := 0
var direction := 1
var color := "red"
var phase := "play"
var drawn := -1
var winner := -1
var dealer := -1
var revision := 0
var round_number := 0
var session_wins: Array = []
var history: Array = []
var plays: Array = []
var armed: Array = []
var declared: Array = []
var catch_target := -1
var motion: Dictionary = {}
var last_event := ""
var pending_draw := 0
var feedback: Dictionary = {}
var allow_mercy := false
var eliminated: Array = []
var retired: Array = []
var allow_stacking := false
var allow_seven_zero := false
var allow_jump_ins := false
var draw_until_play := false
var force_play := false
var jump_open := false
var swap_seat := -1
var swap_next := -1


func start(seat_count: int) -> void:
	if seat_count < 4 or seat_count > 6:
		return
	_build_cards()
	session_wins.resize(seat_count)
	session_wins.fill(0)
	dealer = randi_range(0, seat_count - 1)
	round_number = 0
	history.clear()
	_new_round()


func active_colors() -> Array:
	return DARK_COLORS if gamemode == "flip" and side == "dark" else COLORS


func set_gamemode(mode: String) -> bool:
	if mode not in GAMEMODES or mode == gamemode: return false
	gamemode = mode
	var defaults := default_options(mode)
	for option in defaults: set(option, defaults[option])
	return true


static func default_options(mode: String) -> Dictionary:
	var mercy := mode == "no_mercy"
	return {"allow_stacking": mercy, "allow_seven_zero": mercy, "allow_mercy": mercy, "allow_jump_ins": false, "draw_until_play": mercy, "force_play": false}


func _build_cards() -> void:
	cards.clear()
	flip_faces.clear()
	built_mode = gamemode
	built_addons = AddOns.signature(enabled_addons) if gamemode == "classic" else ""
	side = "light"
	if gamemode == "flip":
		var light := _flip_deck(COLORS, "draw1", "skip", "draw2")
		var dark := _flip_deck(DARK_COLORS, "draw5", "skip_all", "draw_color")
		dark.shuffle()
		# Pair once; every flip and replay keeps these physical card identities.
		for id in light.size():
			flip_faces.append({"light": light[id], "dark": dark[id]})
		_activate_faces()
		return
	if gamemode == "no_mercy":
		for suit in COLORS:
			for kind in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "draw4", "skip_all"]:
				for copy in 2: _add_card(suit, kind)
			for kind in ["skip", "reverse", "draw2", "discard_all"]:
				for copy in 3: _add_card(suit, kind)
		for kind in ["reverse_draw4", "color_roulette"]:
			for copy in 8: _add_card("wild", kind)
		for kind in ["draw6", "draw10"]:
			for copy in 4: _add_card("wild", kind)
		return
	for suit in COLORS:
		_add_card(suit, "0")
		for kind in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "skip", "reverse", "draw2"]:
			_add_card(suit, kind)
			_add_card(suit, kind)
	for kind in ["wild", "draw4"]:
		for copy in 4: _add_card("wild", kind)
	AddOns.append_cards(self)


static func _flip_deck(palette: Array, draw_kind: String, skip_kind: String, wild_kind: String) -> Array:
	var faces: Array = []
	for suit in palette:
		for kind in ["1", "2", "3", "4", "5", "6", "7", "8", "9", draw_kind, "reverse", skip_kind, "flip"]:
			for copy in 2: faces.append({"color": suit, "kind": kind})
	for kind in ["wild", wild_kind]:
		for copy in 4: faces.append({"color": "wild", "kind": kind})
	return faces


func _activate_faces() -> void:
	cards.clear()
	for id in flip_faces.size():
		var face: Dictionary = flip_faces[id][side].duplicate()
		face.id = id
		face.side = side
		cards.append(face)


func _opposite_face(id: int) -> Dictionary:
	var face: Dictionary = flip_faces[id]["dark" if side == "light" else "light"].duplicate()
	face.side = "dark" if side == "light" else "light"
	return face


func _add_card(suit: String, kind: String) -> void:
	cards.append({"id": cards.size(), "color": suit, "kind": kind})


func _new_round() -> void:
	if built_mode != gamemode or built_addons != (AddOns.signature(enabled_addons) if gamemode == "classic" else ""): _build_cards()
	addons.reset()
	side = "light"
	if gamemode == "flip": _activate_faces()
	flip_next = -1
	pending_color = ""
	round_number += 1
	plays.clear()
	retired.clear()
	eliminated.resize(session_wins.size())
	eliminated.fill(false)
	deck = range(cards.size())
	deck.shuffle()
	discard.clear()
	hands.clear()
	armed.clear()
	declared.clear()
	for seat in session_wins.size():
		hands.append([])
		armed.append(false)
		declared.append(false)
	for deal in 7:
		for seat in hands.size():
			_take(seat, 1)
	direction = 1
	turn = (dealer + 1) % hands.size()
	phase = "play"
	drawn = -1
	winner = -1
	catch_target = -1
	motion.clear()
	pending_draw = 0
	feedback.clear()
	swap_seat = -1
	swap_next = -1
	var top: int = deck.pop_back()
	while cards[top].has("addon") or (gamemode == "no_mercy" and not str(cards[top].kind).is_valid_int()) or (cards[top].color == "wild" and cards[top].kind != "wild"):
		deck.push_front(top)
		top = deck.pop_back()
	discard.append(top)
	color = str(cards[top].color)
	match cards[top].kind:
		"wild":
			color = "red"
			phase = "opening_color"
		"draw1", "draw2":
			pending_draw = int(DRAW_AMOUNTS[cards[top].kind])
		"flip": _flip(dealer, true)
		"skip": turn = next_seat(turn)
		"reverse":
			direction = -1
			turn = dealer
	last_event = "Seven cards dealt."
	if addons.active(self):
		if pending_draw > 0:
			addons.penalties = [{"target":turn,"amount":pending_draw,"source":dealer,"kind":cards[top].kind,"color":color,"follow":true}]
			addons.resume = next_seat(turn)
			phase = "addon_response"
		else: addons.prepare(self)
	jump_open = phase == "play" and str(cards[top].kind).is_valid_int()
	revision += 1


func play_again() -> bool:
	if phase != "finished":
		return false
	dealer = (dealer + 1) % hands.size()
	_new_round()
	return true


func restart_round() -> void:
	# Abandon the current hand without awarding a result; retain completed wins.
	_new_round()


func next_seat(seat: int, steps := 1) -> int:
	for step in steps:
		for search in hands.size():
			seat = posmod(seat + direction, hands.size())
			if is_active(seat): break
	return seat


func is_active(seat: int) -> bool:
	return seat >= 0 and seat < hands.size() and (eliminated.is_empty() or not eliminated[seat])


func active_count() -> int:
	return range(hands.size()).filter(func(seat: int) -> bool: return is_active(seat)).size()


func _check_survivor() -> void:
	if gamemode != "no_mercy" or not allow_mercy or winner >= 0 or active_count() != 1: return
	for seat in hands.size():
		if is_active(seat):
			_finish(seat)
			last_event = "Last player remaining."
			return


func _eliminate(seat: int) -> void:
	eliminated[seat] = true
	retired.append_array(hands[seat])
	hands[seat].clear()
	armed[seat] = false
	declared[seat] = false
	_effect("out", seat)


func playable(seat: int, card_id: int) -> bool:
	if addons.active(self): return addons.playable(self, seat, card_id)
	if not is_active(seat) or phase != "play" or winner >= 0 or card_id < 0 or card_id >= cards.size() or not hands[seat].has(card_id):
		return false
	if seat != turn:
		return can_jump_in(seat, card_id)
	if drawn >= 0 and card_id != drawn:
		return false
	var card: Dictionary = cards[card_id]
	if pending_draw > 0:
		if not allow_stacking or not DRAW_AMOUNTS.has(card.kind): return false
		return int(DRAW_AMOUNTS[card.kind]) >= int(DRAW_AMOUNTS[cards[discard.back()].kind]) if gamemode == "no_mercy" else card.kind == cards[discard.back()].kind
	if not pending_color.is_empty(): return false
	if gamemode == "flip" and card.color == "wild" and card.kind in ["draw2", "draw_color"] and hands[seat].any(func(id: int) -> bool: return cards[id].color == color): return false
	return card.color == "wild" or card.color == color or card.kind == cards[discard.back()].kind


func legal_cards(seat: int) -> Array:
	if seat < 0 or seat >= hands.size():
		return []
	return hands[seat].filter(func(id: int) -> bool: return playable(seat, id))


func can_jump_in(seat: int, card_id: int) -> bool:
	if not allow_jump_ins or not jump_open or phase != "play" or winner >= 0 or pending_draw > 0 or not pending_color.is_empty() or drawn >= 0 or seat == turn:
		return false
	if not is_active(seat) or card_id < 0 or card_id >= cards.size() or not hands[seat].has(card_id):
		return false
	var card: Dictionary = cards[card_id]
	var top: Dictionary = cards[discard.back()]
	return str(card.kind).is_valid_int() and card.kind == top.kind and card.color == top.color


func jump_cards(seat: int) -> Array:
	if seat < 0 or seat >= hands.size(): return []
	return hands[seat].filter(func(id: int) -> bool: return can_jump_in(seat, id))


func set_option(option: String, enabled: bool) -> bool:
	if option not in default_options(gamemode) or phase in ["swap", "drawn_color"] or bool(get(option)) == enabled:
		return false
	set(option, enabled)
	if option == "force_play" and enabled and phase == "play" and drawn >= 0 and cards[drawn].color == "wild" and cards[drawn].kind != "color_roulette": phase = "drawn_color"
	revision += 1
	return true


func requires_auto_draw() -> bool:
	if addons.active(self): return phase == "addon_response" and legal_cards(turn).is_empty()
	return phase == "play" and (not pending_color.is_empty() or pending_draw > 0 and legal_cards(turn).is_empty())


func requires_turn_draw() -> bool:
	return phase == "play" and pending_draw == 0 and pending_color.is_empty() and drawn < 0 and legal_cards(turn).is_empty()


func requires_forced_play() -> bool:
	# Only the current turn's freshly drawn, playable card may be automatic.
	# Dealt cards, held cards and penalty pickups never enter this decision.
	return force_play and drawn >= 0 and pending_draw == 0 and pending_color.is_empty() and playable(turn, drawn)


static func deal_duration(seat_count: int) -> float:
	return DEAL_SHUFFLE + (seat_count * 7 - 1) * DEAL_STEP + DEAL_FLIGHT + DEAL_REVEAL


static func dealt_count(seat: int, event: Dictionary, elapsed: float) -> int:
	var order := posmod(seat - int(event.dealer) - 1,int(event.seats))
	var first := DEAL_SHUFFLE + order * DEAL_STEP + DEAL_FLIGHT
	return clampi(int(floor((elapsed - first) / (int(event.seats) * DEAL_STEP))) + 1,0,7)


func _begin_action() -> void:
	jump_open = false
	catch_target = -1
	motion.clear()
	feedback.clear()


func _effect(kind: String, seat: int, amount := 0) -> void:
	if feedback.is_empty(): feedback = {"revision": revision + 1, "events": []}
	feedback.events.append({"kind": kind, "seat": seat, "amount": amount, "color": color})


func _flight(kind: String, seat: int, count := 1, face: Dictionary = {}) -> void:
	if motion.is_empty(): motion = {"revision": revision + 1, "flights": []}
	motion.flights.append({"kind": kind, "seat": seat, "count": count, "card": face.duplicate()})
	if gamemode == "flip" and kind == "draw": motion.flights.back().backs = hands[seat].slice(-count).map(func(id: int) -> Dictionary: return _opposite_face(id))


# Hand transfers share one interval so every outgoing fan moves together.
static func motion_timeline(event: Dictionary) -> Dictionary:
	if event.is_empty(): return {}
	var timeline: Dictionary = event.duplicate(true)
	var end := 0.0
	var hand_start := -1.0
	for flight in timeline.get("flights", []):
		if flight.kind == "hand":
			if hand_start < 0: hand_start = end
			flight.start = hand_start
			flight.duration = .72
		else:
			hand_start = -1.0
			flight.start = end
			flight.duration = .48 + .10 * maxi(0, int(flight.count) - 1)
		end = maxf(end, flight.start + flight.duration)
	return timeline


static func motion_duration(event: Dictionary) -> float:
	var duration := 0.0
	for flight in motion_timeline(event).get("flights", []):
		duration = maxf(duration, flight.start + flight.duration)
	return duration


static func card_art_prefix(card: Dictionary, mode := "classic") -> String:
	if mode == "no_mercy": return "no-mercy-"
	if card.has("addon"): return "addon-speed-" if card.addon == "speed" and str(card.kind).is_valid_int() else "addon-"
	return "flip-dark-" if card.get("side", "") == "dark" else ""


# Sort presentation copies only. Draw order, IDs and Flip pairs stay authoritative.
static func sorted_hand(hand: Array, palette: Array = COLORS, playable_first: Array = []) -> Array:
	var ordered := hand.duplicate()
	var actions := ["skip", "reverse", "draw1", "draw2", "draw4", "draw5", "skip_all", "discard_all", "flip", "wild", "reverse_draw4", "draw6", "draw10", "draw_color", "color_roulette"]
	actions.append_array(AddOns.LABELS.keys())
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if playable_first.has(a.id) != playable_first.has(b.id): return playable_first.has(a.id)
		var a_color := palette.find(str(a.color)) if a.color != "wild" else palette.size()
		var b_color := palette.find(str(b.color)) if b.color != "wild" else palette.size()
		if a_color != b_color: return a_color < b_color
		var a_kind := int(a.kind) if str(a.kind).is_valid_int() else 10 + actions.find(str(a.kind))
		var b_kind := int(b.kind) if str(b.kind).is_valid_int() else 10 + actions.find(str(b.kind))
		return a_kind < b_kind if a_kind != b_kind else int(a.id) < int(b.id)
	)
	return ordered


func play(seat: int, card_id: int, chosen_color := "") -> bool:
	if addons.active(self): return addons.play(self, seat, card_id, chosen_color)
	if not playable(seat, card_id):
		return false
	var card: Dictionary = cards[card_id]
	if card.color == "wild" and card.kind != "color_roulette" and chosen_color not in active_colors():
		return false
	var jumped := seat != turn
	_begin_action()
	if jumped: _effect("jump", seat)
	hands[seat].erase(card_id)
	var extras: Array = []
	if card.kind == "discard_all":
		extras = hands[seat].filter(func(id: int) -> bool: return cards[id].color == card.color)
		for id in extras:
			hands[seat].erase(id)
			discard.append(id)
	discard.append(card_id)
	color = (color if card.kind == "color_roulette" else chosen_color) if card.color == "wild" else str(card.color)
	var shown := card.duplicate()
	if card.color == "wild" and card.kind != "color_roulette": shown.selected_color = color
	for id in extras: _flight("play", seat, 1, cards[id])
	_flight("play", seat, 1, shown)
	plays.append({"number": plays.size() + 1, "seat": seat, "card": card.duplicate(), "color": color})
	drawn = -1
	var missed_uno: bool = hands[seat].size() == 1 and not armed[seat]
	declared[seat] = hands[seat].size() == 1 and armed[seat]
	if missed_uno:
		var penalty := _take(seat, 2)
		if not penalty.is_empty(): _flight("draw", seat, penalty.size())
		_effect("draw", seat, 2)
	armed[seat] = false
	last_event = "Played %s." % card_label(card)
	# No Mercy ends immediately when the last card is played, before 7/0 transfers.
	if gamemode == "no_mercy" and hands[seat].is_empty():
		_finish(seat)
		revision += 1
		return true
	match card.kind:
		"reverse":
			direction *= -1
			turn = seat if gamemode == "no_mercy" and active_count() == 2 else next_seat(seat)
			_effect("reverse", seat)
		"skip":
			_effect("skip", next_seat(seat))
			turn = next_seat(seat, 2)
		"skip_all":
			for target in hands.size():
				if target != seat and is_active(target): _effect("skip", target)
			turn = seat
		"flip": _flip(seat)
		"draw_color":
			pending_color = chosen_color
			turn = next_seat(seat)
			_effect("wild", seat)
			last_event = "Draw until %s and skip the turn." % chosen_color.capitalize()
		"color_roulette":
			turn = next_seat(seat)
			phase = "roulette_color"
			_effect("wild", seat)
			last_event = "Choose a color for Color Roulette."
		"reverse_draw4":
			direction *= -1
			turn = seat if active_count() == 2 else next_seat(seat)
			pending_draw += 4
			_effect("reverse", seat)
			_effect("stack", turn, pending_draw)
			last_event = "Reverse and draw %d cards." % pending_draw
		"draw1", "draw2", "draw4", "draw5", "draw6", "draw10":
			pending_draw += int(DRAW_AMOUNTS[card.kind])
			turn = next_seat(seat)
			_effect("stack", turn, pending_draw)
			last_event = "Draw %d: stack another +%d, or take the cards." % [pending_draw, int(DRAW_AMOUNTS[card.kind])] if allow_stacking else "Draw %d cards." % pending_draw
		"wild":
			turn = next_seat(seat)
			_effect("wild", seat)
		_:
			turn = next_seat(seat)
			if allow_seven_zero and card.kind == "7":
				phase = "swap"
				swap_seat = seat
				swap_next = turn
				turn = seat
				catch_target = -1
				_effect("seven", seat)
				last_event = "Choose a player to swap hands with."
			elif allow_seven_zero and card.kind == "0":
				_pass_hands()
			else:
				jump_open = str(card.kind).is_valid_int()
	if phase != "swap" and hands[seat].is_empty():
		# An empty hand ends the round; its final stack is paid before celebration.
		if pending_draw > 0 or not pending_color.is_empty(): _take_penalty(turn)
		_finish(seat)
	if missed_uno and winner < 0: last_event = "Missed UNO: two-card penalty."
	revision += 1
	return true


func _flip(seat: int, opening := false) -> void:
	side = "dark" if side == "light" else "light"
	_activate_faces()
	deck.reverse()
	discard.reverse()
	color = str(cards[discard.back()].color)
	turn = next_seat(seat)
	# Revealing a new action face does not play that action a second time.
	if color == "wild":
		flip_next = turn
		turn = seat
		phase = "flip_color"
		color = str(active_colors()[0])
	jump_open = phase == "play" and str(cards[discard.back()].kind).is_valid_int()
	if not opening:
		_flight("flip", seat)
		_effect("flip", seat)
		last_event = "%s Side." % side.capitalize()


func _handoff(source: int, target: int, hand: Array) -> void:
	var amount := hand.size()
	if amount == 0: return
	_flight("hand", source)
	motion.flights.back().target = target
	motion.flights.back().hand_count = amount
	if gamemode == "flip":
		motion.flights.back().backs = hand.map(func(id: int) -> Dictionary: return _opposite_face(id))


func swap_hands(seat: int, target: int) -> bool:
	if phase != "swap" or seat != swap_seat or target < 0 or target >= hands.size() or target == seat or not is_active(target):
		return false
	_begin_action()
	var own: Array = hands[seat]
	hands[seat] = hands[target]
	hands[target] = own
	declared[seat] = false
	declared[target] = false
	_handoff(seat, target, hands[target])
	_handoff(target, seat, hands[seat])
	armed.fill(false)
	phase = "play"
	turn = swap_next
	swap_seat = -1
	swap_next = -1
	_effect("swap", seat)
	_effect("swap", target)
	last_event = "Hands swapped."
	jump_open = true
	_finish_empty_hand()
	revision += 1
	return true


func _pass_hands() -> void:
	declared.fill(false)
	var previous := hands.duplicate(true)
	for source in hands.size():
		if not is_active(source): continue
		var target := next_seat(source)
		hands[target] = previous[source]
		_handoff(source, target, previous[source])
		_effect("pass", target)
	armed.fill(false)
	catch_target = -1
	last_event = "All hands passed in the current direction."
	jump_open = true
	_finish_empty_hand()


func _finish_empty_hand() -> void:
	for seat in hands.size():
		if is_active(seat) and hands[seat].is_empty():
			_finish(seat)
			return


func choose_color(seat: int, chosen_color: String) -> bool:
	if phase not in ["opening_color", "drawn_color", "flip_color", "roulette_color"] or seat != turn or chosen_color not in active_colors():
		return false
	if phase == "drawn_color":
		phase = "play"
		return play(seat, drawn, chosen_color)
	color = chosen_color
	if phase == "roulette_color": pending_color = chosen_color
	if phase == "flip_color":
		turn = flip_next
		flip_next = -1
	phase = "play"
	last_event = "%s starts the hand." % color.capitalize()
	revision += 1
	return true


func draw(seat: int) -> bool:
	if addons.active(self): return addons.draw(self, seat)
	if phase != "play" or seat != turn or drawn >= 0 or not is_active(seat):
		return false
	var keep_drawing := draw_until_play and legal_cards(seat).is_empty()
	_begin_action()
	armed[seat] = false
	if pending_draw > 0 or not pending_color.is_empty():
		_take_penalty(seat)
		turn = next_seat(seat)
		_check_survivor()
		revision += 1
		return true
	var taken := _take(seat, 1)
	if not taken.is_empty(): _flight("draw", seat, taken.size())
	if not is_active(seat):
		drawn = -1
		turn = next_seat(seat)
		last_event = "25 cards: eliminated."
		_check_survivor()
	elif taken.is_empty():
		turn = next_seat(seat)
		last_event = "Draw pile empty; turn passed."
	else:
		drawn = int(taken[0])
		last_event = "One card drawn."
		if not playable(seat, drawn):
			drawn = -1
			if not keep_drawing: turn = next_seat(seat)
		elif force_play and cards[drawn].color == "wild" and cards[drawn].kind != "color_roulette":
			phase = "drawn_color"
			last_event = "Choose the drawn Wild's color."
	revision += 1
	return true


func _take_penalty(seat: int) -> void:
	var amount := pending_draw
	var taken: Array = []
	if not pending_color.is_empty():
		# A finite stock can run out without that color; keep all drawn cards.
		while true:
			var next := _take(seat, 1)
			if next.is_empty(): break
			taken.append(next[0])
			if not is_active(seat) or cards[next[0]].color == pending_color: break
		amount = taken.size()
	else:
		taken = _take(seat, amount)
	pending_color = ""
	if not taken.is_empty(): _flight("draw", seat, taken.size())
	_effect("draw", seat, amount)
	pending_draw = 0
	drawn = -1
	last_event = "25 cards: eliminated." if not is_active(seat) else "Drew %d cards and skipped the turn." % taken.size()


func pass_turn(seat: int) -> bool:
	if addons.active(self): return addons.pass_turn(self, seat)
	if phase != "play" or seat != turn or drawn < 0 or force_play or not is_active(seat):
		return false
	_begin_action()
	drawn = -1
	armed[seat] = false
	turn = next_seat(seat)
	last_event = "Drawn card kept."
	revision += 1
	return true


func can_call_uno(seat: int) -> bool:
	if addons.active(self):
		if not is_active(seat) or armed[seat] or winner >= 0: return false
		if seat != turn: return phase == "play" and hands[seat].size() == 2 and not jump_cards(seat).is_empty()
		return (phase in ["play", "drawn_color", "addon_response", "addon_assist"] and hands[seat].size() == 2) or addons.can_combo(self, seat) or (phase == "addon_choice" and addons.choice.get("kind") in ["double", "combo_keep", "combo_color"] and (hands[seat].size() == 2 or addons.choice.kind.begins_with("combo")))
	if not is_active(seat) or phase not in ["play", "drawn_color"] or armed[seat]: return false
	if turn != seat and jump_cards(seat).is_empty(): return false
	if hands[seat].size() == 2: return true
	# Discard All can reduce a larger hand directly to one card.
	return gamemode == "no_mercy" and hands[seat].any(func(id: int) -> bool:
		return cards[id].kind == "discard_all" and hands[seat].filter(func(other: int) -> bool: return cards[other].color != cards[id].color).size() == 1 and playable(seat,id)
	)


func call_uno(seat: int) -> bool:
	if not is_active(seat) or phase == "finished":
		return false
	if can_call_uno(seat):
		armed[seat] = true
	else:
		return false
	last_event = "UNO!"
	feedback.clear()
	_effect("uno", seat)
	revision += 1
	return true


func catch_uno(seat: int, target: int) -> bool:
	if not is_active(seat) or target != catch_target or target < 0 or seat == target or phase == "finished":
		return false
	motion.clear()
	var taken := _take(target, 2)
	if not taken.is_empty(): _flight("draw", target, taken.size())
	armed[target] = false
	catch_target = -1
	last_event = "Missed UNO caught: two-card penalty."
	revision += 1
	return true


func _take(seat: int, amount: int) -> Array:
	var taken: Array = []
	if not is_active(seat): return taken
	for index in amount:
		if deck.is_empty() and (discard.size() > 1 or not retired.is_empty()):
			var top: int = discard.pop_back()
			deck = discard.duplicate() + retired
			retired.clear()
			deck.shuffle()
			discard = [top]
		if deck.is_empty(): break
		var card: int = deck.pop_back()
		hands[seat].append(card)
		declared[seat] = false
		taken.append(card)
		if gamemode == "no_mercy" and allow_mercy and hands[seat].size() >= 25:
			_eliminate(seat)
			break
	return taken


func _finish(seat: int) -> void:
	if winner >= 0: return
	winner = seat
	phase = "finished"
	declared.fill(false)
	catch_target = -1
	jump_open = false
	session_wins[seat] += 1
	history.append({"round": round_number, "winner": seat})
	last_event = "UNO! All cards played."


static func card_label(card: Dictionary) -> String:
	var name := str(card.kind)
	if AddOns.LABELS.has(name): return (str(card.color).capitalize() + " " if card.color != "wild" else "") + AddOns.LABELS[name]
	if card.get("addon", "") == "speed": return "%s Speed Up %s" % [str(card.color).capitalize(), name]
	match name:
		"draw1": name = "Draw One"
		"draw2":
			if card.color == "wild": return "Wild Draw Two"
			name = "Draw Two"
		"draw5": name = "Draw Five"
		"draw_color": return "Wild Draw Color"
		"skip_all": name = "Skip Everyone"
		"flip": name = "Flip"
		"draw4":
			if card.color == "wild": return "Wild Draw Four"
			name = "Draw Four"
		"draw6": return "Wild Draw Six"
		"draw10": return "Wild Draw Ten"
		"reverse_draw4": return "Wild Reverse Draw Four"
		"color_roulette": return "Wild Color Roulette"
		"discard_all": name = "Discard All"
		"wild": return "Wild"
		"skip", "reverse": name = name.capitalize()
	return "%s %s" % [str(card.color).capitalize(), name]


func view_for(seat: int) -> Dictionary:
	var own: Array = []
	if seat >= 0 and seat < hands.size():
		for id in hands[seat]:
			var face: Dictionary = cards[id].duplicate()
			if gamemode == "flip": face.opposite = _opposite_face(id)
			own.append(face)
	var top: Dictionary = cards[discard.back()].duplicate()
	if top.color == "wild" and phase not in ["opening_color", "flip_color", "roulette_color"]: top.selected_color = color
	var targets: Array = range(hands.size()).filter(func(target: int) -> bool: return target != seat and is_active(target)) if phase == "swap" and seat == swap_seat else []
	var options := {"allow_mercy":allow_mercy, "allow_stacking":allow_stacking, "allow_seven_zero":allow_seven_zero, "allow_jump_ins":allow_jump_ins, "draw_until_play":draw_until_play, "force_play":force_play}
	var backs: Array = []
	if gamemode == "flip":
		for hand in hands:
			backs.append(hand.map(func(id: int) -> Dictionary: return _opposite_face(id)))
	var uno_players: Array = range(hands.size()).map(func(index: int) -> bool: return declared[index] and hands[index].size() == 1 and winner < 0)
	var view := {"eliminated": eliminated.duplicate(), "gamemode": gamemode, "side": side, "colors": active_colors().duplicate(), "backs": backs, "deck_back": _opposite_face(deck.back()) if gamemode == "flip" and not deck.is_empty() else {"color":"wild", "kind":"back"}, "pending_color": pending_color, "viewer": seat, "hand": own, "counts": hands.map(func(hand: Array) -> int: return hand.size()), "top": top, "color": color, "direction": direction, "turn": turn, "phase": phase, "winner": winner, "revision": revision, "round_id": str(round_number), "round": round_number, "session_wins": session_wins.duplicate(), "history": history.duplicate(true), "catch_target": catch_target, "can_uno": can_call_uno(seat), "uno_armed": bool(armed[seat]) if seat >= 0 and seat < armed.size() else false, "uno_players": uno_players, "drawn": drawn if seat == turn else -1, "legal_cards": legal_cards(seat), "last_event": last_event, "deck_count": deck.size(), "motion": motion_timeline(motion), "pending_draw": pending_draw, "feedback": feedback.duplicate(true), "options":options, "jump_cards": jump_cards(seat), "swap_seat": swap_seat, "swap_targets": targets, "auto_draw":requires_turn_draw(), "forced_play":requires_forced_play()}
	if addons.active(self): view.merge(addons.view(self, seat))
	return view


# The AI accepts only its own private view, never other hands or deck order.
static func computer_action(view: Dictionary, difficulty: int) -> Dictionary:
	var addon_action := AddOns.computer_action(view)
	if not addon_action.is_empty(): return addon_action
	if view.phase == "swap":
		var targets: Array = view.swap_targets
		var target: int = targets.pick_random()
		if difficulty != Difficulty.EASY:
			for candidate in targets:
				if view.counts[candidate] < view.counts[target]: target = candidate
		return {"action": "swap", "target": target}
	var palette: Array = view.get("colors", COLORS)
	if view.phase in ["opening_color", "drawn_color", "flip_color", "roulette_color"]:
		return {"action": "color", "color": _best_color(view.hand, palette)}
	var legal: Array = view.hand.filter(func(card: Dictionary) -> bool: return view.legal_cards.has(card.id))
	if legal.is_empty():
		return {"action": "pass" if view.drawn >= 0 else "draw"}
	var selected: Dictionary = legal.pick_random()
	if difficulty != Difficulty.EASY:
		var best := -INF
		var preferred := _best_color(view.hand, palette)
		var target := int(view.viewer)
		for step in view.counts.size():
			target = posmod(target + int(view.direction), view.counts.size())
			if not view.get("eliminated", []).size() or not view.eliminated[target]: break
		for card in legal:
			var score := float(int(card.kind)) if str(card.kind).is_valid_int() else 18.0
			if card.color == preferred: score += 5.0
			if card.color == "wild": score -= 12.0
			if difficulty == Difficulty.HARD and view.counts[target] <= 2 and card.kind in ["skip", "skip_all", "draw1", "draw2", "draw4", "draw5", "draw_color", "draw6", "draw10", "reverse_draw4", "color_roulette"]: score += 24.0
			if card.kind == "discard_all":
				score += view.hand.filter(func(held: Dictionary) -> bool: return held.color == card.color).size() * 9.0
			if card.kind == "flip" and difficulty == Difficulty.HARD:
				var opposite: Array = view.hand.filter(func(held: Dictionary) -> bool: return held.id != card.id).map(func(held: Dictionary) -> Dictionary: return held.opposite)
				var other_palette: Array = COLORS if view.side == "dark" else DARK_COLORS
				var other_color := _best_color(opposite, other_palette)
				score += opposite.filter(func(held: Dictionary) -> bool: return held.color == other_color).size() * 2.0
			score += randf()
			if score > best:
				best = score
				selected = card
	return {"action": "play", "card": selected.id, "color": _best_color(view.hand.filter(func(card: Dictionary) -> bool: return card.id != selected.id), palette)}


static func _best_color(hand: Array, palette: Array = COLORS) -> String:
	var best := 0
	var chosen: String = palette.pick_random()
	for suit in palette:
		var count := hand.filter(func(card: Dictionary) -> bool: return card.color == suit).size()
		if count > best:
			best = count
			chosen = suit
	return chosen
