extends RefCounted

# Pure, host-owned US Classic rules. Presentation, identities and clocks live
# outside this file. No controller supplies dice, money, ownership or results.
var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Games/monopoly-classic/board.json"))
var properties: Dictionary = {}
var s: Dictionary = {}
var events: Array = []
var rng := RandomNumberGenerator.new()


func _init() -> void:
	for item in definition.properties:
		var property: Dictionary = item.duplicate(true)
		property.id = int(property.id)
		for key in ["price", "mortgage", "building_cost", "value"]: property[key] = int(property[key])
		property.rents = property.rents.map(func(value: Variant) -> int: return int(value))
		properties[property.id] = property


func start(count: int, first := 0, seed_value := 0) -> bool:
	if count < 2 or count > 6 or first < 0 or first >= count: return false
	rng.seed = seed_value if seed_value != 0 else int(Time.get_ticks_usec())
	s = {"count": count, "cash": [], "positions": [], "jailed": [], "bankrupt": [], "held": [], "owners": [], "levels": [], "mortgaged": [], "decks": {}, "turn": first, "starter": first, "turn_serial": 1, "revision": 1, "decision_serial": 0, "phase": "roll", "doubles": 0, "extra_roll": false, "dice": [1, 1], "queue": [], "debt": {}, "transfer": {}, "auction": {}, "trade": {}, "buy_id": -1, "last_card": {}, "winner": -1, "finish_reason": "", "result_wealth": [], "tie_rolls": [], "log": [], "sequence": 0}
	s.building_sale = {}
	for seat in count:
		s.cash.append(1500); s.positions.append(0); s.jailed.append(-1); s.bankrupt.append(false); s.held.append([])
	for index in 40:
		s.owners.append(-1); s.levels.append(0); s.mortgaged.append(false)
	for deck in ["chance", "community"]:
		var cards := range(16)
		for index in range(cards.size() - 1, 0, -1):
			var other := rng.randi_range(0, index); var old: int = cards[index]; cards[index] = cards[other]; cards[other] = old
		s.decks[deck] = cards
	events.clear(); _note("start", {"seat": first})
	return true


static func whole(value: Variant, minimum := 0, maximum := 100000000) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum


func actor() -> int:
	if s.is_empty() or s.phase == "finished": return -1
	match str(s.phase):
		"building_interest": return int(s.building_sale.seat)
		"debt": return int(s.debt.seat)
		"auction": return int(s.auction.seat)
		"transfer": return int(s.transfer.seat)
		"trade": return int(s.trade.to)
	return int(s.turn)


func decision_key() -> String:
	if s.is_empty(): return ""
	match str(s.phase):
		"building_interest": return "building:%d:%d" % [int(s.building_sale.ticket), int(s.building_sale.step)]
		"debt": return "debt:%d" % int(s.debt.ticket)
		"auction": return "auction:%d:%d" % [int(s.auction.ticket), int(s.auction.step)]
		"transfer": return "transfer:%d" % int(s.transfer.ticket)
		"trade": return "trade:%d" % int(s.trade.ticket)
	return "turn:%d" % int(s.turn_serial)


func group_ids(id: int) -> Array:
	if not properties.has(id): return []
	var group: String = properties[id].group
	return properties.keys().filter(func(candidate: int) -> bool: return properties[candidate].group == group)


func owns_set(seat: int, id: int) -> bool:
	return group_ids(id).all(func(candidate: int) -> bool: return int(s.owners[candidate]) == seat)


func buildings_available() -> Dictionary:
	var houses := 32; var hotels := 12
	for level in s.levels:
		if int(level) == 5: hotels -= 1
		else: houses -= int(level)
	return {"houses": houses, "hotels": hotels}


func wealth(seat: int) -> int:
	var result: int = s.cash[seat]
	for id in properties:
		if int(s.owners[id]) != seat: continue
		result += int(properties[id].price) - (int(properties[id].mortgage) if s.mortgaged[id] else 0)
		result += int(s.levels[id]) * int(properties[id].building_cost)
	return result


func liquidation_value(seat: int) -> int:
	var value: int = s.cash[seat]
	for id in properties:
		if int(s.owners[id]) != seat: continue
		value += int(s.levels[id]) * int(properties[id].building_cost) / 2
		if not s.mortgaged[id]: value += int(properties[id].mortgage)
	return value


func rent(id: int, roll: int, multiplier := 1, special_utility := false) -> int:
	var owner: int = s.owners[id]
	if owner < 0 or s.mortgaged[id]: return 0
	var property: Dictionary = properties[id]
	var count := group_ids(id).filter(func(candidate: int) -> bool: return int(s.owners[candidate]) == owner).size()
	if property.group == "railroad": return int(property.rents[count - 1]) * multiplier
	if property.group == "utility": return roll * (10 if special_utility or count == 2 else 4)
	return int(property.rents[int(s.levels[id])]) * (2 if int(s.levels[id]) == 0 and owns_set(owner, id) else 1)


func _choice(actions: Array, label: String, action: String, values: Dictionary = {}) -> void:
	var payload := values.duplicate(true); payload.action = action
	actions.append({"label": label, "payload": payload})


