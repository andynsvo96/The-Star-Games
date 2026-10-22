extends RefCounted

# Classic-only packs. Placeholders/reference cards are UI state, never deck cards.
const PACKS := [["reverse", "Reverse"], ["stack", "Stack"], ["swap", "Swap"], ["speed", "Speed"], ["billie_eilish", "Billie Eilish"], ["frenemies", "Frenemies"], ["defense", "Defense"], ["comeback", "Comeback"], ["love_island", "Love Island"]]
const COLORED := {"reverse": ["reverse_draw2", "reverse_skip"], "stack": ["stack1", "stack2"], "swap": ["swap1", "refresh_hand"], "billie_eilish": ["reveal_hands"], "love_island": ["text"]}
const WILDS := {"reverse": ["power_reverse", "no_u"], "stack": ["stack3", "stack_number"], "swap": ["force_trade", "pass_hands"], "speed": ["double_speed"], "billie_eilish": ["pass_color", "trick", "color_challenge"], "frenemies": ["nemesis", "petty", "eliminator", "instigator"], "defense": ["block", "rebound", "deflect", "redirect"], "comeback": ["swap_hands", "double_down", "match_max", "misery"], "love_island": ["coupled", "chat", "eggs"]}
const LABELS := {"reverse_draw2":"Reverse Draw 2", "reverse_skip":"Reverse Skip", "power_reverse":"Wild Power Reverse", "no_u":"Wild No U", "stack1":"Stack 1", "stack2":"Stack 2", "stack3":"Wild Stack 3", "stack_number":"Wild Stack Number", "swap1":"Swap 1", "refresh_hand":"Refresh Hand", "force_trade":"Wild Force Trade", "pass_hands":"Wild Pass Hands", "double_speed":"Wild Double Speed Up", "pass_color":"Wild Pass Color", "trick":"Trick Wild Card", "color_challenge":"Wild Color Challenge", "reveal_hands":"Reveal Hands", "nemesis":"Wild Nemesis", "petty":"Wild Petty Play", "eliminator":"Wild Eliminator", "instigator":"Wild Instigator", "block":"Wild Block", "rebound":"Wild Block & Rebound", "deflect":"Wild Block & Deflect", "redirect":"Wild Redirect", "swap_hands":"Wild Swap Hands", "double_down":"Wild Double Down", "match_max":"Wild Match the Max", "misery":"Wild Misery Loves Company", "coupled":"Wild Coupled Up", "chat":"Wild Pull You for a Chat", "eggs":"Wild Eggs in One Basket", "text":"I've Got a Text"}

var speed := 1
var remaining := 1
var choice: Dictionary = {}
var context: Dictionary = {}
var penalties: Array = []
var resume := -1
var finish_candidate := -1
var enemies: Dictionary = {}
var couple := [-1, -1]
var basket := [-1, -1]
var basket_was_uno := false
var reveal_owner := -1
var private_reveals: Dictionary = {}
var assist_declined := false


static func defaults() -> Dictionary:
	var result := {}
	for pack in PACKS: result[pack[0]] = false
	return result


static func signature(enabled: Dictionary) -> String:
	return ",".join(PACKS.filter(func(pack: Array) -> bool: return bool(enabled.get(pack[0], false))).map(func(pack: Array) -> String: return pack[0]))


static func append_cards(rules) -> void:
	for pack in PACKS:
		var key: String = pack[0]
		if not rules.enabled_addons.get(key, false): continue
		for kind in COLORED.get(key, []):
			for suit in rules.COLORS:
				var count := 2 if key == "love_island" else 1
				for copy in count: _card(rules, key, suit, kind)
		if key == "speed":
			for index in 4:
				for number in range(1 + index * 2, 4 + index * 2):
					_card(rules, key, ["yellow", "red", "blue", "green"][index], str(number))
		for kind in WILDS.get(key, []):
			var count := (1 if kind == "eggs" else 2) if key == "love_island" else 4
			for copy in count: _card(rules, key, "wild", kind)


