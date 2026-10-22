extends RefCounted

signal card_drawn(card: int, seat: int)
signal stock_shuffled()

# Pure host-authoritative rules. Art, names, networking and timers live elsewhere.
var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Games/monopoly-deal/cards.json"))
var cards: Array = definition.cards
var colors: Dictionary = definition.groups
var hands: Array = []
var banks: Array = []
var properties: Array = []
var loose: Array = []
var deck: Array = []
var discard: Array = []
var turn := 0
var starter := 0
var plays := 0
var phase := "play"
var revision := 0
var winner := -1
var round_number := 0
var next_group := 0
var pending: Dictionary = {}
var history: Array = []
var last_event := ""
var action_notices: Array = []
var action_sequence := 0
var activity: Array = []
var activity_sequence := 0


func start(count: int, first := 0) -> void:
	assert(count >= 2 and count <= 5)
	hands.clear(); banks.clear(); properties.clear(); loose.clear()
	for seat in count:
		hands.append([]); banks.append([]); properties.append([]); loose.append([])
	deck = range(cards.size()); deck.shuffle(); discard.clear(); pending.clear(); history.clear()
	action_notices.clear()
	activity.clear()
	starter = posmod(first, count); turn = starter; plays = 0; winner = -1; phase = "play"; next_group = 0
	round_number += 1; revision += 1
	for pass_index in 5:
		for seat in count: _draw(seat, 1)
	_draw(turn, 2)
	_event("New deal")


func replay() -> void:
	start(hands.size(), (starter + 1) % hands.size())


static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == float(int(value))


static func _normalize(value: Variant) -> Variant:
	# JSON decodes numbers as floats; normalize only whole finite numbers before
	# comparing offered commands. Dictionary equality otherwise distinguishes them.
	if value is float and integer(value): return int(value)
	if value is Array:
		var list: Array = []
		for item in value: list.append(_normalize(item))
		return list
	if value is Dictionary:
		var mapping: Dictionary = {}
		for key in value: mapping[key] = _normalize(value[key])
		return mapping
	return value


func complete(group: Dictionary) -> bool:
	return group.cards.size() >= int(colors[group.color].size) and group.cards.any(func(id: int) -> bool: return cards[id].value > 0)


func completed(seat: int) -> int:
	var found: Array = []
	for group in properties[seat]:
		if complete(group) and not found.has(group.color): found.append(group.color)
	return found.size()


func rent(group: Dictionary) -> int:
	if group.cards.is_empty() or not group.cards.any(func(id: int) -> bool: return cards[id].value > 0): return 0
	var amounts: Array = colors[group.color].rent
	var amount := int(amounts[mini(group.cards.size(), amounts.size()) - 1])
	if complete(group):
		for id in group.buildings: amount += 3 if cards[id].kind == "house" else 4
	return amount


func group_for(seat: int, gid: int) -> Dictionary:
	for group in properties[seat]:
		if group.id == gid: return group
	return {}


func _destinations(seat: int, color: String) -> Array:
	var result: Array = [-1]
	for group in properties[seat]:
		if group.color == color and group.cards.size() < int(colors[color].size): result.append(group.id)
	return result


func _put_property(seat: int, id: int, color: String, gid := -1) -> void:
	var group := group_for(seat, gid)
	if group.is_empty():
		group = {"id": next_group, "color": color, "cards": [], "buildings": []}
		next_group += 1; properties[seat].append(group)
	group.cards.append(id)


func _receive_property(seat: int, id: int, color: String) -> void:
	var destinations := _destinations(seat, color)
	_put_property(seat, id, color, int(destinations[1]) if destinations.size() > 1 else -1)


func _remove_property(seat: int, id: int) -> String:
	for group in properties[seat]:
		if group.cards.has(id):
			var color: String = group.color
			group.cards.erase(id)
			if not complete(group):
				discard.append_array(group.buildings); group.buildings.clear()
			if group.cards.is_empty(): properties[seat].erase(group)
			return color
	return ""


func _draw(seat: int, amount: int) -> void:
	for index in amount:
		if deck.is_empty():
			if discard.is_empty(): break
			deck = discard.duplicate(); discard.clear(); deck.shuffle()
			stock_shuffled.emit()
		var id: int = deck.pop_back()
		hands[seat].append(id); card_drawn.emit(id, seat)


