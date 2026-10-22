extends RefCounted

# Input is the same own-seat/public view sent to a phone, never deck order or
# future dice. Difficulty zero is also the deliberately random timeout player.
static func choose(view: Dictionary, difficulty: int, rng: RandomNumberGenerator) -> Dictionary:
	var choices: Array = view.get("actions", []).filter(func(choice: Dictionary) -> bool: return choice.payload.action != "offer_trade")
	if choices.is_empty(): return {}
	var actor := int(view.viewer)
	var player: Dictionary = view.players[actor]
	if difficulty == 0:
		var required: Array = choices.filter(func(choice: Dictionary) -> bool: return not choice.payload.action in ["unmortgage", "build", "mortgage", "sell", "sell_group"])
		if view.phase == "debt": required = choices.filter(func(choice: Dictionary) -> bool: return choice.payload.action in ["pay_debt", "bankrupt", "mortgage", "sell_group", "sell"])
		if not required.is_empty(): choices = required
		var result: Dictionary = choices[rng.randi_range(0, choices.size() - 1)].payload.duplicate(true)
		if result.action == "bid": result.amount = mini(int(player.cash), int(result.amount) + rng.randi_range(0, 12))
		return result
	if view.phase == "building_interest":
		var request := _find(choices, "claim_building")
		if not request.is_empty() and int(player.cash) > int(_property(view, int(request.property)).building_cost) + 150: return request
		return _find(choices, "decline_building")
	for action in ["pay_debt", "bankrupt", "use_jail_card"]:
		var found := _find(choices, action)
		if not found.is_empty(): return found
	if view.phase == "debt":
		var mortgages: Array = choices.filter(func(choice: Dictionary) -> bool: return choice.payload.action == "mortgage")
		mortgages.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _value(view, int(a.payload.property), actor) < _value(view, int(b.payload.property), actor))
		if not mortgages.is_empty(): return mortgages[0].payload.duplicate(true)
		for action in ["sell", "sell_group"]:
			var found := _find(choices, action)
			if not found.is_empty(): return found
	if view.phase == "trade":
		var trade: Dictionary = view.trade
		var gain := int(trade.get("give_cash", 0)) - int(trade.get("take_cash", 0))
		for id in trade.get("give_properties", []): gain += _value(view, int(id), actor)
		for id in trade.get("take_properties", []): gain -= _value(view, int(id), actor)
		gain += (trade.get("give_jail", []).size() - trade.get("take_jail", []).size()) * 35
		return _find(choices, "accept_trade" if gain >= 0 else "decline_trade")
	if view.phase == "buy":
		var property: Dictionary = _property(view, int(view.buy_id))
		if int(player.cash) - int(property.price) >= (60 if difficulty == 1 else 140) or _value(view, int(view.buy_id), actor) > int(property.price) * 1.3:
			var buy := _find(choices, "buy")
			if not buy.is_empty(): return buy
		return _find(choices, "auction")
	if view.phase == "auction":
		var bid := _find(choices, "bid")
		if not bid.is_empty():
			var ceiling := mini(int(player.cash) - (80 if difficulty == 1 else 150), int(_value(view, int(view.auction.property), actor) * (1.0 if difficulty == 1 else 1.15)))
			if view.auction.get("kind") == "building": ceiling = mini(int(player.cash) - 150, int(_property(view, int(bid.property)).building_cost) * 2)
			if int(bid.amount) <= ceiling: bid.amount = mini(ceiling, int(bid.amount) + rng.randi_range(0, 12)); return bid
		return _find(choices, "pass_bid")
	if view.phase == "transfer":
		var property: Dictionary = _property(view, int(view.transfer.property))
		return _find(choices, "redeem_transfer" if int(player.cash) > int(property.mortgage) * 1.1 + 180 else "keep_mortgage")
	if view.phase == "jail" and int(player.cash) > 250 and int(player.jailed) < 2: return _find(choices, "pay_jail")
	if view.phase in ["manage", "roll", "jail"]:
		var reserve := 160 if difficulty == 1 else 260
		for choice in choices:
			if choice.payload.action == "build":
				var property: Dictionary = _property(view, int(choice.payload.property))
				if int(player.cash) - int(property.building_cost) >= reserve: return choice.payload.duplicate(true)
			if choice.payload.action == "unmortgage":
				var property: Dictionary = _property(view, int(choice.payload.property))
				if int(player.cash) - int(property.mortgage) * 1.1 >= reserve + 100: return choice.payload.duplicate(true)
	for action in ["roll", "end", "pay_jail", "keep_mortgage", "pass_bid", "decline_trade"]:
		var found := _find(choices, action)
		if not found.is_empty(): return found
	return choices[0].payload.duplicate(true)


static func offer(view: Dictionary) -> Dictionary:
	var seat := int(view.viewer)
	for property in view.properties:
		if int(property.owner) < 0 or int(property.owner) == seat or property.mortgaged or int(property.buildings) > 0: continue
		var group: Array = view.properties.filter(func(item: Dictionary) -> bool: return item.group == property.group)
		if group.any(func(item: Dictionary) -> bool: return int(item.buildings) > 0): continue
		var ours := group.filter(func(item: Dictionary) -> bool: return int(item.owner) == seat).size()
		if ours == 0: continue
		var amount := int(property.price) * 3 / 2
		if int(view.players[seat].cash) < amount + 200: continue
		return {"action": "offer_trade", "to": int(property.owner), "give_cash": amount, "take_cash": 0, "give_properties": [], "take_properties": [int(property.id)], "give_jail": [], "take_jail": []}
	return {}


static func _property(view: Dictionary, id: int) -> Dictionary:
	for item in view.properties:
		if int(item.id) == id: return item
	return {}


static func _value(view: Dictionary, id: int, owner: int) -> int:
	var property := _property(view, id)
	if property.is_empty(): return 0
	var matches := 0
	for item in view.properties:
		if item.group == property.group and int(item.owner) == owner: matches += 1
	var value := int(property.price) * (1.0 + matches * .4)
	return int(value) - (int(property.mortgage) if property.mortgaged else 0)


static func _find(choices: Array, action: String) -> Dictionary:
	for choice in choices:
		if choice.payload.action == action: return choice.payload.duplicate(true)
	return {}