func legal_actions(seat: int) -> Array:
	var actions: Array = []
	if s.is_empty() or seat < 0 or seat >= int(s.count) or s.bankrupt[seat] or s.phase == "finished": return actions
	if s.phase == "building_interest":
		if seat == actor():
			for id in s.building_sale.eligible[str(seat)]: _choice(actions, "Request for " + str(properties[int(id)].name), "claim_building", {"property": int(id)})
			_choice(actions, "No building needed", "decline_building")
		return actions
	if s.phase == "trade":
		if seat == int(s.trade.to):
			_choice(actions, "Accept trade", "accept_trade"); _choice(actions, "Decline", "decline_trade")
		if seat == int(s.trade.from): _choice(actions, "Cancel offer", "cancel_trade")
		return actions
	if s.phase == "auction":
		if seat == actor():
			var minimum: int = 10 if int(s.auction.leader) < 0 else int(s.auction.amount) + 1
			if int(s.cash[seat]) >= minimum:
				var payload := {"amount": minimum}
				if s.auction.get("kind") == "building": payload.property = int(s.auction.selections[str(seat)])
				_choice(actions, "Bid", "bid", payload)
			_choice(actions, "Pass", "pass_bid")
		return actions
	if s.phase == "transfer":
		if seat == actor():
			_choice(actions, "Keep mortgage · pay interest", "keep_mortgage")
			_choice(actions, "Repay mortgage", "redeem_transfer")
		return actions
	if s.phase == "debt" and seat != actor(): return actions
	if seat == int(s.turn) and s.phase in ["roll", "jail", "buy", "manage"]:
		match str(s.phase):
			"roll": _choice(actions, "ROLL DICE", "roll")
			"jail":
				_choice(actions, "Roll for doubles", "roll")
				_choice(actions, "Pay $50", "pay_jail")
				if not s.held[seat].is_empty(): _choice(actions, "Use Jail Free card", "use_jail_card")
			"buy":
				if int(s.cash[seat]) >= int(properties[int(s.buy_id)].price): _choice(actions, "Buy · $%d" % int(properties[int(s.buy_id)].price), "buy")
				_choice(actions, "Auction", "auction")
			"manage": _choice(actions, "Roll again" if s.extra_roll else "END TURN", "roll" if s.extra_roll else "end")
	if s.phase == "debt":
		if int(s.cash[seat]) >= int(s.debt.amount): _choice(actions, "Pay $%d" % int(s.debt.amount), "pay_debt")
		elif liquidation_value(seat) < int(s.debt.amount): _choice(actions, "Declare bankruptcy", "bankrupt")
	if not s.phase in ["roll", "jail", "buy", "manage", "debt"]: return actions
	var stock := buildings_available()
	for id in properties:
		if int(s.owners[id]) != seat: continue
		var property: Dictionary = properties[id]
		var ids := group_ids(id)
		var clear := ids.all(func(other: int) -> bool: return int(s.levels[other]) == 0)
		var level: int = s.levels[id]
		if not s.mortgaged[id] and clear: _choice(actions, "Mortgage · +$%d" % int(property.mortgage), "mortgage", {"property": id})
		if s.mortgaged[id] and s.phase != "debt" and int(s.cash[seat]) >= _unmortgage_cost(id): _choice(actions, "Repay · $%d" % _unmortgage_cost(id), "unmortgage", {"property": id})
		if int(property.building_cost) == 0: continue
		var maximum := 0; var minimum := 5
		for other in ids: maximum = maxi(maximum, int(s.levels[other])); minimum = mini(minimum, int(s.levels[other]))
		if level > 0 and level == maximum and (level < 5 or int(stock.houses) >= 4): _choice(actions, "Sell building · +$%d" % (int(property.building_cost) / 2), "sell", {"property": id})
		if level > 0: _choice(actions, "Sell all buildings in set", "sell_group", {"property": id})
		if s.phase != "debt" and level < 5 and level == minimum and owns_set(seat, id) and ids.all(func(other: int) -> bool: return not s.mortgaged[other]) and int(s.cash[seat]) >= int(property.building_cost) and ((level < 4 and int(stock.houses) > 0) or (level == 4 and int(stock.hotels) > 0)):
			_choice(actions, "Build %s · $%d" % ["Hotel" if level == 4 else "House", int(property.building_cost)], "build", {"property": id})
	_choice(actions, "TRADE", "offer_trade")
	return actions


func apply(seat: int, input: Dictionary) -> bool:
	if s.is_empty() or not whole(input.get("revision"), 1) or int(input.revision) != int(s.revision) or not input.get("action") is String: return false
	var action: String = input.action
	var offered := legal_actions(seat)
	if not offered.any(func(choice: Dictionary) -> bool: return choice.payload.action == action): return false
	var allowed: Array = ["action", "revision"]
	if action in ["build", "sell", "sell_group", "mortgage", "unmortgage", "claim_building"] or (action == "bid" and s.auction.get("kind") == "building"): allowed.append("property")
	if action == "bid": allowed.append("amount")
	if action == "offer_trade": allowed.append_array(["to", "give_cash", "take_cash", "give_properties", "take_properties", "give_jail", "take_jail"])
	if not input.keys().all(func(key: Variant) -> bool: return key in allowed): return false
	if action in ["build", "sell", "sell_group", "mortgage", "unmortgage", "claim_building"]:
		if not whole(input.get("property"), 0, 39) or not offered.any(func(choice: Dictionary) -> bool: return choice.payload.action == action and int(choice.payload.property) == int(input.property)): return false
	if action == "bid" and (not whole(input.get("amount"), 1) or int(input.amount) < int(offered.filter(func(choice: Dictionary) -> bool: return choice.payload.action == "bid")[0].payload.amount) or int(input.amount) > int(s.cash[seat])): return false
	if action == "bid" and s.auction.get("kind") == "building" and input.has("property"):
		if not whole(input.property, 0, 39) or not s.auction.eligible[str(seat)].any(func(id: Variant) -> bool: return int(id) == int(input.property)): return false
	if action == "offer_trade" and not _valid_trade(seat, input): return false
	events.clear()
	match action:
		"roll": _roll(seat)
		"end": _end_turn()
		"buy":
			var id := int(s.buy_id); s.cash[seat] -= int(properties[id].price); s.owners[id] = seat; s.buy_id = -1; s.phase = "manage"; _note("buy", {"seat": seat, "property": id, "amount": properties[id].price}); _drain()
		"auction":
			var id := int(s.buy_id); s.buy_id = -1; _begin_auction(id)
		"bid", "pass_bid": _auction_action(seat, int(input.get("amount", 0)), action == "pass_bid", int(input.get("property", -1)))
		"claim_building", "decline_building": _building_interest(seat, int(input.get("property", -1)), action == "claim_building")
		"mortgage":
			var id := int(input.property); s.mortgaged[id] = true; s.cash[seat] += int(properties[id].mortgage); _note("mortgage", {"seat": seat, "property": id, "amount": properties[id].mortgage})
		"unmortgage":
			var id := int(input.property); s.cash[seat] -= _unmortgage_cost(id); s.mortgaged[id] = false; _note("unmortgage", {"seat": seat, "property": id})
		"build", "sell", "sell_group": _building(seat, int(input.property), action)
		"pay_debt":
			var debt: Dictionary = s.debt.duplicate(true); s.debt = {}; s.phase = "manage"; _pay(debt); _drain()
		"bankrupt": _bankrupt(seat); _drain()
		"pay_jail":
			_prepend([{"kind": "charge", "seat": seat, "target": -1, "amount": 50, "reason": "jail"}, {"kind": "release", "seat": seat}]); s.phase = "manage"; _drain()
		"use_jail_card":
			_return_jail_card(seat, str(s.held[seat][0])); s.jailed[seat] = -1; s.phase = "roll"; _note("release", {"seat": seat})
		"keep_mortgage", "redeem_transfer":
			var transfer: Dictionary = s.transfer.duplicate(true); var id: int = transfer.property; s.transfer = {}; s.phase = "manage"
			var tasks: Array = [{"kind": "charge", "seat": seat, "target": -1, "amount": _unmortgage_cost(id) if action == "redeem_transfer" else int(ceil(float(properties[id].mortgage) * .1)), "reason": "mortgage transfer"}]
			if action == "redeem_transfer": tasks.append({"kind": "unmortgage", "property": id, "seat": seat})
			_prepend(tasks); _drain()
		"offer_trade":
			var trade: Dictionary = input.duplicate(true); trade.erase("revision"); trade.erase("action"); trade.from = seat; trade.return_phase = s.phase; trade.ticket = _ticket(); s.trade = trade; s.phase = "trade"
		"accept_trade": _accept_trade(); _drain()
		"decline_trade", "cancel_trade":
			_note("trade_declined", {"seat": int(s.trade.from), "target": int(s.trade.to)}); s.phase = s.trade.return_phase; s.trade = {}
	s.revision += 1
	return true