func _event(text: String) -> void:
	last_event = text
	history.push_front({"seat": turn, "text": text})
	if history.size() > 80: history.resize(80)


func _activity(seat: int, kind: String, details: Dictionary = {}) -> void:
	activity_sequence += 1
	var entry := details.duplicate(true); entry.id = activity_sequence; entry.seat = seat; entry.kind = kind
	activity.push_front(entry)
	if activity.size() > 80: activity.resize(80)


func _check_win() -> void:
	if parallel_pending() and not pending.branches.is_empty(): return
	for offset in hands.size():
		var seat := (turn + offset) % hands.size()
		if completed(seat) >= 3:
			winner = seat; phase = "finished"; pending.clear(); _event("Three complete sets — wins!"); return


func _finish_play() -> void:
	phase = "play"; pending.clear(); _check_win()


func _choice(list: Array, label: String, payload: Dictionary) -> void:
	list.append({"label": label, "payload": payload})


func legal_actions(seat: int) -> Array:
	var result: Array = []
	if seat < 0 or seat >= hands.size() or winner >= 0: return result
	if parallel_pending():
		for branch in pending.branches:
			if branch.phase != "response" or int(branch.ask) != seat: continue
			_choice(result, "Keep cancellation" if branch.canceled else "Pay $%d" % pending.amount, {"action": "accept", "target": branch.target, "effect": branch.effect})
			for id in hands[seat]:
				if cards[id].kind == "just-say-no" and (seat != turn or plays < 3): _choice(result, "Just Say No", {"action": "no", "card": id, "target": branch.target, "effect": branch.effect})
		return result
	if phase == "response":
		if seat != int(pending.ask): return result
		_choice(result, "Keep cancellation" if pending.canceled else "Pay $%d" % pending.amount if pending.kind in ["rent", "birthday", "debt"] else "Allow property transfer", {"action": "accept"})
		for id in hands[seat]:
			if cards[id].kind == "just-say-no" and (seat != turn or plays < 3): _choice(result, "Just Say No", {"action": "no", "card": id})
		return result
	if phase == "pay" or seat != turn: return result
	if phase == "discard":
		for id in hands[seat]: _choice(result, "Discard", {"action": "discard", "card": id})
		return result
	_choice(result, "End turn", {"action": "end"})
	var payable_opponents: Array = []
	for target in hands.size():
		if target != seat and not payment_assets(target).is_empty(): payable_opponents.append(target)
	for id in hands[seat]:
		var card: Dictionary = cards[id]
		if plays >= 3: continue
		if card.value > 0 and not card.kind in ["property", "wild"]: _choice(result, "Bank $%d" % card.value, {"action": "bank", "card": id})
		if card.kind in ["property", "wild"]:
			for color: String in card.colors:
				for gid: int in _destinations(seat, color):
					_choice(result, "Add to %s%s" % [colors[color].name, " · new group" if gid < 0 else " · set %d" % (gid + 1)], {"action": "property", "card": id, "color": color, "group": gid})
		elif card.kind == "pass-go": _choice(result, "Draw 2 cards", {"action": "go", "card": id})
		elif card.kind in ["house", "hotel"]:
			_build_choices(result, seat, id, "building")
		elif card.kind == "birthday":
			if not payable_opponents.is_empty(): _choice(result, "Collect $2 from everyone", {"action": "birthday", "card": id})
		elif card.kind == "debt-collector":
			for target in payable_opponents: _choice(result, "Collect $5", {"action": "debt", "card": id, "target": target})
		elif card.kind == "rent":
			if payable_opponents.is_empty(): continue
			for group in properties[seat]:
				if not group.color in card.colors or rent(group) <= 0: continue
				var multipliers: Array = [[]]
				# G0351: Double the Rent accompanies any rent; each costs a play.
				if card.kind == "rent":
					var doubles: Array = hands[seat].filter(func(other: int) -> bool: return cards[other].kind == "double-rent")
					if plays <= 1:
						for other in doubles: multipliers.append([other])
					if plays == 0 and doubles.size() == 2: multipliers.append(doubles.duplicate())
				for extra in multipliers:
					var payload := {"action": "rent", "card": id, "group": group.id, "double": extra}
					var caption := "%s rent · $%d%s" % [colors[group.color].name, rent(group) * int(pow(2, extra.size())), " each" if card.colors.size() == 2 else ""]
					if card.colors.size() == 2: _choice(result, caption, payload)
					else:
						for target in payable_opponents:
							var single := payload.duplicate(true); single.target = target; _choice(result, caption, single)
		elif card.kind in ["sly-deal", "forced-deal", "deal-breaker"]:
			for target in hands.size():
				if target == seat: continue
				for group in properties[target]:
					if card.kind == "deal-breaker":
						if complete(group): _choice(result, "Take %s set" % colors[group.color].name, {"action": "deal-breaker", "card": id, "target": target, "group": group.id})
					elif not complete(group):
						for take in group.cards:
							if card.kind == "sly-deal": _choice(result, "Take " + cards[take].name, {"action": "sly-deal", "card": id, "target": target, "take": take})
							else:
								for own in properties[seat]:
									for give in own.cards: _choice(result, "Give %s · take %s" % [cards[give].name, cards[take].name], {"action": "forced-deal", "card": id, "target": target, "take": take, "give": give})
	# Already-played properties and buildings can be reorganized without a play.
	for group in properties[seat]:
		for id in group.cards:
			if not cards[id].kind in ["property", "wild"]: continue
			for color: String in cards[id].colors:
				for gid: int in _destinations(seat, color):
					if gid == group.id or (gid < 0 and group.cards.size() == 1 and color == group.color): continue
					_choice(result, "Move to %s%s" % [colors[color].name, " · new group" if gid < 0 else " · set %d" % (gid + 1)], {"action": "move", "card": id, "color": color, "group": gid})
		for id in group.buildings: _build_choices(result, seat, id, "move-building", group.id)
	for id in loose[seat]: _build_choices(result, seat, id, "move-building")
	return result


