extends RefCounted

const Evaluator = preload("res://Games/poker/host/evaluator.gd")
const DEFAULTS := {"starting_chips": 2000, "small_blind": 10, "big_blind": 20, "ante": 0, "blind_interval": 10}
var variant := "texas"
var options: Dictionary = DEFAULTS.duplicate()
var count := 2
var players: Array = []
var deck: Array = []
var board: Array = []
var burns: Array = []
var dealer := 0
var small_seat := 0
var big_seat := 1
var small_blind := 10
var big_blind := 20
var hand_number := 0
var stage := "preflop"
var phase := "betting"
var turn := -1
var current_bet := 0
var min_raise := 20
var revision := 0
var turn_serial := 0
var total_chips := 4000
var winner := -1
var hand_winners: Array = []
var awards: Array = []
var winning_cards: Dictionary = {}
var showdown := false
var last_pot := 0
var events: Array = []
var event_serial := 0
var rng := RandomNumberGenerator.new()


static func whole(value: Variant, minimum := 0, maximum := 1000000000) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum


static func valid_options(data: Dictionary) -> bool:
	for key in DEFAULTS:
		if not whole(data.get(key), 0, 1000000): return false
	return data.starting_chips >= 20 and data.small_blind >= 1 and data.big_blind >= data.small_blind * 2 and data.big_blind <= data.starting_chips and data.ante < data.starting_chips and data.blind_interval <= 100


func start(seats: int, mode: String, settings: Dictionary = DEFAULTS, first_dealer := 0, random_seed := 0) -> bool:
	if seats < 2 or seats > 10 or mode not in ["texas", "omaha"] or not valid_options(settings): return false
	variant = mode; options = settings.duplicate(true); count = seats
	players.clear(); events.clear(); event_serial = 0
	for seat in count: players.append({"stack": int(options.starting_chips), "street": 0, "committed": 0, "folded": false, "out": false, "hand": [], "has_acted": false, "acted_at": 0, "last_action": "", "last_amount": 0})
	total_chips = count * int(options.starting_chips); dealer = posmod(first_dealer, count); hand_number = 0; winner = -1
	if random_seed == 0: rng.randomize()
	else: rng.seed = random_seed
	_new_hand(); return true


func _next(from: int, predicate: Callable) -> int:
	for offset in range(1, count + 1):
		var seat := posmod(from + offset, count)
		if predicate.call(seat): return seat
	return -1


func live() -> Array:
	return range(count).filter(func(seat: int) -> bool: return not players[seat].out and not players[seat].folded)


func able() -> Array:
	return live().filter(func(seat: int) -> bool: return int(players[seat].stack) > 0)


func pot() -> int:
	var amount := 0
	for player in players: amount += int(player.committed)
	return amount


func _commit(seat: int, amount: int, street := true) -> void:
	amount = mini(amount, int(players[seat].stack))
	players[seat].stack -= amount; players[seat].committed += amount
	if street: players[seat].street += amount


func _event(seat: int, action: String, amount := 0) -> void:
	event_serial += 1; events.push_front({"id": event_serial, "hand": hand_number, "seat": seat, "action": action, "amount": amount})
	if events.size() > 80: events.resize(80)