func _ticket() -> int:
	s.decision_serial += 1
	return int(s.decision_serial)


func _prepend(tasks: Array) -> void:
	for index in range(tasks.size() - 1, -1, -1):
		var task: Dictionary = tasks[index].duplicate(true)
		if not task.has("ticket"): task.ticket = _ticket()
		s.queue.push_front(task)


func _unmortgage_cost(id: int) -> int:
	return (int(properties[id].mortgage) * 11 + 9) / 10


func _roll(seat: int) -> void:
	_roll_values(seat, rng.randi_range(1, 6), rng.randi_range(1, 6))


# Only tests call this helper; transport never accepts supplied dice.
func _roll_values(seat: int, first: int, second: int) -> void:
	s.dice = [first, second]; _note("roll", {"seat": seat, "dice": s.dice.duplicate()})
	var double := first == second
	if int(s.jailed[seat]) >= 0:
		s.extra_roll = false
		if double:
			s.jailed[seat] = -1; _move(seat, (int(s.positions[seat]) + first + second) % 40, true); s.phase = "manage"; _drain()
		else:
			s.jailed[seat] += 1; s.phase = "manage"
			if int(s.jailed[seat]) >= 3:
				_prepend([{"kind": "charge", "seat": seat, "target": -1, "amount": 50, "reason": "jail"}, {"kind": "jail_move", "seat": seat, "steps": first + second}]); _drain()
		return
	s.doubles = int(s.doubles) + 1 if double else 0
	s.extra_roll = double
	if int(s.doubles) == 3: _send_to_jail(seat); return
	s.phase = "manage"; _move(seat, (int(s.positions[seat]) + first + second) % 40, true); _drain()


func _move(seat: int, destination: int, collect_go: bool, backwards := false, multiplier := 1, special_utility := false) -> void:
	var origin: int = s.positions[seat]
	if collect_go and not backwards and destination <= origin:
		s.cash[seat] += 200; _note("go", {"seat": seat, "amount": 200})
	s.positions[seat] = destination
	_note("move", {"seat": seat, "from": origin, "to": destination, "backwards": backwards})
	_prepend([{"kind": "land", "seat": seat, "multiplier": multiplier, "special_utility": special_utility}])


func _land(task: Dictionary) -> void:
	var seat: int = task.seat; var index: int = s.positions[seat]; var space: Dictionary = definition.board[index]
	match str(space.kind):
		"property":
			var owner: int = s.owners[index]
			if owner < 0:
				s.buy_id = index; s.phase = "buy"; return
			if owner == seat or s.mortgaged[index]: return
			var total := int(s.dice[0]) + int(s.dice[1])
			if task.get("special_utility", false): total = rng.randi_range(1, 6) + rng.randi_range(1, 6)
			_prepend([{"kind": "charge", "seat": seat, "target": owner, "amount": rent(index, total, int(task.get("multiplier", 1)), bool(task.get("special_utility", false))), "reason": "rent", "property": index}])
		"tax": _prepend([{"kind": "charge", "seat": seat, "target": -1, "amount": int(space.amount), "reason": str(space.name)}])
		"chance", "community": _draw_card(str(space.kind), seat)
		"go_to_jail": _send_to_jail(seat)