func _build_choices(result: Array, seat: int, id: int, action: String, source := -1) -> void:
	for group in properties[seat]:
		if group.id == source or group.color in ["railroad", "utility"] or not complete(group): continue
		var kinds: Array = group.buildings.map(func(other: int) -> String: return cards[other].kind)
		if cards[id].kind in kinds or (cards[id].kind == "hotel" and not "house" in kinds): continue
		_choice(result, "Add %s to %s" % [cards[id].name, colors[group.color].name], {"action": action, "card": id, "group": group.id})


# UI defaults are derived from offered commands; they never bypass validation.
# Ordinary properties join the fullest available set. Wilds still ask a color.
func tap_choices(seat: int, id: int, bank_mode := false, doubles: Array = []) -> Array:
	var choices := legal_actions(seat).filter(func(choice: Dictionary) -> bool: return int(choice.payload.get("card", -1)) == id)
	if bank_mode or cards[id].kind == "money": return choices.filter(func(choice: Dictionary) -> bool: return choice.payload.action == "bank")
	choices = choices.filter(func(choice: Dictionary) -> bool: return choice.payload.action != "bank")
	var result: Array = []
	for choice in choices:
		var command: Dictionary = choice.payload
		if command.action == "rent":
			var requested := doubles.duplicate(); requested.sort()
			var offered: Array = command.double.duplicate(); offered.sort()
			if requested != offered: continue
		if command.action in ["property", "move"]:
			var same := choices.filter(func(other: Dictionary) -> bool: return other.payload.get("color", "") == command.color)
			same.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var left := group_for(seat, int(a.payload.group)); var right := group_for(seat, int(b.payload.group))
				return (0 if left.is_empty() else left.cards.size()) > (0 if right.is_empty() else right.cards.size()))
			if command != same[0].payload: continue
		result.append(choice)
	if cards[id].kind == "rent":
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var left := rent(group_for(seat, int(a.payload.group))) * int(pow(2, a.payload.double.size()))
			var right := rent(group_for(seat, int(b.payload.group))) * int(pow(2, b.payload.double.size()))
			return left > right if left != right else int(a.payload.group) < int(b.payload.group) if a.payload.group != b.payload.group else int(a.payload.get("target", -1)) < int(b.payload.get("target", -1)))
	elif cards[id].kind == "wild" and cards[id].colors.size() > 2:
		result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var left_done: bool = properties[seat].any(func(group: Dictionary) -> bool: return group.color == a.payload.color and complete(group))
			var right_done: bool = properties[seat].any(func(group: Dictionary) -> bool: return group.color == b.payload.color and complete(group))
			if left_done != right_done: return not left_done
			var left := int(colors[a.payload.color].rent.back()); var right := int(colors[b.payload.color].rent.back())
			return left > right if left != right else colors.keys().find(a.payload.color) < colors.keys().find(b.payload.color))
	return result