func _new_hand() -> void:
	hand_number += 1; phase = "betting"; stage = "preflop"; board.clear(); burns.clear(); deck = range(52)
	for index in range(51, 0, -1):
		var other := rng.randi_range(0, index); var card: int = deck[index]; deck[index] = deck[other]; deck[other] = card
	showdown = false; hand_winners.clear(); awards.clear(); winning_cards.clear(); last_pot = 0
	var level := mini(24, int((hand_number - 1) / maxi(1, int(options.blind_interval)) )) if int(options.blind_interval) > 0 else 0
	small_blind = mini(1000000000, int(options.small_blind) * (1 << level)); big_blind = mini(1000000000, int(options.big_blind) * (1 << level))
	for player in players:
		player.out = int(player.stack) == 0; player.folded = false; player.street = 0; player.committed = 0; player.hand = []; player.has_acted = false; player.acted_at = 0; player.last_action = ""; player.last_amount = 0
		player.erase("hand_net")
	var active := live()
	small_seat = dealer if active.size() == 2 else _next(dealer, func(seat: int) -> bool: return not players[seat].out)
	big_seat = _next(small_seat, func(seat: int) -> bool: return not players[seat].out)
	for seat in active: _commit(seat, int(options.ante), false)
	_commit(small_seat, small_blind); _commit(big_seat, big_blind)
	for round_index in (4 if variant == "omaha" else 2):
		var seat := dealer
		for offset in active.size():
			seat = _next(seat, func(candidate: int) -> bool: return not players[candidate].out)
			players[seat].hand.append(deck.pop_back())
	current_bet = big_blind; min_raise = big_blind; revision += 1
	_event(-1, "deal")
	_continue(big_seat)


func next_hand() -> bool:
	if phase != "hand_over": return false
	# Advance the big blind among survivors. This also avoids two consecutive
	# big blinds for the same player when an elimination starts heads-up play.
	var next_big := _next(big_seat, func(seat: int) -> bool: return int(players[seat].stack) > 0)
	var survivors: Array = range(count).filter(func(seat: int) -> bool: return int(players[seat].stack) > 0)
	var index := survivors.find(next_big)
	dealer = int(survivors[posmod(index - (1 if survivors.size() == 2 else 2), survivors.size())])
	_new_hand(); return true


func legal(seat: int) -> Dictionary:
	var result := {"fold": false, "check": false, "call": -1, "can_raise": false, "min_raise_to": 0, "max_raise_to": 0, "all_in": false, "stack": 0}
	if phase != "betting" or seat != turn or seat < 0 or seat >= count: return result
	var player: Dictionary = players[seat]
	var to_call := maxi(0, current_bet - int(player.street))
	var total := int(player.street) + int(player.stack)
	# A short opening all-in is still part of the amount to call. No-limit
	# and pot-limit raise by a full increment; they do not complete that bet.
	var minimum := current_bet + min_raise
	var maximum := total
	if variant == "omaha":
		var limit_pot := pot()
		# Tournament pre-flop pot calculations assume full blinds, even when a
		# short stack could not post one. Post-flop uses the actual pot (TDA 56).
		if stage == "preflop": limit_pot += maxi(0, small_blind - int(players[small_seat].street)) + maxi(0, big_blind - int(players[big_seat].street))
		maximum = mini(maximum, current_bet + limit_pot + to_call)
	var reopened: bool = not player.has_acted or current_bet - int(player.acted_at) >= min_raise
	var can_raise: bool = reopened and able().size() >= 2 and maximum > current_bet and (maximum >= minimum or maximum == total)
	result = {"fold": true, "check": to_call == 0, "call": mini(to_call, int(player.stack)) if to_call > 0 else -1, "can_raise": can_raise, "min_raise_to": mini(minimum, total), "max_raise_to": maximum if can_raise else 0, "all_in": total <= current_bet or (can_raise and maximum == total), "stack": int(player.stack)}
	return result


func act(seat: int, action: String, amount: Variant = -1) -> bool:
	if phase != "betting" or seat != turn: return false
	var choices := legal(seat)
	var player: Dictionary = players[seat]
	var paid := 0
	var feedback_amount := 0
	if action == "all_in":
		if not choices.all_in: return false
		if int(player.street) + int(player.stack) <= current_bet: action = "call"
		else: action = "raise"; amount = int(player.street) + int(player.stack)
	match action:
		"fold": player.folded = true
		"check":
			if not choices.check: return false
		"call":
			if int(choices.call) < 0: return false
			paid = int(choices.call); feedback_amount = paid; _commit(seat, paid)
		"raise":
			if not choices.can_raise or not whole(amount, int(choices.min_raise_to), int(choices.max_raise_to)): return false
			var target := int(amount)
			var increase := target - current_bet
			feedback_amount = increase
			if increase >= min_raise: min_raise = increase
			paid = target - int(player.street); _commit(seat, paid); current_bet = target
		_: return false
	player.has_acted = true; player.acted_at = current_bet; player.last_action = action; player.last_amount = feedback_amount
	_event(seat, action, paid); revision += 1
	_continue(seat); return true