func _draw_card(deck: String, seat: int) -> void:
	var index: int = s.decks[deck].pop_front()
	var card: Dictionary = definition[deck][index].duplicate(true)
	s.last_card = card; _note("card", {"seat": seat, "card": card.duplicate(true)})
	if card.effect != "jail_free": s.decks[deck].append(index)
	match str(card.effect):
		"move": _move(seat, int(card.destination), true)
		"back": _move(seat, posmod(int(s.positions[seat]) - int(card.amount), 40), false, true)
		"railroad", "utility":
			var locations: Array = [5, 15, 25, 35] if card.effect == "railroad" else [12, 28]
			var destination: int = locations[0]
			for candidate in locations:
				if int(candidate) > int(s.positions[seat]): destination = int(candidate); break
			_move(seat, destination, true, false, 2 if card.effect == "railroad" else 1, card.effect == "utility")
		"receive": s.cash[seat] += int(card.amount); _note("receive", {"seat": seat, "amount": int(card.amount)})
		"pay": _prepend([{"kind": "charge", "seat": seat, "target": -1, "amount": int(card.amount), "reason": str(card.name)}])
		"pay_each", "receive_each":
			var tasks: Array = []
			for other in int(s.count):
				if other != seat and not s.bankrupt[other]: tasks.append({"kind": "charge", "seat": seat if card.effect == "pay_each" else other, "target": other if card.effect == "pay_each" else seat, "amount": int(card.amount), "reason": str(card.name)})
			_prepend(tasks)
		"repairs":
			var amount := 0
			for id in properties:
				if int(s.owners[id]) == seat: amount += int(card.hotel) if int(s.levels[id]) == 5 else int(s.levels[id]) * int(card.house)
			_prepend([{"kind": "charge", "seat": seat, "target": -1, "amount": amount, "reason": str(card.name)}])
		"jail": _send_to_jail(seat)
		"jail_free": s.held[seat].append(deck)


func _send_to_jail(seat: int) -> void:
	var origin: int = s.positions[seat]
	s.positions[seat] = 10; s.jailed[seat] = 0; s.doubles = 0; s.extra_roll = false; s.phase = "manage"
	_note("jail", {"seat": seat, "from": origin, "to": 10})


func _drain() -> void:
	while not s.queue.is_empty() and not s.phase in ["buy", "auction", "debt", "transfer", "trade", "building_interest", "finished"]:
		var task: Dictionary = s.queue.pop_front()
		var seat := int(task.get("seat", -1))
		if seat >= 0 and s.bankrupt[seat]: continue
		match str(task.kind):
			"land": _land(task)
			"charge":
				if int(task.amount) <= 0: continue
				if int(s.cash[seat]) >= int(task.amount): _pay(task)
				else: s.debt = task; s.phase = "debt"
			"release": s.jailed[seat] = -1; s.phase = "roll"
			"jail_move": s.jailed[seat] = -1; _move(seat, (int(s.positions[seat]) + int(task.steps)) % 40, true)
			"mortgage_transfer": s.transfer = task; s.phase = "transfer"
			"unmortgage":
				if int(s.owners[int(task.property)]) == seat: s.mortgaged[int(task.property)] = false
			"auction": _begin_auction(int(task.property))
			"restore_phase": s.phase = str(task.phase)
	if s.queue.is_empty() and not s.phase in ["debt", "transfer", "auction", "trade", "building_interest", "finished"]:
		var living := _living()
		if living.size() == 1: finish("bankruptcy")
		elif s.bankrupt[int(s.turn)]: _next_turn()


func _pay(task: Dictionary) -> void:
	var seat: int = task.seat; var amount: int = task.amount; var target := int(task.get("target", -1))
	s.cash[seat] -= amount
	if target >= 0 and not s.bankrupt[target]: s.cash[target] += amount
	_note("pay", {"seat": seat, "target": target, "amount": amount, "reason": task.get("reason", "Payment"), "property": task.get("property", -1)})


func _end_turn() -> void:
	if s.extra_roll and not s.bankrupt[int(s.turn)]: s.phase = "roll"; s.extra_roll = false
	else: _next_turn()


func _next_turn() -> void:
	for offset in range(1, int(s.count) + 1):
		var next := (int(s.turn) + offset) % int(s.count)
		if not s.bankrupt[next]:
			s.turn = next; s.turn_serial += 1; s.doubles = 0; s.extra_roll = false; s.phase = "jail" if int(s.jailed[next]) >= 0 else "roll"; _note("turn", {"seat": next}); return


func _begin_auction(id: int) -> void:
	s.auction = {"kind": "property", "property": id, "leader": -1, "amount": 0, "seat": int(s.turn), "passed": [], "ticket": _ticket(), "step": 0}
	if s.bankrupt[int(s.auction.seat)]: s.auction.seat = _living()[0]
	s.phase = "auction"; _note("auction", {"property": id})


func _auction_action(seat: int, amount: int, passed: bool, property := -1) -> void:
	if passed: s.auction.passed.append(seat)
	else:
		if s.auction.get("kind") == "building" and property >= 0: s.auction.selections[str(seat)] = property
		s.auction.leader = seat; s.auction.amount = amount; _note("bid", {"seat": seat, "property": int(s.auction.property), "amount": amount})
	s.auction.step += 1
	var available := _living().filter(func(candidate: int) -> bool: return not s.auction.passed.has(candidate) and candidate != int(s.auction.leader) and (s.auction.get("kind") != "building" or s.auction.eligible.has(str(candidate))))
	if available.is_empty(): _complete_auction(); return
	for offset in range(1, int(s.count) + 1):
		var next := (seat + offset) % int(s.count)
		if available.has(next): s.auction.seat = next; return


func _complete_auction() -> void:
	var auction: Dictionary = s.auction.duplicate(true)
	if int(auction.leader) >= 0:
		var seat: int = auction.leader; var id: int = auction.property
		s.cash[seat] -= int(auction.amount)
		if auction.get("kind") == "building":
			id = int(auction.selections[str(seat)]); s.levels[id] += 1; _note("build", {"seat": seat, "property": id})
		else: s.owners[id] = seat; _note("buy", {"seat": seat, "property": id, "amount": int(auction.amount)})
	s.auction = {}; s.phase = str(auction.get("return_phase", "manage")); _drain()


func _building(seat: int, id: int, action: String) -> void:
	var cost: int = properties[id].building_cost
	if action == "build":
		var kind := "hotel" if int(s.levels[id]) == 4 else "house"
		var available := buildings_available()
		var eligible := _building_eligible(kind)
		if int(available.hotels if kind == "hotel" else available.houses) == 1 and eligible.size() > 1:
			s.building_sale = {"kind": kind, "requester": seat, "property": id, "eligible": eligible, "interested": {str(seat): id}, "responded": [seat], "seat": seat, "ticket": _ticket(), "step": 0, "return_phase": s.phase}
			s.phase = "building_interest"; _note("building_sale", {"seat": seat, "property": id}); _next_building_response(); return
	if action == "sell_group":
		var amount := 0
		for other in group_ids(id): amount += int(s.levels[other]) * int(properties[other].building_cost) / 2; s.levels[other] = 0
		s.cash[seat] += amount
	else:
		s.levels[id] += 1 if action == "build" else -1
		s.cash[seat] += -cost if action == "build" else cost / 2
	_note(action, {"seat": seat, "property": id})