func rent_cards_for_double(seat: int, id: int, armed: Array = []) -> Array:
	var doubles := armed.duplicate()
	if not doubles.has(id): doubles.append(id)
	var result: Array = []
	for held: int in hands[seat]:
		if cards[held].kind != "rent": continue
		var choices := tap_choices(seat, held, false, doubles)
		if not choices.is_empty(): result.append({"card": public_card(held, seat), "amount": preview_for(seat, choices[0].payload).amount, "doubles": doubles.duplicate()})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.amount) > int(b.amount) if a.amount != b.amount else int(a.card.id) < int(b.card.id))
	return result


func payment_assets(seat: int) -> Array:
	var result: Array = banks[seat].duplicate()
	result.append_array(loose[seat])
	for group in properties[seat]: result.append_array(group.cards); result.append_array(group.buildings)
	return result.filter(func(id: int) -> bool: return cards[id].value > 0)


# Public properties retain the face that is currently upright on their table.
func public_card(id: int, seat := -1) -> Dictionary:
	var card: Dictionary = cards[id].duplicate(true)
	if card.kind == "wild" and card.colors.size() == 2:
		var owners: Array = [seat] if seat >= 0 else range(properties.size())
		for owner: int in owners:
			for group in properties[owner]:
				if group.cards.has(id): card.face_side = int(group.color == card.colors[1]); return card
	return card


func parallel_pending() -> bool:
	return pending.has("branches")


func decision_for(seat: int) -> Dictionary:
	if pending.is_empty(): return {}
	if parallel_pending():
		for branch in pending.branches:
			if branch.phase == "response" and int(branch.ask) == seat: return branch
		for branch in pending.branches:
			if branch.phase == "pay" and int(branch.target) == seat: return branch
		return {}
	if (phase == "response" and int(pending.ask) == seat) or (phase == "pay" and int(pending.target) == seat):
		var result := pending.duplicate(true); result.phase = phase; return result
	return {}


func decision_actors() -> Array:
	if not parallel_pending():
		return [int(pending.ask) if phase == "response" else int(pending.target)] if phase in ["response", "pay"] else [turn]
	var result: Array = []
	for branch in pending.branches:
		var seat := int(branch.ask) if branch.phase == "response" else int(branch.target)
		if not result.has(seat): result.append(seat)
	return result


func payment_command(seat: int, ids: Array) -> Dictionary:
	var command := {"action": "pay", "cards": ids.duplicate()}
	var branch := decision_for(seat)
	if parallel_pending() and not branch.is_empty(): command.target = branch.target; command.effect = branch.effect
	return command


func apply(seat: int, input: Dictionary) -> bool:
	if not integer(input.get("revision")) or seat < 0 or seat >= hands.size() or winner >= 0: return false
	var branch: Dictionary = {}
	if parallel_pending() and integer(input.get("target")) and integer(input.get("effect")):
		for candidate in pending.branches:
			if int(candidate.target) == int(input.target) and int(candidate.effect) == int(input.effect): branch = candidate; break
	# Another recipient's response must not invalidate an unchanged decision.
	if int(input.revision) != revision and (branch.is_empty() or int(input.revision) < int(branch.effect) or int(input.revision) > revision): return false
	var command: Dictionary = _normalize(input); command.erase("revision")
	if parallel_pending() and not branch.is_empty():
		if command.get("action") == "pay":
			if not _pay_parallel(seat, command, branch): return false
		else:
			var offered := legal_actions(seat)
			if not offered.any(func(choice: Dictionary) -> bool: return _normalize(choice.payload) == command): return false
			_execute_parallel(seat, command, branch)
		_check_win(); revision += 1; return true
	if parallel_pending(): return false
	if command.get("action") == "pay":
		if not _pay(seat, command): return false
	else:
		var offered := legal_actions(seat)
		if not offered.any(func(choice: Dictionary) -> bool: return _normalize(choice.payload) == command): return false
		_execute(seat, command)
	_check_win()
	revision += 1
	return true