func _needs_action(seat: int) -> bool:
	var player: Dictionary = players[seat]
	return not player.out and not player.folded and int(player.stack) > 0 and (not player.has_acted or int(player.street) < current_bet)


func _continue(after: int) -> void:
	if live().size() == 1: _settle(false); return
	var available := able()
	if available.size() <= 1:
		var highest := 0
		for seat in live(): highest = maxi(highest, int(players[seat].street))
		current_bet = highest
		if available.size() == 1 and int(players[available[0]].street) < current_bet:
			turn = int(available[0]); turn_serial += 1; return
		_refund_uncalled(); turn = -1
		if stage == "river": _settle(true)
		else: phase = "runout"
		return
	var next := _next(after, _needs_action)
	if next >= 0: turn = next; turn_serial += 1; return
	_refund_uncalled()
	if stage == "river": _settle(true)
	else: _street()


func _refund_uncalled() -> void:
	var highest := -1; var second := 0; var owner := -1
	for seat in count:
		var amount := int(players[seat].street)
		if amount > highest: second = maxi(0, highest); highest = amount; owner = seat
		else: second = maxi(second, amount)
	if owner >= 0 and highest > second:
		var refund := highest - second
		players[owner].stack += refund; players[owner].street -= refund; players[owner].committed -= refund
		current_bet = mini(current_bet, second)


func _street() -> void:
	burns.append(deck.pop_back())
	if stage == "preflop":
		stage = "flop"
		for index in 3: board.append(deck.pop_back())
	elif stage == "flop": stage = "turn"; board.append(deck.pop_back())
	elif stage == "turn": stage = "river"; board.append(deck.pop_back())
	for player in players: player.street = 0; player.has_acted = false; player.acted_at = 0; player.last_action = ""; player.last_amount = 0
	current_bet = 0; min_raise = big_blind
	_event(-1, stage)
	if phase == "betting": turn = _next(dealer, _needs_action); turn_serial += 1


func advance_runout() -> bool:
	if phase != "runout": return false
	if stage == "river": _settle(true)
	else: _street()
	revision += 1; return true


func _settle(reveal: bool) -> void:
	_refund_uncalled(); showdown = reveal; last_pot = pot(); awards.clear(); hand_winners.clear(); winning_cards.clear()
	for player in players: player.hand_net = -int(player.committed)
	var levels: Array = []
	for player in players:
		if int(player.committed) > 0 and not levels.has(int(player.committed)): levels.append(int(player.committed))
	levels.sort()
	var previous := 0
	for level: int in levels:
		var contributors := range(count).filter(func(seat: int) -> bool: return int(players[seat].committed) >= level)
		var eligible := contributors.filter(func(seat: int) -> bool: return not players[seat].folded and not players[seat].out)
		var amount := (level - previous) * contributors.size(); previous = level
		# A lone survivor is entitled to folded contributions at every level.
		if eligible.is_empty() and live().size() == 1: eligible = live()
		var winners: Array = []
		var best_score := -1
		for seat: int in eligible:
			var value := Evaluator.best(players[seat].hand, board, variant) if reveal else {"score": 0, "cards": []}
			if int(value.score) > best_score: best_score = int(value.score); winners = [seat]
			elif int(value.score) == best_score: winners.append(seat)
			if reveal: winning_cards[str(seat)] = value.cards
		if winners.is_empty(): continue
		# Odd chips go clockwise from the dealer, never by suit or identity.
		winners.sort_custom(func(a: int, b: int) -> bool: return posmod(a - dealer - 1, count) < posmod(b - dealer - 1, count))
		var shares: Array = []
		for index in winners.size():
			var seat: int = winners[index]; var share := int(amount / winners.size()) + (1 if index < amount % winners.size() else 0)
			players[seat].stack += share; players[seat].hand_net += share; shares.append({"seat": seat, "amount": share})
			if not hand_winners.has(seat): hand_winners.append(seat)
		awards.append({"amount": amount, "winners": winners, "shares": shares})
	for player in players: player.committed = 0; player.street = 0; player.out = int(player.stack) == 0
	turn = -1; current_bet = 0; stage = "showdown"; phase = "hand_over"
	var survivors := range(count).filter(func(seat: int) -> bool: return int(players[seat].stack) > 0)
	if survivors.size() == 1: winner = int(survivors[0]); phase = "finished"
	_event(-1, "showdown" if reveal else "uncontested", last_pot)