func _building_eligible(kind: String) -> Dictionary:
	var eligible: Dictionary = {}
	for id in properties:
		var seat := int(s.owners[id]); var level := int(s.levels[id])
		if seat < 0 or s.bankrupt[seat] or int(s.cash[seat]) < 10 or int(properties[id].building_cost) <= 0: continue
		if (kind == "hotel" and level != 4) or (kind == "house" and level >= 4): continue
		var ids := group_ids(id)
		if not owns_set(seat, id) or not ids.all(func(other: int) -> bool: return not s.mortgaged[other] and int(s.levels[other]) >= level): continue
		if not eligible.has(str(seat)): eligible[str(seat)] = []
		eligible[str(seat)].append(id)
	return eligible


func _building_interest(seat: int, id: int, interested: bool) -> void:
	if interested: s.building_sale.interested[str(seat)] = id
	s.building_sale.responded.append(seat); s.building_sale.step += 1
	_next_building_response()


func _next_building_response() -> void:
	var sale: Dictionary = s.building_sale
	for offset in range(1, int(s.count) + 1):
		var next := (int(sale.seat) + offset) % int(s.count)
		if sale.eligible.has(str(next)) and not sale.responded.has(next): s.building_sale.seat = next; return
	s.building_sale = {}
	if sale.interested.size() == 1:
		var seat := int(sale.requester); var id := int(sale.property)
		s.cash[seat] -= int(properties[id].building_cost); s.levels[id] += 1; s.phase = str(sale.return_phase); _note("build", {"seat": seat, "property": id}); return
	var eligible: Dictionary = {}
	for seat in sale.interested: eligible[seat] = sale.eligible[seat].duplicate()
	s.auction = {"kind": "building", "building": sale.kind, "eligible": eligible, "selections": sale.interested.duplicate(true), "property": int(sale.property), "leader": -1, "amount": 0, "seat": int(sale.requester), "passed": [], "ticket": _ticket(), "step": 0, "return_phase": str(sale.return_phase)}
	s.phase = "auction"


func _return_jail_card(seat: int, deck: String) -> void:
	s.held[seat].erase(deck)
	for index in definition[deck].size():
		if definition[deck][index].effect == "jail_free": s.decks[deck].append(index); return


func _bankrupt(seat: int) -> void:
	var target := int(s.debt.get("target", -1)); var tasks: Array = []
	for id in properties:
		if int(s.owners[id]) != seat: continue
		s.cash[seat] += int(s.levels[id]) * int(properties[id].building_cost) / 2; s.levels[id] = 0
		s.owners[id] = target
		if target < 0:
			s.mortgaged[id] = false; tasks.append({"kind": "auction", "property": id})
		elif s.mortgaged[id]: tasks.append({"kind": "mortgage_transfer", "seat": target, "property": id})
	if target >= 0:
		s.cash[target] += int(s.cash[seat])
		for deck in s.held[seat]: s.held[target].append(deck)
		s.held[seat] = []
	else:
		for deck in s.held[seat].duplicate(): _return_jail_card(seat, str(deck))
	s.cash[seat] = 0; s.bankrupt[seat] = true; s.debt = {}; s.phase = "manage"; s.extra_roll = false
	_note("bankrupt", {"seat": seat, "target": target})
	# No property auctions are needed after only one player survives.
	if _living().size() == 1: s.queue.clear(); finish("bankruptcy")
	else: _prepend(tasks)


func _property_list(value: Variant, owner: int) -> bool:
	if not value is Array or value.size() > 28: return false
	var seen: Array = []
	for id in value:
		if not whole(id, 0, 39) or not properties.has(int(id)) or int(s.owners[int(id)]) != owner or seen.has(int(id)): return false
		if not group_ids(int(id)).all(func(other: int) -> bool: return int(s.levels[other]) == 0): return false
		seen.append(int(id))
	return true


func _jail_list(value: Variant, owner: int) -> bool:
	if not value is Array or value.size() > 2: return false
	var seen: Array = []
	for deck in value:
		if not deck is String or not s.held[owner].has(deck) or seen.has(deck): return false
		seen.append(deck)
	return true


func _valid_trade(seat: int, input: Dictionary) -> bool:
	if not whole(input.get("to"), 0, int(s.count) - 1): return false
	var other := int(input.to)
	if other == seat or s.bankrupt[other]: return false
	if not whole(input.get("give_cash"), 0, int(s.cash[seat])) or not whole(input.get("take_cash"), 0, int(s.cash[other])): return false
	if not _property_list(input.get("give_properties"), seat) or not _property_list(input.get("take_properties"), other): return false
	if not _jail_list(input.get("give_jail"), seat) or not _jail_list(input.get("take_jail"), other): return false
	return int(input.give_cash) + int(input.take_cash) + input.give_properties.size() + input.take_properties.size() + input.give_jail.size() + input.take_jail.size() > 0