func end_timed_turn() -> bool:
	# Only the session's host clock calls this. Pending effects must finish first.
	if winner >= 0 or not phase in ["play", "discard"]: return false
	var ordered: Array = hands[turn].duplicate()
	ordered.sort_custom(func(a: int, b: int) -> bool:
		return cards[a].value < cards[b].value if cards[a].value != cards[b].value else a < b)
	while hands[turn].size() > 7:
		var id: int = ordered.pop_front()
		hands[turn].erase(id); discard.append(id); _activity(turn, "discard", {"card": id})
	_event("Turn timer expired · discarded lowest-value excess cards")
	_next_turn(); revision += 1
	return true


func _consume(seat: int, id: int) -> void:
	hands[seat].erase(id); plays += 1


func _execute(seat: int, command: Dictionary) -> void:
	var action: String = command.action
	var id := int(command.get("card", -1))
	match action:
		"end":
			if hands[seat].size() > 7: phase = "discard"
			else: _next_turn()
		"discard":
			hands[seat].erase(id); discard.append(id); _event("Discarded a card")
			_activity(seat, "discard", {"card": id})
			if hands[seat].size() <= 7: _next_turn()
		"bank":
			_consume(seat, id); banks[seat].append(id); _event("Banked $%d" % cards[id].value)
			_activity(seat, "bank", {"card": id, "amount": cards[id].value})
		"property":
			_consume(seat, id); _put_property(seat, id, command.color, int(command.group)); _event("Added " + cards[id].name)
			_activity(seat, "property", {"card": id})
		"go":
			_consume(seat, id); discard.append(id); var before: int = hands[seat].size(); _draw(seat, 2); _event("Played Pass Go")
			_activity(seat, "go", {"card": id, "amount": hands[seat].size() - before})
		"building", "move-building":
			if action == "building": _consume(seat, id)
			else:
				loose[seat].erase(id)
				for group in properties[seat]:
					if group.buildings.has(id):
						group.buildings.erase(id)
						if cards[id].kind == "house": discard.append_array(group.buildings); group.buildings.clear()
			group_for(seat, int(command.group)).buildings.append(id); _event("Placed " + cards[id].name)
			_activity(seat, action, {"card": id})
		"move":
			_remove_property(seat, id); _put_property(seat, id, command.color, int(command.group)); _event("Moved a wild property")
			_activity(seat, "move", {"card": id})
		"accept": _accept_response()
		"no":
			hands[seat].erase(id); discard.append(id)
			if seat == turn: plays += 1
			pending.canceled = not pending.canceled
			pending.ask = int(pending.actor) if seat == int(pending.target) else int(pending.target)
			pending.responder = seat
			_record_action_notice()
			_event("Just Say No")
			_activity(seat, "no", {"card": id, "target": pending.target})
		_:
			_consume(seat, id); discard.append(id)
			pending = command.duplicate(true)
			pending.actor = seat; pending.kind = action; pending.queue = []
			if action == "rent":
				pending.amount = rent(group_for(seat, int(command.group))) * int(pow(2, command.double.size()))
				for extra in command.double:
					_consume(seat, int(extra)); discard.append(extra); _activity(seat, "double", {"card": extra})
			elif action == "birthday": pending.amount = 2
			elif action == "debt": pending.amount = 5
			if command.has("target"): pending.queue.append(int(command.target))
			else:
				for offset in range(1, hands.size()): pending.queue.append((seat + offset) % hands.size())
			_event("Played " + cards[id].name)
			_activity(seat, action, {"card": id, "target": command.get("target", -1), "amount": pending.get("amount", 0)})
			if not command.has("target"):
				pending.branches = []
				for target in pending.queue: pending.branches.append({"target": target, "ask": target, "canceled": false, "phase": "response", "effect": revision + 1})
				pending.queue.clear(); _sync_parallel()
				for branch in pending.branches: _record_action_notice("pending", -1, branch)
			else: _next_recipient()