static func _card(rules, pack: String, suit: String, kind: String) -> void:
	rules._add_card(suit, kind)
	var card: Dictionary = rules.cards.back()
	card.addon = pack
	if pack == "speed": card.speed = 2 if kind == "double_speed" else 1
	if kind in ["swap_hands", "double_down", "match_max"]: card.letter = {"swap_hands":"U", "double_down":"N", "match_max":"O"}[kind]


func reset() -> void:
	speed = 1
	remaining = 1
	choice.clear()
	context.clear()
	penalties.clear()
	resume = -1
	finish_candidate = -1
	enemies.clear()
	couple = [-1, -1]
	basket = [-1, -1]
	basket_was_uno = false
	reveal_owner = -1
	private_reveals.clear()
	assist_declined = false


func active(rules) -> bool:
	return rules.gamemode == "classic" and not signature(rules.enabled_addons).is_empty()


func matches(rules, card: Dictionary) -> bool:
	var top: Dictionary = rules.cards[rules.discard.back()]
	if card.color == "wild" or card.color == rules.color or card.kind == top.kind: return true
	var symbols := {"reverse_draw2":["reverse", "draw2"], "reverse_skip":["reverse", "skip"]}
	var own: Array = symbols.get(card.kind, [card.kind])
	var other: Array = symbols.get(top.kind, [top.kind])
	return own.any(func(symbol: String) -> bool: return other.has(symbol))


func responses(rules, seat: int) -> Array:
	if penalties.is_empty(): return []
	var penalty: Dictionary = penalties[0]
	return rules.hands[seat].filter(func(id: int) -> bool:
		var card: Dictionary = rules.cards[id]
		if card.kind in ["block", "deflect"]: return true
		if penalty.get("skip_only", false): return false
		if card.kind in ["no_u", "rebound", "redirect"]: return true
		if card.kind == "petty": return not penalty.get("petty_used", false) and penalty.source != seat
		if card.kind in ["stack3", "stack_number"]: return not penalty.has("until")
		if card.kind in ["stack1", "stack2"]: return not penalty.has("until") and (card.color == penalty.color or str(penalty.kind).begins_with("stack"))
		return rules.allow_stacking and not penalty.has("until") and card.kind in ["draw2", "draw4"] and card.kind == penalty.kind
	)


func playable(rules, seat: int, id: int) -> bool:
	if not rules.is_active(seat) or rules.winner >= 0 or id < 0 or id >= rules.cards.size() or not rules.hands[seat].has(id): return false
	if rules.phase == "addon_response": return seat == rules.turn and responses(rules, seat).has(id)
	if rules.phase == "addon_choice": return false
	if rules.phase not in ["play", "addon_assist"]: return false
	if seat != rules.turn: return rules.can_jump_in(seat, id) if rules.phase == "play" else false
	if rules.drawn >= 0 and id != rules.drawn: return false
	return matches(rules, rules.cards[id])


func start_turn(rules, seat: int) -> void:
	rules.turn = seat
	rules.phase = "play"
	rules.drawn = -1
	remaining = speed
	assist_declined = false
	if seat == reveal_owner: reveal_owner = -1
	private_reveals.erase(seat)
	prepare(rules)


func prepare(rules) -> void:
	if rules.phase != "play" or rules.pending_draw > 0 or rules.drawn >= 0 or rules.winner >= 0 or assist_declined: return
	if couple[1] != rules.turn or couple[0] < 0 or not rules.legal_cards(rules.turn).is_empty(): return
	var helper: int = couple[0]
	if not rules.hands[helper].any(func(id: int) -> bool: return matches(rules, rules.cards[id])): return
	context = {"actor":helper, "origin":rules.turn, "after":rules.next_seat(rules.turn), "assisting":true}
	rules.turn = helper
	rules.phase = "addon_assist"
	rules.last_event = "Coupled partner may play a card or let their partner draw."