func _accept_trade() -> void:
	var trade: Dictionary = s.trade.duplicate(true); var from: int = trade.from; var to: int = trade.to
	s.trade = {}; s.phase = "manage"
	s.cash[from] += int(trade.take_cash) - int(trade.give_cash); s.cash[to] += int(trade.give_cash) - int(trade.take_cash)
	var tasks: Array = []
	for pair in [[trade.give_properties, to], [trade.take_properties, from]]:
		for value in pair[0]:
			var id := int(value); s.owners[id] = int(pair[1])
			if s.mortgaged[id]: tasks.append({"kind": "mortgage_transfer", "seat": int(pair[1]), "property": id})
	for deck in trade.give_jail: s.held[from].erase(deck); s.held[to].append(deck)
	for deck in trade.take_jail: s.held[to].erase(deck); s.held[from].append(deck)
	if not s.debt.is_empty(): tasks.append(s.debt.duplicate(true)); s.debt = {}
	elif trade.return_phase == "buy": tasks.append({"kind": "land", "seat": int(s.turn)})
	else: tasks.append({"kind": "restore_phase", "phase": str(trade.return_phase)})
	_prepend(tasks); _note("trade", {"seat": from, "target": to, "give_properties":trade.give_properties.duplicate(), "take_properties":trade.take_properties.duplicate(), "give_jail":trade.give_jail.duplicate(), "take_jail":trade.take_jail.duplicate(), "give_cash":int(trade.give_cash), "take_cash":int(trade.take_cash)})


func _living() -> Array:
	return range(int(s.count)).filter(func(seat: int) -> bool: return not s.bankrupt[seat])


func finish(reason: String) -> void:
	if s.is_empty() or s.phase == "finished": return
	# A bid already made is binding. Closing it at the game deadline does not
	# invent a player choice or invoke a computer player.
	if not s.auction.is_empty() and int(s.auction.leader) >= 0:
		var buyer := int(s.auction.leader); var id := int(s.auction.property)
		s.cash[buyer] -= int(s.auction.amount)
		if s.auction.get("kind") == "building":
			id = int(s.auction.selections[str(buyer)]); s.levels[id] += 1; _note("build", {"seat": buyer, "property": id})
		else: s.owners[id] = buyer; _note("buy", {"seat": buyer, "property": id, "amount": int(s.auction.amount)})
	var totals: Array = []
	for seat in int(s.count): totals.append(wealth(seat))
	# At a timed cutoff, account for already-incurred, unresolved obligations.
	var obligations: Array = s.queue.filter(func(task: Dictionary) -> bool: return task.kind == "charge").duplicate(true)
	if not s.debt.is_empty(): obligations.push_front(s.debt.duplicate(true))
	var mortgages: Array = s.queue.filter(func(task: Dictionary) -> bool: return task.kind == "mortgage_transfer").duplicate(true)
	if not s.transfer.is_empty(): mortgages.append(s.transfer)
	for transfer in mortgages: obligations.append({"seat": int(transfer.seat), "target": -1, "amount": (int(properties[int(transfer.property)].mortgage) + 9) / 10})
	for debt in obligations:
		var seat := int(debt.seat); var target := int(debt.get("target", -1))
		if s.bankrupt[seat]: continue
		var amount := mini(maxi(0, int(totals[seat])), int(debt.amount)); totals[seat] -= int(debt.amount)
		if target >= 0 and not s.bankrupt[target]: totals[target] += amount
	var candidates := _living()
	var highest: int = totals[candidates[0]]
	for seat in candidates: highest = maxi(highest, int(totals[seat]))
	candidates = candidates.filter(func(seat: int) -> bool: return int(totals[seat]) == highest)
	var cash := 0
	for seat in candidates: cash = maxi(cash, int(s.cash[seat]))
	candidates = candidates.filter(func(seat: int) -> bool: return int(s.cash[seat]) == cash)
	s.tie_rolls = []
	while candidates.size() > 1:
		var rolls: Array = []; var best := 0
		for seat in candidates:
			var value := rng.randi_range(1, 6) + rng.randi_range(1, 6); rolls.append({"seat": seat, "roll": value}); best = maxi(best, value)
		s.tie_rolls.append(rolls)
		candidates = rolls.filter(func(roll: Dictionary) -> bool: return int(roll.roll) == best).map(func(roll: Dictionary) -> int: return int(roll.seat))
	s.winner = int(candidates[0]); s.result_wealth = totals; s.phase = "finished"; s.finish_reason = reason; s.trade = {}; s.queue = []; s.debt = {}; s.transfer = {}; s.auction = {}; s.building_sale = {}; s.revision += 1
	_note("win", {"seat": int(s.winner), "amount": int(totals[int(s.winner)]), "reason": reason})


func _note(kind: String, values: Dictionary) -> void:
	s.sequence += 1
	var event := values.duplicate(true); event.kind = kind; event.id = int(s.sequence)
	# Public balance checkpoints are transient presentation data, never save rules.
	var visual := event.duplicate(true); visual.balances = s.cash.duplicate()
	events.append(visual); s.log.push_front(event.duplicate(true))
	if s.log.size() > 100: s.log.resize(100)


func export_state() -> Dictionary:
	var result := s.duplicate(true); result.rng_state = str(rng.state)
	return result


func view_for(viewer: int) -> Dictionary:
	if s.is_empty(): return {"phase": "setup", "viewer": viewer, "revision": 0, "players": [], "properties": [], "actions": []}
	var players: Array = []
	for seat in int(s.count):
		players.append({"seat": seat, "cash": int(s.cash[seat]), "wealth": int(s.result_wealth[seat]) if s.phase == "finished" else wealth(seat), "bankrupt": bool(s.bankrupt[seat]), "jailed": int(s.jailed[seat]), "jail_cards": s.held[seat].size(), "jail_decks": s.held[seat].duplicate()})
	var portfolio: Array = []
	for id in properties:
		var item: Dictionary = properties[id].duplicate(true)
		item.owner = int(s.owners[id]); item.buildings = int(s.levels[id]); item.mortgaged = bool(s.mortgaged[id]); item.rent = rent(id, int(s.dice[0]) + int(s.dice[1]))
		item.rent_level = item.buildings
		if item.group in ["railroad", "utility"]: item.rent_level = group_ids(id).filter(func(other: int) -> bool: return int(s.owners[other]) == int(item.owner)).size() - 1
		portfolio.append(item)
	var trade: Dictionary = {}
	if not s.trade.is_empty():
		trade = s.trade.duplicate(true) if viewer in [int(s.trade.from), int(s.trade.to)] else {"from": int(s.trade.from), "to": int(s.trade.to)}
	return {"phase": str(s.phase), "viewer": viewer, "revision": int(s.revision), "turn": int(s.turn), "actor": actor(), "turn_serial": int(s.turn_serial), "decision_key": decision_key(), "players": players, "properties": portfolio, "actions": legal_actions(viewer), "debt": s.debt.duplicate(true), "auction": s.auction.duplicate(true), "transfer": s.transfer.duplicate(true), "trade": trade, "held": s.held[viewer].duplicate() if viewer >= 0 and viewer < int(s.count) else [], "buy_id": int(s.buy_id), "dice": s.dice.duplicate(), "last_card": s.last_card.duplicate(true), "winner": int(s.winner), "finish_reason": str(s.finish_reason), "tie_rolls": s.tie_rolls.duplicate(true), "stock": buildings_available(), "log": s.log.duplicate(true)}