func hand_results() -> Array:
	if phase not in ["hand_over", "finished"]: return []
	var rows: Array = []
	for seat in count:
		var player: Dictionary = players[seat]
		var value := {"score": -3, "name": "Eliminated earlier", "cards": []}
		if not player.hand.is_empty():
			if player.folded: value = {"score": -2, "name": "Folded", "cards": []}
			elif showdown: value = Evaluator.five(winning_cards[str(seat)]) if winning_cards.has(str(seat)) else Evaluator.best(player.hand, board, variant)
			else: value = {"score": -1, "name": "Won uncontested", "cards": []}
		var amount := 0
		for pot_award in awards:
			for share in pot_award.shares:
				if int(share.seat) == seat: amount += int(share.amount)
		rows.append({"seat": seat, "score": int(value.score), "category": value.name, "cards": value.cards.duplicate(), "amount": amount, "net": int(player.get("hand_net", amount)), "rank": 0})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.score) > int(b.score) or (int(a.score) == int(b.score) and int(a.seat) < int(b.seat)))
	for index in rows.size():
		if int(rows[index].score) < -1: continue
		rows[index].rank = rows[index - 1].rank if index > 0 and int(rows[index].score) == int(rows[index - 1].score) else index + 1
	return rows


func view_for(viewer := -1) -> Dictionary:
	var table: Array = []
	for index in count:
		var player: Dictionary = players[index]
		var public := {"stack": int(player.stack), "street": int(player.street), "committed": int(player.committed), "folded": player.folded, "out": player.out, "all_in": int(player.stack) == 0 and not player.folded and not player.out, "last_action": player.last_action, "last_amount": int(player.get("last_amount", 0)), "card_count": player.hand.size(), "hand": []}
		if (showdown or phase == "runout") and not player.folded and not player.hand.is_empty(): public.hand = player.hand.duplicate()
		table.append(public)
	var own: Array = players[viewer].hand.duplicate() if viewer >= 0 and viewer < count else []
	return {"variant": variant, "revision": revision, "hand_number": hand_number, "phase": phase, "stage": stage, "turn": turn, "turn_serial": turn_serial, "dealer": dealer, "small_seat": small_seat, "big_seat": big_seat, "small_blind": small_blind, "big_blind": big_blind, "pot": last_pot if phase in ["hand_over", "finished"] else pot(), "current_bet": current_bet, "players": table, "board": board.duplicate(), "viewer": viewer, "hand": own, "hand_category": Evaluator.best(own, board, variant).name if not own.is_empty() else "", "legal": legal(viewer), "winner": winner, "hand_winners": hand_winners.duplicate(), "awards": awards.duplicate(true), "winning_cards": winning_cards.duplicate(true) if showdown else {}, "hand_results": hand_results(), "showdown": showdown, "events": events.duplicate(true), "options": options.duplicate(true)}