func _log(rules, seat: int, card: Dictionary) -> void:
	var shown := card.duplicate()
	if card.color == "wild": shown.selected_color = rules.color
	rules._flight("play", seat, 1, shown)
	rules.plays.append({"number":rules.plays.size() + 1, "seat":seat, "card":card.duplicate(), "color":rules.color})
	rules.last_event = "Played %s." % rules.card_label(card)


func _uno(rules, seat: int) -> void:
	rules.declared[seat] = rules.hands[seat].size() == 1 and rules.armed[seat]
	if rules.hands[seat].size() == 1 and not rules.armed[seat]:
		var taken: Array = rules._take(seat, 2)
		if not taken.is_empty(): rules._flight("draw", seat, taken.size())
		rules._effect("draw", seat, taken.size())
		rules.last_event = "Missed UNO: two-card penalty."
	rules.armed[seat] = false
	_basket_uno(rules)


func _basket_uno(rules) -> void:
	if basket[1] < 0: return
	var at_uno: bool = rules.hands[basket[1]].size() == 1
	if at_uno and not basket_was_uno and basket[0] >= 0:
		var follower: int = basket[0]
		while rules.hands[follower].size() > 1: rules.discard.push_front(rules.hands[follower].pop_front())
		rules.declared[follower] = true
		rules.armed[follower] = false
	basket_was_uno = at_uno


func play(rules, seat: int, id: int, selected_color: String) -> bool:
	if not playable(rules, seat, id): return false
	var card: Dictionary = rules.cards[id]
	if card.color == "wild" and selected_color not in rules.COLORS: return false
	var responding: bool = rules.phase == "addon_response"
	var assisting: bool = rules.phase == "addon_assist"
	var origin: int = int(context.origin) if assisting else seat
	var jumped: bool = seat != rules.turn
	if jumped: remaining = speed
	rules._begin_action()
	if jumped: rules._effect("jump", seat)
	rules.hands[seat].erase(id)
	rules.discard.append(id)
	rules.color = selected_color if card.color == "wild" else str(card.color)
	rules.drawn = -1
	_log(rules, seat, card)
	if responding:
		_uno(rules, seat)
		_response(rules, seat, card)
	else:
		remaining = maxi(0, remaining - 1)
		speed += int(card.get("speed", 0))
		context = {"actor":seat, "origin":origin, "after":origin if remaining > 0 else rules.next_seat(origin), "continuing":remaining > 0, "color":rules.color, "uno_pending":true}
		# Speed icons always apply; other actions apply only to the final card.
		if remaining == 0 or rules.hands[seat].is_empty(): _effect(rules, card)
		if choice.is_empty():
			_uno(rules, seat)
			context.uno_pending = false
		_resolve(rules)
	rules.revision += 1
	return true


func _job(rules, target: int, amount: int, source: int, kind: String, skip := false, follow := false) -> void:
	if amount <= 0 and not skip: return
	penalties.append({"target":target, "amount":amount, "source":source, "kind":kind, "color":rules.color, "skip_only":skip, "follow":follow})
	if amount > 0: rules._effect("stack", target, amount)


func _ask(rules, kind: String, prompt: String, targets: Array = []) -> void:
	choice = {"kind":kind, "prompt":prompt, "owner":int(context.actor), "targets":targets}
	rules.phase = "addon_choice"
	rules.turn = int(context.actor)
	rules.last_event = prompt


func _others(rules, owner: int, include_self := false) -> Array:
	return range(rules.hands.size()).filter(func(seat: int) -> bool: return include_self or seat != owner)