func import_state(value: Dictionary) -> bool:
	if not _valid_saved_state(value): return false
	s = value.duplicate(true); s.erase("rng_state")
	# JSON numbers arrive as floats. All rule operations explicitly normalize.
	rng.state = int(str(value.rng_state)); events.clear()
	return true


func _valid_saved_state(value: Dictionary) -> bool:
	if not whole(value.get("count"), 2, 6) or not whole(value.get("revision"), 1) or not value.get("rng_state") is String or not value.rng_state.is_valid_int(): return false
	var count := int(value.count)
	for field in ["cash", "positions", "jailed", "bankrupt", "held"]:
		if not value.get(field) is Array or value[field].size() != count: return false
	for seat in count:
		if not whole(value.cash[seat]) or not whole(value.positions[seat], 0, 39) or not whole(value.jailed[seat], -1, 3) or not value.bankrupt[seat] is bool or not value.held[seat] is Array: return false
	for field in ["owners", "levels", "mortgaged"]:
		if not value.get(field) is Array or value[field].size() != 40: return false
	for index in 40:
		if not whole(value.owners[index], -1, count - 1) or not whole(value.levels[index], 0, 5) or not value.mortgaged[index] is bool: return false
		if not properties.has(index) and (int(value.owners[index]) != -1 or int(value.levels[index]) != 0 or value.mortgaged[index]): return false
		if properties.has(index) and ((int(value.levels[index]) > 0 and (int(value.owners[index]) < 0 or value.mortgaged[index] or int(properties[index].building_cost) == 0)) or (value.mortgaged[index] and int(value.owners[index]) < 0)): return false
		if int(value.owners[index]) >= 0 and value.bankrupt[int(value.owners[index])]: return false
	var houses := 0; var hotels := 0
	for id in properties:
		var level := int(value.levels[id])
		if level == 5: hotels += 1
		else: houses += level
		if level > 0:
			var low := 5; var high := 0
			for other in group_ids(id):
				if int(value.owners[other]) != int(value.owners[id]) or value.mortgaged[other]: return false
				low = mini(low, int(value.levels[other])); high = maxi(high, int(value.levels[other]))
			if high - low > 1: return false
	if houses > 32 or hotels > 12: return false
	if not value.get("phase") in ["roll", "jail", "buy", "manage", "auction", "debt", "transfer", "trade", "building_interest", "finished"]: return false
	if not whole(value.get("turn"), 0, count - 1) or not whole(value.get("starter"), 0, count - 1) or not whole(value.get("turn_serial"), 1) or not whole(value.get("decision_serial")) or not whole(value.get("doubles"), 0, 3) or not value.get("extra_roll") is bool: return false
	if not value.get("dice") is Array or value.dice.size() != 2 or not value.dice.all(func(die: Variant) -> bool: return whole(die, 1, 6)): return false
	for field in ["debt", "transfer", "trade", "auction", "building_sale", "last_card", "decks"]:
		if not value.get(field) is Dictionary: return false
	for field in ["queue", "log", "result_wealth", "tie_rolls"]:
		if not value.get(field) is Array or value[field].size() > 200: return false
	if not whole(value.get("buy_id"), -1, 39) or not whole(value.get("winner"), -1, count - 1) or not whole(value.get("sequence")) or not value.get("finish_reason") is String: return false
	if value.phase == "buy" and (not properties.has(int(value.buy_id)) or int(value.owners[int(value.buy_id)]) >= 0): return false
	if value.phase == "finished" and (not whole(value.winner, 0, count - 1) or value.bankrupt[int(value.winner)] or value.result_wealth.size() != count or not value.result_wealth.all(func(amount: Variant) -> bool: return whole(amount, -100000000))): return false
	if value.phase != "finished" and int(value.winner) != -1: return false
	if value.phase == "debt" and (not _valid_task(value.debt, count) or value.debt.kind != "charge" or value.bankrupt[int(value.debt.seat)]): return false
	if value.phase == "transfer" and (not _valid_task(value.transfer, count) or value.transfer.kind != "mortgage_transfer" or int(value.owners[int(value.transfer.property)]) != int(value.transfer.seat) or not value.mortgaged[int(value.transfer.property)]): return false
	for task in value.queue:
		if not _valid_task(task, count): return false
	if value.phase == "auction":
		var auction: Dictionary = value.auction
		if not whole(auction.get("property"), 0, 39) or not properties.has(int(auction.property)): return false
		if auction.get("kind", "property") == "building":
			if not _valid_saved_builders(value, auction.get("eligible"), str(auction.get("building", "")), count) or not auction.get("selections") is Dictionary or not auction.get("return_phase") in ["roll", "jail", "buy", "manage"]: return false
			if auction.selections.size() != auction.eligible.size(): return false
			for seat in auction.selections:
				if not auction.eligible.has(seat) or not whole(auction.selections[seat], 0, 39) or not auction.eligible[seat].any(func(id: Variant) -> bool: return int(id) == int(auction.selections[seat])): return false
		else:
			if auction.get("kind", "property") != "property" or int(value.owners[int(auction.property)]) != -1: return false
		if not whole(auction.get("leader"), -1, count - 1) or not whole(auction.get("seat"), 0, count - 1) or not whole(auction.get("amount")) or not whole(auction.get("ticket"), 1, int(value.decision_serial)) or not whole(auction.get("step")) or not auction.get("passed") is Array: return false
		var seen_bidders: Array = []
		for bidder in auction.passed:
			if not whole(bidder, 0, count - 1) or seen_bidders.has(int(bidder)): return false
			seen_bidders.append(int(bidder))
		if value.bankrupt[int(auction.seat)] or seen_bidders.has(int(auction.seat)) or int(auction.seat) == int(auction.leader): return false
		if int(auction.leader) >= 0 and (value.bankrupt[int(auction.leader)] or int(auction.amount) > int(value.cash[int(auction.leader)])): return false
		if auction.get("kind") == "building" and (not auction.eligible.has(str(int(auction.seat))) or (int(auction.leader) >= 0 and not auction.eligible.has(str(int(auction.leader))))): return false
	if value.phase == "building_interest":
		var sale: Dictionary = value.building_sale
		if not _valid_saved_builders(value, sale.get("eligible"), str(sale.get("kind", "")), count) or not sale.get("interested") is Dictionary or not sale.get("responded") is Array: return false
		if not whole(sale.get("seat"), 0, count - 1) or not whole(sale.get("requester"), 0, count - 1) or not whole(sale.get("property"), 0, 39) or not whole(sale.get("ticket"), 1, int(value.decision_serial)) or not whole(sale.get("step")) or not sale.get("return_phase") in ["roll", "jail", "buy", "manage"]: return false
		if not sale.eligible.has(str(int(sale.seat))) or sale.responded.has(int(sale.seat)) or not sale.interested.has(str(int(sale.requester))): return false
		for key in sale.interested:
			if not sale.eligible.has(key) or not whole(sale.interested[key], 0, 39) or not sale.eligible[key].any(func(id: Variant) -> bool: return int(id) == int(sale.interested[key])): return false
	if value.phase == "trade":
		var trade: Dictionary = value.trade
		if not whole(trade.get("from"), 0, count - 1) or not whole(trade.get("ticket"), 1, int(value.decision_serial)) or not trade.get("return_phase") in ["roll", "jail", "buy", "manage", "debt"]: return false
		var prior: Dictionary = s; s = value
		var valid := _valid_trade(int(trade.from), trade)
		s = prior
		if not valid: return false
		if trade.return_phase == "debt" and (not _valid_task(value.debt, count) or int(value.debt.seat) != int(trade.from)): return false
	for deck in ["chance", "community"]:
		if not value.decks.get(deck) is Array: return false
		var seen: Array = []
		for id in value.decks[deck]:
			if not whole(id, 0, 15) or seen.has(int(id)): return false
			seen.append(int(id))
		var held_count := 0
		for held in value.held:
			if held.size() > 2 or not held.all(func(item: Variant) -> bool: return item in ["chance", "community"]) or held.count(deck) > 1: return false
			held_count += held.count(deck)
		if seen.size() + held_count != 16 or held_count > 1: return false
		for index in 16:
			var held_card: bool = definition[deck][index].effect == "jail_free" and held_count == 1
			if seen.has(index) == held_card: return false
	for event in value.log:
		if not _valid_event(event, count): return false
	return true