func _sync_parallel() -> void:
	if pending.branches.is_empty(): _finish_play(); return
	var first: Dictionary = pending.branches[0]
	for field in ["target", "ask", "canceled", "effect"]: pending[field] = first[field]
	pending.erase("responder")
	if first.has("responder"): pending.responder = first.responder
	phase = "response" if pending.branches.any(func(branch: Dictionary) -> bool: return branch.phase == "response") else "pay"


func _execute_parallel(seat: int, command: Dictionary, branch: Dictionary) -> void:
	if command.action == "no":
		var id := int(command.card); hands[seat].erase(id); discard.append(id)
		if seat == turn: plays += 1
		branch.canceled = not branch.canceled; branch.ask = int(pending.actor) if seat == int(branch.target) else int(branch.target)
		branch.responder = seat; branch.effect = revision + 1
		_record_action_notice("pending", -1, branch); _event("Just Say No")
		_activity(seat, "no", {"card": id, "target": branch.target})
	elif branch.canceled:
		_record_action_notice("canceled", -1, branch); pending.branches.erase(branch)
	else: branch.phase = "pay"; branch.effect = revision + 1
	_sync_parallel()


func _pay_parallel(seat: int, command: Dictionary, branch: Dictionary) -> bool:
	if branch.phase != "pay" or seat != int(branch.target) or command.keys().size() != 4: return false
	# Reuse the same asset validation and transfer rules as a single debt.
	var shared := pending; var old_phase := phase
	pending = shared.duplicate(true); pending.erase("branches"); pending.queue = []
	pending.erase("responder")
	for field in branch: pending[field] = branch[field]
	phase = "pay"
	var accepted := _pay(seat, {"action": "pay", "cards": command.get("cards")}, false)
	pending = shared; phase = old_phase
	if not accepted: return false
	pending.branches.erase(branch); _sync_parallel(); return true


func _next_turn() -> void:
	_activity(turn, "end")
	turn = (turn + 1) % hands.size(); plays = 0; phase = "play"
	action_notices.clear()
	var before: int = hands[turn].size()
	_draw(turn, 5 if hands[turn].is_empty() else 2); _event("Turn started")
	if hands[turn].size() > before: _activity(turn, "draw", {"amount": hands[turn].size() - before})
	_check_win()


func _next_recipient() -> void:
	if pending.queue.is_empty(): _finish_play(); return
	pending.target = pending.queue.pop_front(); pending.ask = pending.target; pending.canceled = false; phase = "response"
	pending.erase("responder"); _record_action_notice()


# Only the played action and already-public selected assets appear in this data.
func action_details(branch: Dictionary = {}) -> Dictionary:
	if pending.is_empty(): return {}
	var details := {"actor": pending.actor, "target": pending.target, "ask": pending.ask, "kind": pending.kind, "card": cards[int(pending.card)].duplicate(true), "amount": pending.get("amount", 0), "canceled": pending.canceled, "responder": pending.get("responder", -1)}
	if not branch.is_empty():
		for field in ["target", "ask", "canceled", "effect", "phase"]:
			if branch.has(field): details[field] = branch[field]
		details.responder = branch.get("responder", -1)
	if pending.has("double"): details.modifiers = pending.double.map(func(id: int) -> Dictionary: return cards[id].duplicate(true))
	if pending.has("take"): details.take_card = public_card(int(pending.take))
	if pending.has("give"): details.give_card = public_card(int(pending.give))
	if pending.kind == "deal-breaker":
		var group := group_for(int(pending.target), int(pending.group))
		if not group.is_empty(): details.set_color = group.color
	return details


func _record_action_notice(outcome := "pending", paid := -1, branch: Dictionary = {}) -> void:
	action_sequence += 1
	var details := action_details(branch); details.id = action_sequence; details.outcome = outcome
	if paid >= 0: details.paid = paid
	action_notices = action_notices.filter(func(prior: Dictionary) -> bool: return int(prior.target) != int(details.target) or int(prior.card.id) != int(details.card.id))
	action_notices.append(details)