func _effect(rules, card: Dictionary) -> void:
	var actor: int = context.actor
	var origin: int = context.origin
	var next: int = rules.next_seat(origin)
	match card.kind:
		"reverse", "reverse_draw2", "reverse_skip", "power_reverse":
			rules.direction *= -1
			next = rules.next_seat(origin)
			context.after = actor if card.kind == "power_reverse" else next
			rules._effect("reverse", actor)
			if card.kind == "reverse_draw2":
				_job(rules, next, 2, actor, "draw2", false, true)
				context.after = rules.next_seat(next)
			elif card.kind == "reverse_skip":
				_job(rules, next, 0, actor, "skip", true, true)
				context.after = rules.next_seat(next)
		"skip":
			_job(rules, next, 0, actor, "skip", true, true)
			context.after = rules.next_seat(next)
		"draw2", "draw4", "stack1", "stack2", "stack3", "stack_number":
			_job(rules, next, _draw_value(rules, card.kind), actor, card.kind, false, true)
			context.after = rules.next_seat(next)
		"no_u":
			rules.direction *= -1
			context.after = rules.next_seat(origin)
			rules._effect("reverse", actor)
		"swap1", "swap_hands", "nemesis", "match_max", "coupled", "chat", "eggs":
			_ask(rules, card.kind, "Choose a player for %s." % LABELS[card.kind], _others(rules, actor))
		"force_trade": _ask(rules, "trade_first", "Choose the first player to trade hands.", _others(rules, actor, true))
		"refresh_hand":
			var amount: int = rules.hands[actor].size()
			for id in rules.hands[actor]: rules.discard.push_front(id)
			rules.hands[actor] = []
			_draw_cards(rules, actor, amount)
		"pass_hands": rules._pass_hands()
		"pass_color":
			var previous: Array = rules.hands.duplicate(true)
			for source in previous.size():
				var passed: Array = previous[source].filter(func(id: int) -> bool: return rules.cards[id].color == rules.color)
				var target := (source + 1) % previous.size() # Physical left, independent of direction.
				for id in passed: rules.hands[source].erase(id)
				rules.hands[target].append_array(passed)
				rules._handoff(source, target, passed)
			rules.declared.fill(false)
		"trick":
			if not rules.hands[next].any(func(id: int) -> bool: return rules.cards[id].color == rules.color): context.after = actor
		"color_challenge":
			var revealed := {}
			for target in _others(rules, actor):
				var matching: Array = rules.hands[target].filter(func(id: int) -> bool: return rules.cards[id].color == rules.color)
				if matching.is_empty(): _job(rules, target, 2, actor, card.kind)
				else: revealed[target] = [rules.cards[matching[0]].duplicate()]
			private_reveals[actor] = revealed
			if revealed.size() == rules.hands.size() - 1: _job(rules, actor, 3, actor, card.kind)
		"reveal_hands": reveal_owner = actor
		"petty": _ask(rules, "petty", "Choose a player to draw three cards.", _others(rules, actor))
		"eliminator":
			for target in _others(rules, actor):
				var wilds: Array = rules.hands[target].filter(func(id: int) -> bool: return rules.cards[id].color == "wild")
				for id in wilds:
					rules.hands[target].erase(id)
					rules.discard.push_front(id)
				rules.declared[target] = rules.hands[target].size() == 1
		"instigator":
			_ask(rules, "instigator", "Choose players and 1–4 cards each, then confirm.", _others(rules, actor, true))
			choice.amounts = {}
		"double_down":
			if not rules.hands[actor].is_empty(): _ask(rules, "double", "Choose an extra card to discard.")
		"misery":
			var largest := _largest(rules)
			for target in _others(rules, actor): _job(rules, target, largest - rules.hands[target].size(), actor, card.kind)
		"text": _ask(rules, "text", "I've Got a Text — choose a rule.")
		_:
			if rules.allow_seven_zero and card.kind == "7": _ask(rules, "swap_hands", "Choose a player to swap hands with.", _others(rules, actor))
			elif rules.allow_seven_zero and card.kind == "0": rules._pass_hands()