func _valid_task(task: Variant, count: int) -> bool:
	if not task is Dictionary or not task.get("kind") is String or not whole(task.get("ticket"), 1): return false
	if task.kind == "restore_phase": return task.get("phase") in ["roll", "jail", "manage"]
	if task.kind == "auction": return whole(task.get("property"), 0, 39) and properties.has(int(task.property))
	if not whole(task.get("seat"), 0, count - 1): return false
	match str(task.kind):
		"land": return whole(task.get("multiplier", 1), 1, 2) and task.get("special_utility", false) is bool
		"charge": return whole(task.get("amount")) and whole(task.get("target"), -1, count - 1) and task.get("reason") is String
		"release": return true
		"jail_move": return whole(task.get("steps"), 2, 12)
		"mortgage_transfer", "unmortgage": return whole(task.get("property"), 0, 39) and properties.has(int(task.property))
	return false


func _valid_saved_builders(value: Dictionary, supplied: Variant, kind: String, count: int) -> bool:
	if not kind in ["house", "hotel"] or not supplied is Dictionary or supplied.size() < 2 or supplied.size() > count: return false
	var prior: Dictionary = s; s = value
	var allowed := _building_eligible(kind)
	s = prior
	for key in supplied:
		if not key is String or not allowed.has(key) or not supplied[key] is Array or supplied[key].is_empty(): return false
		var seen: Array = []
		for id in supplied[key]:
			if not whole(id, 0, 39) or seen.has(int(id)) or not allowed[key].has(int(id)): return false
			seen.append(int(id))
	return true


func _valid_event(event: Variant, count: int) -> bool:
	if not event is Dictionary or not event.get("kind") is String or not whole(event.get("id"), 1): return false
	if event.kind == "auction": return whole(event.get("property"), 0, 39) and properties.has(int(event.property))
	if not whole(event.get("seat"), 0, count - 1): return false
	match str(event.kind):
		"start", "turn", "release": return true
		"roll": return event.get("dice") is Array and event.dice.size() == 2 and event.dice.all(func(value: Variant) -> bool: return whole(value, 1, 6))
		"move", "jail": return whole(event.get("from"), 0, 39) and whole(event.get("to"), 0, 39)
		"buy", "bid": return whole(event.get("property"), 0, 39) and properties.has(int(event.property)) and whole(event.get("amount"))
		"mortgage", "unmortgage", "build", "sell", "sell_group", "building_sale": return whole(event.get("property"), 0, 39) and properties.has(int(event.property))
		"receive", "go", "win": return whole(event.get("amount"), -100000000)
		"pay": return whole(event.get("amount")) and whole(event.get("target"), -1, count - 1) and whole(event.get("property", -1), -1, 39) and event.get("reason") is String
		"trade", "trade_declined", "bankrupt": return whole(event.get("target"), -1, count - 1)
		"card": return event.get("card") is Dictionary and event.card.get("key") is String and event.card.get("name") is String
	return false