func _accept_response() -> void:
	if pending.canceled: _record_action_notice("canceled"); _next_recipient(); return
	var actor := int(pending.actor)
	var target := int(pending.target)
	if pending.kind in ["rent", "birthday", "debt"]: phase = "pay"; return
	_record_action_notice("resolved")
	if pending.kind == "deal-breaker":
		var group := group_for(target, int(pending.group))
		properties[target].erase(group); properties[actor].append(group)
		_activity(actor, "take-set", {"target": target})
	elif pending.kind in ["sly-deal", "forced-deal"]:
		var take := int(pending.take)
		var color := _remove_property(target, take)
		if pending.kind == "forced-deal":
			var give := int(pending.give)
			var own_color := _remove_property(actor, give)
			_receive_property(target, give, own_color)
		_receive_property(actor, take, color)
		_activity(actor, "exchange" if pending.kind == "forced-deal" else "take", {"target": target, "card": take, "give": pending.get("give", -1)})
	_next_recipient()


func _pay(seat: int, command: Dictionary, advance := true) -> bool:
	if phase != "pay" or seat != int(pending.target) or command.keys().size() != 2 or not command.get("cards") is Array: return false
	var eligible := payment_assets(seat)
	var chosen: Array = []
	var total := 0
	for value in command.cards:
		if not integer(value): return false
		var id := int(value)
		if not eligible.has(id) or chosen.has(id): return false
		chosen.append(id); total += int(cards[id].value)
	if total < int(pending.amount) and chosen.size() != eligible.size(): return false
	_record_action_notice("paid", total)
	var actor := int(pending.actor)
	# Transfer chosen buildings before properties so breaking a set cannot discard
	# a building that was explicitly included in the payment.
	chosen.sort_custom(func(a: int, b: int) -> bool: return (0 if cards[a].kind == "hotel" else 1 if cards[a].kind == "house" else 2) < (0 if cards[b].kind == "hotel" else 1 if cards[b].kind == "house" else 2))
	for id: int in chosen:
		if banks[seat].has(id): banks[seat].erase(id); banks[actor].append(id)
		elif cards[id].kind in ["house", "hotel"]:
			loose[seat].erase(id)
			for group in properties[seat]:
				if group.buildings.has(id):
					group.buildings.erase(id)
					if cards[id].kind == "house": discard.append_array(group.buildings); group.buildings.clear()
			banks[actor].append(id)
		else:
			var color := _remove_property(seat, id); _receive_property(actor, id, color)
	_event("Paid $%d (owed $%d; no change)" % [total, pending.amount])
	if not chosen.is_empty(): _activity(seat, "pay", {"target": actor, "amount": total})
	if advance: _next_recipient()
	return true


func view_for(seat: int) -> Dictionary:
	var table: Array = []
	for owner in hands.size():
		var groups: Array = []
		for group in properties[owner]:
			groups.append({"id": group.id, "color": group.color, "cards": group.cards.map(func(id: int) -> Dictionary: return public_card(id, owner)), "buildings": group.buildings.map(func(id: int) -> Dictionary: return cards[id].duplicate(true)), "complete": complete(group), "rent": rent(group)})
		groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return bool(a.complete) if a.complete != b.complete else a.cards.size() > b.cards.size() if a.cards.size() != b.cards.size() else int(a.id) < int(b.id))
		table.append({"count": hands[owner].size(), "bank": banks[owner].map(func(id: int) -> Dictionary: return cards[id].duplicate(true)), "total": banks[owner].reduce(func(sum: int, id: int) -> int: return sum + int(cards[id].value), 0), "sets": completed(owner), "groups": groups, "loose": loose[owner].map(func(id: int) -> Dictionary: return cards[id].duplicate(true))})
	var view := {"revision": revision, "round": round_number, "turn": turn, "plays_left": maxi(0, 3 - plays), "phase": phase, "winner": winner, "viewer": seat, "table": table, "colors": colors.duplicate(true), "hand": [], "actions": [], "deck_count": deck.size(), "top": cards[discard.back()].duplicate(true) if not discard.is_empty() else {}, "event": last_event, "history": history.duplicate(true), "pending": {}}
	view.action_notices = action_notices.duplicate(true)
	view.activity = activity.duplicate(true)
	if not pending.is_empty():
		view.pending = action_details()
	if seat >= 0 and seat < hands.size():
		view.hand = hands[seat].map(func(id: int) -> Dictionary: return cards[id].duplicate(true))
		view.actions = legal_actions(seat)
		for choice in view.actions: choice.preview = preview_for(seat, choice.payload)
		var decision := decision_for(seat)
		if not decision.is_empty():
			view.phase = decision.phase; view.pending = action_details(decision)
			if parallel_pending(): view.actions = view.actions.filter(func(choice: Dictionary) -> bool: return int(choice.payload.target) == int(decision.target))
			if decision.phase == "pay": view["payment"] = {"amount": pending.amount, "assets": payment_assets(seat), "command": payment_command(seat, [])}
	view.parallel_pending = parallel_pending()
	return view