func _draw_value(rules, kind: String) -> int:
	if kind == "stack_number":
		var stock: Array = rules.deck.duplicate()
		if stock.is_empty() and rules.discard.size() > 1:
			var top: int = rules.discard.pop_back()
			rules.deck = rules.discard.duplicate()
			rules.deck.shuffle()
			rules.discard = [top]
			stock = rules.deck.duplicate()
		while not stock.is_empty():
			var id: int = stock.pop_back()
			rules.deck.erase(id)
			rules.discard.push_front(id)
			if str(rules.cards[id].kind).is_valid_int(): return int(rules.cards[id].kind)
		return 0
	return {"draw2":2, "draw4":4, "stack1":1, "stack2":2, "stack3":3}.get(kind, 0)


func _largest(rules) -> int:
	var largest := 0
	for hand in rules.hands: largest = maxi(largest, hand.size())
	return largest


func _exchange(rules, first: int, second: int) -> void:
	var own: Array = rules.hands[first]
	rules.hands[first] = rules.hands[second]
	rules.hands[second] = own
	rules._handoff(first, second, rules.hands[second])
	rules._handoff(second, first, rules.hands[first])
	rules.declared[first] = false
	rules.declared[second] = false
	rules.armed[first] = false
	rules.armed[second] = false


func choose(rules, seat: int, input: Dictionary) -> bool:
	if rules.phase != "addon_choice" or choice.is_empty() or seat != choice.owner: return false
	var kind: String = choice.kind
	var target := int(input.get("target", -1))
	var id := int(input.get("card", -1))
	var value := str(input.get("value", ""))
	if not choice.get("targets", []).is_empty() and not choice.targets.has(target) and not (kind == "instigator" and value == "done"): return false
	var actor: int = context.actor
	# Validate the complete choice before clearing presentation or mutating state.
	if kind in ["give", "double"] and not rules.hands[actor].has(id): return false
	if kind == "chat_take" and value != "skip" and not rules.hands[choice.target].has(id): return false
	if kind == "text" and value not in ["draw", "swap", "color"]: return false
	if kind == "combo_color" and value not in rules.COLORS: return false
	if kind == "combo_keep" and not _combo_keeps(rules, actor).has(id): return false
	if kind == "instigator" and value != "done" and (int(input.get("amount", -1)) < 0 or int(input.get("amount", -1)) > 4): return false
	rules._begin_action()
	match kind:
		"swap1", "chat":
			if rules.hands[target].is_empty() or rules.hands[actor].is_empty():
				choice.clear()
			else:
				var pick: int = rules.hands[target].pick_random()
				_ask(rules, "give" if kind == "swap1" else "chat_take", "Choose a card to give." if kind == "swap1" else "View this hand. Choose a card to exchange, or skip.")
				choice.target = target
				choice.take = pick
		"give":
			if not rules.hands[actor].has(id): return false
			var other: int = choice.target
			var received: int = choice.take
			if not rules.hands[other].has(received): return false
			rules._begin_action()
			rules.hands[actor].erase(id)
			rules.hands[other].erase(received)
			rules.hands[actor].append(received)
			rules.hands[other].append(id)
			rules._handoff(actor, other, [id])
			rules._handoff(other, actor, [received])
			choice.clear()
		"chat_take":
			if value == "skip": choice.clear()
			else:
				if not rules.hands[choice.target].has(id): return false
				choice.kind = "give"
				choice.take = id
				choice.prompt = "Choose your replacement card."
		"swap_hands":
			rules._begin_action()
			_exchange(rules, actor, target)
			choice.clear()
		"trade_first":
			_ask(rules, "trade_second", "Choose the second player to trade hands.", _others(rules, target))
			choice.first = target
		"trade_second":
			rules._begin_action()
			_exchange(rules, choice.first, target)
			choice.clear()
		"nemesis":
			enemies[actor] = target
			choice.clear()
		"petty", "match_max":
			_job(rules, target, 3 if kind == "petty" else _largest(rules) - rules.hands[target].size(), actor, kind)
			choice.clear()
		"coupled":
			couple = [actor, target]
			choice.clear()
		"eggs":
			basket = [actor, target]
			basket_was_uno = rules.hands[target].size() == 1
			choice.clear()
		"instigator":
			if value == "done":
				for recipient in choice.amounts: _job(rules, int(recipient), int(choice.amounts[recipient]), actor, "instigator")
				choice.clear()
			else:
				var amount := int(input.get("amount", -1))
				if amount < 0 or amount > 4: return false
				choice.amounts[target] = amount
		"redirect":
			penalties[0].target = target
			choice.clear()
		"double":
			if not rules.hands[actor].has(id): return false
			rules._begin_action()
			var extra: Dictionary = rules.cards[id]
			rules.hands[actor].erase(id)
			rules.discard.append(id)
			_log(rules, actor, extra)
			choice.clear()
			speed += int(extra.get("speed", 0))
			_effect(rules, extra)
		"text":
			if value not in ["draw", "swap", "color"]: return false
			choice.clear()
			if value == "swap": _ask(rules, "swap_hands", "Choose a player to swap hands with.", _others(rules, actor))
			else:
				for recipient in _others(rules, actor):
					if value == "draw": _job(rules, recipient, 1, actor, "text")
					elif not rules.hands[recipient].any(func(card_id: int) -> bool: return rules.cards[card_id].color == rules.color):
						penalties.append({"target":recipient, "amount":0, "source":actor, "kind":"text", "color":rules.color, "until":rules.color})
		"combo_keep":
			if not _combo_keeps(rules, actor).has(id): return false
			choice.keep = id
			choice.kind = "combo_color"
			choice.prompt = "Choose the color after U-N-O."
		"combo_color":
			if value not in rules.COLORS: return false
			rules._begin_action()
			var keep: int = choice.keep
			var letters: Array = []
			for letter in ["U", "N", "O"]:
				letters.append(rules.hands[actor].filter(func(card_id: int) -> bool: return card_id != keep and rules.cards[card_id].get("letter", "") == letter)[0])
			for held in rules.hands[actor]:
				if held != keep and held not in letters: rules.discard.push_front(held)
			for held in letters:
				rules.discard.append(held)
				rules._flight("play", actor, 1, rules.cards[held])
			rules.hands[actor] = [keep]
			rules.color = value
			choice.clear()
		_:
			return false
	if choice.is_empty():
		if context.get("uno_pending", false):
			_uno(rules, actor)
			context.uno_pending = false
		_resolve(rules)
	rules.revision += 1
	return true