func export_state() -> Dictionary:
	var result: Dictionary = {}
	for key in ["variant", "options", "count", "players", "deck", "board", "burns", "dealer", "small_seat", "big_seat", "small_blind", "big_blind", "hand_number", "stage", "phase", "turn", "current_bet", "min_raise", "revision", "turn_serial", "total_chips", "winner", "hand_winners", "awards", "winning_cards", "showdown", "last_pot", "events", "event_serial"]: result[key] = get(key)
	result = result.duplicate(true); result.rng_state = str(rng.state); return result


func import_state(data: Dictionary) -> bool:
	if data.get("variant") not in ["texas", "omaha"] or not data.get("options") is Dictionary or not valid_options(data.options) or not whole(data.get("count"), 2, 10): return false
	var seats := int(data.count)
	if data.get("phase") not in ["betting", "runout", "hand_over", "finished"] or data.get("stage") not in ["preflop", "flop", "turn", "river", "showdown"] or not data.get("players") is Array or data.players.size() != seats: return false
	for key in ["dealer", "small_seat", "big_seat"]:
		if not whole(data.get(key), 0, seats - 1): return false
	for key in ["revision", "turn_serial", "hand_number", "min_raise", "small_blind", "big_blind", "total_chips"]:
		if not whole(data.get(key), 1): return false
	for key in ["current_bet", "last_pot", "event_serial"]:
		if not whole(data.get(key)): return false
	if not whole(data.get("turn"), -1, seats - 1) or not whole(data.get("winner"), -1, seats - 1) or not data.get("showdown") is bool or not data.get("rng_state") is String or not data.rng_state.is_valid_int(): return false
	if int(data.total_chips) != seats * int(data.options.starting_chips): return false
	var cards: Array = []; var chips := 0
	for key in ["deck", "board", "burns"]:
		if not data.get(key) is Array: return false
		cards.append_array(data[key])
	if data.board.size() not in [0, 3, 4, 5] or data.burns.size() > 3: return false
	if data.phase in ["betting", "runout"] and data.board.size() != {"preflop": 0, "flop": 3, "turn": 4, "river": 5}.get(data.stage, -1): return false
	for player in data.players:
		if not player is Dictionary: return false
		for key in ["stack", "street", "committed", "acted_at"]:
			if not whole(player.get(key), 0, int(data.total_chips)): return false
		for key in ["folded", "out", "has_acted"]:
			if not player.get(key) is bool: return false
		if not player.get("last_action") is String or player.last_action not in ["", "check", "fold", "call", "raise"] or not player.get("hand") is Array or player.street > player.committed: return false
		if not whole(player.get("last_amount", 0), 0, int(data.total_chips)): return false
		if not whole(player.get("hand_net", 0), -int(data.total_chips), int(data.total_chips)): return false
		if player.out and int(player.stack) != 0: return false
		if player.hand.size() != (4 if data.variant == "omaha" else 2) and not (player.out and player.hand.is_empty()): return false
		cards.append_array(player.hand); chips += int(player.stack) + int(player.committed)
	if chips != int(data.total_chips) or cards.size() != 52: return false
	var seen: Dictionary = {}
	for card in cards:
		if not whole(card, 0, 51) or seen.has(int(card)): return false
		seen[int(card)] = true
	if data.phase == "betting" and (int(data.turn) < 0 or data.players[int(data.turn)].out or data.players[int(data.turn)].folded or int(data.players[int(data.turn)].stack) == 0): return false
	if data.phase != "betting" and int(data.turn) != -1: return false
	if (data.phase == "finished") != (int(data.winner) >= 0): return false
	if data.phase == "finished":
		var solvent := range(seats).filter(func(seat: int) -> bool: return int(data.players[seat].stack) > 0)
		if solvent.size() != 1 or int(solvent[0]) != int(data.winner): return false
	if data.phase == "hand_over" and data.players.filter(func(player: Dictionary) -> bool: return int(player.stack) > 0).size() < 2: return false
	if data.phase == "runout":
		var contenders: Array = data.players.filter(func(player: Dictionary) -> bool: return not player.out and not player.folded)
		var available: Array = contenders.filter(func(player: Dictionary) -> bool: return int(player.stack) > 0)
		if contenders.size() < 2 or available.size() > 1: return false
		if available.size() == 1 and int(available[0].street) < int(data.current_bet): return false
	if data.showdown and (data.phase not in ["hand_over", "finished"] or data.board.size() != 5): return false
	if data.phase in ["hand_over", "finished"]:
		if data.stage != "showdown": return false
		for player in data.players:
			if int(player.committed) != 0: return false
	for key in ["hand_winners", "awards", "events"]:
		if not data.get(key) is Array: return false
	if not data.get("winning_cards") is Dictionary or data.events.size() > 80 or data.awards.size() > seats: return false
	if data.phase in ["betting", "runout"] and (not data.hand_winners.is_empty() or not data.awards.is_empty() or not data.winning_cards.is_empty()): return false
	for event in data.events:
		if not event is Dictionary or not whole(event.get("id"), 1) or not whole(event.get("hand"), 1, int(data.hand_number)) or not whole(event.get("seat"), -1, seats - 1) or not whole(event.get("amount")) or event.get("action") not in ["deal", "fold", "check", "call", "raise", "flop", "turn", "river", "showdown", "uncontested"]: return false
	for seat in data.hand_winners:
		if not whole(seat, 0, seats - 1): return false
	var awarded := 0
	for award in data.awards:
		if not award is Dictionary or not whole(award.get("amount"), 1, int(data.total_chips)) or not award.get("winners") is Array or not award.get("shares") is Array: return false
		if award.winners.is_empty() or award.winners.size() != award.shares.size(): return false
		var shares_total := 0; var award_seats: Dictionary = {}
		for share in award.shares:
			if not share is Dictionary or not whole(share.get("seat"), 0, seats - 1) or not whole(share.get("amount"), 0, int(data.total_chips)): return false
			if award_seats.has(int(share.seat)) or not award.winners.has(share.seat): return false
			award_seats[int(share.seat)] = true; shares_total += int(share.amount)
		if shares_total != int(award.amount): return false
		awarded += int(award.amount)
	if data.phase in ["hand_over", "finished"] and awarded != int(data.last_pot): return false
	for key in data.winning_cards:
		if not str(key).is_valid_int() or not whole(int(key), 0, seats - 1) or not data.winning_cards[key] is Array: return false
		if data.winning_cards[key].size() != 5 or data.players[int(key)].folded: return false
		for card in data.winning_cards[key]:
			if not whole(card, 0, 51) or (not data.board.has(card) and not data.players[int(key)].hand.has(card)): return false
	# JSON transports numbers as floats. Restore canonical integer card/seat IDs
	# so reconnect comparisons, membership and future shuffles remain exact.
	data = data.duplicate(true)
	for key in ["count", "dealer", "small_seat", "big_seat", "small_blind", "big_blind", "hand_number", "turn", "current_bet", "min_raise", "revision", "turn_serial", "total_chips", "winner", "last_pot", "event_serial"]: data[key] = int(data[key])
	for key in ["deck", "board", "burns", "hand_winners"]: data[key] = data[key].map(func(value: Variant) -> int: return int(value))
	for player in data.players:
		for key in ["stack", "street", "committed", "acted_at"]: player[key] = int(player[key])
		player.last_amount = int(player.get("last_amount", 0))
		if player.has("hand_net"): player.hand_net = int(player.hand_net)
		player.hand = player.hand.map(func(value: Variant) -> int: return int(value))
	for key in data.winning_cards: data.winning_cards[key] = data.winning_cards[key].map(func(value: Variant) -> int: return int(value))
	for key in export_state():
		if key != "rng_state": set(key, data[key])
	rng.state = int(data.rng_state); return true