# Public consequences of one offered command, without simulating hidden hands.
func preview_for(seat: int, command: Dictionary) -> Dictionary:
	var result := {"targets": [], "amount": 0, "cards": [], "groups": [], "summary": "", "counterable": false}
	var action := str(command.get("action", ""))
	if action in ["property", "move"] and cards[int(command.card)].kind == "wild" and cards[int(command.card)].colors.size() > 2:
		var color: String = command.color; var spec: Dictionary = colors[color]
		var group := group_for(seat, int(command.group))
		var count: int = 0 if group.is_empty() else group.cards.size()
		result.summary = "%s · %d/%d properties" % [spec.name, count + 1, int(spec.size)]
		# A catalog face illustrates the color, not a card drawn from a hidden hand.
		var face: Dictionary = cards.filter(func(card: Dictionary) -> bool: return card.kind == "property" and card.colors[0] == color)[0].duplicate(true)
		face.id = -100 - colors.keys().find(color)
		result.groups.append({"key": "color", "value": colors.keys().find(color), "owner": seat, "label": "%s · Full set $%d" % [spec.name, int(spec.rent.back())], "cards": [face]})
	elif action in ["rent", "birthday", "debt"]:
		result.amount = 2 if action == "birthday" else 5
		if action == "rent":
			var group := group_for(seat, int(command.group))
			result.amount = rent(group) * int(pow(2, command.double.size()))
			result.summary = "Rent $%d per player" % result.amount
			_preview_group(result, "group", int(group.id), seat, "Rent $%d" % result.amount, group.cards + group.buildings)
		else: result.summary = "Request $%d from each affected player" % result.amount
		if command.has("target"): result.targets.append(int(command.target))
		else:
			for target in hands.size():
				if target != seat: result.targets.append(target)
		result.counterable = true
		if action == "rent" and command.has("target"):
			_preview_group(result, "target", int(command.target), int(command.target), "Pay $%d" % result.amount, banks[int(command.target)])
		if action == "birthday":
			for target in result.targets: _preview_group(result, "affected", int(target), int(target), "Pay $2", banks[int(target)])
	elif action in ["sly-deal", "forced-deal", "deal-breaker"]:
		result.targets = [int(command.target)]; result.counterable = true
		if action == "deal-breaker":
			var group := group_for(int(command.target), int(command.group))
			for id in group.cards + group.buildings: result.cards.append(public_card(int(id)))
			_preview_group(result, "take", int(group.id), int(command.target), str(colors[group.color].name) + " set", group.cards + group.buildings)
			result.summary = "Take the complete %s set and its buildings" % colors[group.color].name
		else:
			result.cards.append(public_card(int(command.take)))
			_preview_group(result, "take", int(command.take), int(command.target), "Take", [command.take])
			result.summary = "Take " + str(cards[int(command.take)].name)
			if action == "forced-deal":
				result.cards.append(public_card(int(command.give))); result.summary += "; give " + str(cards[int(command.give)].name)
				_preview_group(result, "give", int(command.give), seat, "Give", [command.give])
	elif action == "go": result.summary = "Draw up to 2 cards"; result.targets = [seat]
	elif action in ["building", "move-building"]:
		var group := group_for(seat, int(command.group))
		result.summary = "Rent $%d" % (rent(group) + (3 if cards[int(command.card)].kind == "house" else 4))
		_preview_group(result, "group", int(group.id), seat, result.summary, group.cards + group.buildings)
	elif action == "no": result.summary = "Counter the current action with Just Say No"; result.counterable = true
	return result


func _preview_group(result: Dictionary, key: String, value: int, owner: int, label: String, ids: Array) -> void:
	result.groups.append({"key": key, "value": value, "owner": owner, "label": label, "cards": ids.map(func(id: int) -> Dictionary: return public_card(id, owner))})