func _response(rules, seat: int, card: Dictionary) -> void:
	var penalty: Dictionary = penalties[0]
	match card.kind:
		"block": penalties.pop_front()
		"deflect": penalty.target = rules.next_seat(seat)
		"rebound":
			penalty.target = penalty.source
			penalty.amount += 1
			penalty.follow = false
		"redirect":
			context = {"actor":seat, "origin":seat, "after":resume}
			_ask(rules, "redirect", "Choose who receives the draw penalty.", _others(rules, seat))
		"no_u":
			rules.direction *= -1
			penalty.target = penalty.source
		"petty":
			penalty.petty_used = true
			_job(rules, penalty.source, 3, seat, "petty")
			_pay(rules)
		_:
			penalty.amount += _draw_value(rules, card.kind)
			penalty.target = rules.next_seat(seat)
			penalty.kind = card.kind
			penalty.source = seat
	penalty.color = rules.color
	if penalty.get("follow", false): resume = rules.next_seat(penalty.target)
	_resolve(rules)


func _draw_cards(rules, seat: int, amount: int) -> void:
	var taken: Array = rules._take(seat, amount)
	if not taken.is_empty():
		rules._flight("draw", seat, taken.size())
		rules._effect("draw", seat, taken.size())


func _pay(rules) -> void:
	var penalty: Dictionary = penalties.pop_front()
	var recipient: int = penalty.target
	if penalty.get("skip_only", false): rules._effect("skip", recipient)
	else:
		var amount: int = penalty.amount
		if penalty.has("until"):
			var taken: Array = []
			while true:
				var card: Array = rules._take(recipient, 1)
				if card.is_empty(): break
				taken.append(card[0])
				if rules.cards[card[0]].color == penalty.until: break
			if not taken.is_empty(): rules._flight("draw", recipient, taken.size())
			amount = taken.size()
		else: _draw_cards(rules, recipient, amount)
		if amount > 0 and int(enemies.get(penalty.source, -1)) == recipient: _draw_cards(rules, recipient, 2)
		if amount > 0 and basket[1] == recipient and basket[0] >= 0 and penalty.kind in ["draw2", "draw4"]: _draw_cards(rules, basket[0], amount)
	if penalty.get("follow", false): resume = rules.next_seat(recipient)
	rules.pending_draw = 0


