extends RefCounted

# Only the same private view that a human controller receives is accepted.
static func choose(view: Dictionary, difficulty := 1) -> Dictionary:
	var seat := int(view.viewer)
	if view.has("payment"):
		var candidates: Array = []
		var public: Dictionary = view.table[seat]
		for card in public.bank: candidates.append({"id": card.id, "value": card.value, "cost": card.value})
		for card in public.loose: candidates.append({"id": card.id, "value": card.value, "cost": card.value + 3})
		for group in public.groups:
			for card in group.cards + group.buildings:
				if card.value > 0: candidates.append({"id": card.id, "value": card.value, "cost": card.value + (18 if group.complete else 8)})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.cost < b.cost)
		var chosen: Array = []
		var total := 0
		for card in candidates:
			if total >= int(view.payment.amount): break
			chosen.append(card.id); total += int(card.value)
		var command: Dictionary = view.payment.get("command", {"action": "pay"}).duplicate(true); command.cards = chosen; return command
	var actions: Array = view.actions
	if actions.is_empty(): return {}
	if view.phase == "response":
		for choice in actions:
			if choice.payload.action == "no" and difficulty > 0: return choice.payload.duplicate(true)
		return actions[0].payload.duplicate(true)
	var ranked: Array = []
	for choice in actions:
		var command: Dictionary = choice.payload
		var score := 0.0
		match command.action:
			"end": score = -100 if view.plays_left > 0 else 0
			"go": score = 20
			"property":
				score = 30
				for group in view.table[seat].groups:
					if group.id == command.group: score += 15 + (80 if group.cards.size() + 1 >= int(view.colors[group.color].size) else 0)
			"deal-breaker": score = 130
			"sly-deal", "forced-deal": score = 55
			"rent", "debt", "birthday": score = 22
			"building": score = 18
			"move-building": score = 18 if view.table[seat].loose.any(func(card: Dictionary) -> bool: return card.id == command.card) else -200
			"move":
				score = -200
				var source_complete: bool = view.table[seat].groups.any(func(group: Dictionary) -> bool: return group.complete and group.cards.any(func(card: Dictionary) -> bool: return card.id == command.card))
				for group in view.table[seat].groups:
					if not source_complete and group.id == command.group and group.cards.size() + 1 == int(view.colors[group.color].size): score = 100
			"bank":
				var held: Array = view.hand.filter(func(card: Dictionary) -> bool: return card.id == command.card)
				# Keep action cards circulating. Banking every unplayable action can
				# exhaust all theft/rent cards and leave a permanently split table.
				score = (15 if view.table[seat].total < 5 else -10) if not held.is_empty() and held[0].kind == "money" else -500
			"discard": score = 1
		if difficulty == 0: score += randf_range(-60, 60)
		elif difficulty == 1: score += randf_range(-7, 7)
		ranked.append({"score": score, "payload": command})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	return ranked[0].payload.duplicate(true)