func _resolve(rules) -> void:
	if not choice.is_empty(): return
	_basket_uno(rules)
	var actor: int = int(context.get("actor", rules.turn))
	var candidates: Array = [actor]
	candidates.append_array(_others(rules, actor))
	for seat in candidates:
		if rules.hands[seat].is_empty():
			finish_candidate = seat
			break
	if finish_candidate >= 0:
		while not penalties.is_empty(): _pay(rules)
		rules.pending_draw = 0
		if rules.hands[finish_candidate].is_empty():
			rules._finish(finish_candidate)
			return
		finish_candidate = -1
	if not penalties.is_empty():
		if resume < 0: resume = int(context.get("after", rules.next_seat(rules.turn)))
		rules.turn = int(penalties[0].target)
		rules.phase = "addon_response"
		rules.pending_draw = int(penalties[0].amount)
		rules.drawn = -1
		return
	var next: int = resume if resume >= 0 else int(context.get("after", rules.next_seat(rules.turn)))
	rules.pending_draw = 0
	resume = -1
	if context.get("continuing", false):
		rules.turn = next
		rules.phase = "play"
		rules.drawn = -1
	else: start_turn(rules, next)
	rules.jump_open = rules.phase == "play" and remaining == speed and str(rules.cards[rules.discard.back()].kind).is_valid_int()


func draw(rules, seat: int) -> bool:
	if seat != rules.turn or rules.drawn >= 0 or rules.winner >= 0 or rules.phase not in ["play", "addon_response"]: return false
	if rules.phase == "play" and speed > 1 and not rules.legal_cards(seat).is_empty(): return false
	rules._begin_action()
	rules.armed[seat] = false
	if rules.phase == "addon_response":
		_pay(rules)
		_resolve(rules)
	elif speed > 1:
		_draw_cards(rules, seat, speed)
		speed = 1
		start_turn(rules, rules.next_seat(seat))
		rules.last_event = "Crashed — speed resets to one."
	else:
		var keep_drawing: bool = rules.draw_until_play and rules.legal_cards(seat).is_empty()
		var taken: Array = rules._take(seat, 1)
		if not taken.is_empty(): rules._flight("draw", seat, taken.size())
		if taken.is_empty(): start_turn(rules, rules.next_seat(seat))
		else:
			rules.drawn = taken[0]
			if not playable(rules, seat, rules.drawn):
				rules.drawn = -1
				if not keep_drawing: start_turn(rules, rules.next_seat(seat))
			elif rules.force_play and rules.cards[rules.drawn].color == "wild": rules.phase = "drawn_color"
	_basket_uno(rules)
	rules.revision += 1
	return true


func pass_turn(rules, seat: int) -> bool:
	if seat != rules.turn or rules.phase != "play" or rules.drawn < 0 or rules.force_play: return false
	rules._begin_action()
	rules.armed[seat] = false
	start_turn(rules, rules.next_seat(seat))
	rules.revision += 1
	return true


func decline(rules, seat: int) -> bool:
	if rules.phase != "addon_assist" or seat != rules.turn: return false
	rules._begin_action()
	rules.turn = context.origin
	rules.phase = "play"
	assist_declined = true
	context.clear()
	rules.revision += 1
	return true


func end_enemy(rules, seat: int) -> bool:
	if rules.winner >= 0 or not enemies.has(seat): return false
	enemies.erase(seat)
	rules.revision += 1
	return true


func _combo_keeps(rules, seat: int) -> Array:
	return rules.hands[seat].filter(func(keep: int) -> bool:
		return ["U", "N", "O"].all(func(letter: String) -> bool:
			return rules.hands[seat].any(func(id: int) -> bool: return id != keep and rules.cards[id].get("letter", "") == letter)
		)
	)


func can_combo(rules, seat: int) -> bool:
	return seat == rules.turn and rules.phase == "play" and rules.drawn < 0 and not _combo_keeps(rules, seat).is_empty()


func combo(rules, seat: int) -> bool:
	if not can_combo(rules, seat): return false
	rules._begin_action()
	context = {"actor":seat, "origin":seat, "after":rules.next_seat(seat), "uno_pending":true}
	_ask(rules, "combo_keep", "U-N-O — choose the card to keep.")
	rules.revision += 1
	return true


func view(rules, seat: int) -> Dictionary:
	var result := {"enabled_addons":rules.enabled_addons.duplicate(), "speed":speed, "speed_remaining":remaining, "addon_choice":{}, "addon_draw":false, "can_combo":can_combo(rules, seat), "can_end_enemy":enemies.has(seat), "enemies":enemies.duplicate(), "couple":couple.duplicate(), "basket":basket.duplicate(), "revealed_hands":[], "revealed_cards":private_reveals.get(seat, {}).duplicate(true)}
	if reveal_owner >= 0: result.revealed_hands = rules.hands.map(func(hand: Array) -> Array: return hand.map(func(id: int) -> Dictionary: return rules.cards[id].duplicate()))
	if rules.phase == "addon_response" and seat == rules.turn:
		if penalties[0].get("skip_only", false): result.addon_accept = "ACCEPT SKIP"
		else: result.addon_draw = true
	if rules.phase == "addon_assist" and seat == rules.turn: result.addon_decline = true
	if not choice.is_empty() and seat == choice.owner:
		var offered: Dictionary = choice.duplicate(true)
		offered.cards = []
		if choice.kind in ["give", "double", "combo_keep", "chat_take"]:
			var ids: Array = rules.hands[choice.target] if choice.kind == "chat_take" else (_combo_keeps(rules, seat) if choice.kind == "combo_keep" else rules.hands[seat])
			offered.cards = ids.map(func(id: int) -> Dictionary: return rules.cards[id].duplicate())
		result.addon_choice = offered
	return result


static func computer_action(view: Dictionary) -> Dictionary:
	var offered: Dictionary = view.get("addon_choice", {})
	if offered.is_empty():
		if view.phase == "addon_response" and view.legal_cards.is_empty(): return {"action":"draw"}
		return {}
	var input := {"action":"addon_choose"}
	if not offered.get("targets", []).is_empty():
		if offered.kind == "instigator": return {"action":"addon_choose", "value":"done"} if not offered.amounts.is_empty() else {"action":"addon_choose", "target":offered.targets.filter(func(seat: int) -> bool: return seat != view.viewer).pick_random(), "amount":4}
		input.target = offered.targets.pick_random()
	elif not offered.get("cards", []).is_empty(): input.card = offered.cards.pick_random().id
	elif offered.kind == "text": input.value = ["draw", "swap", "color"].pick_random()
	elif offered.kind == "combo_color": input.value = view.colors.pick_random()
	else: input.value = "skip"
	return input
