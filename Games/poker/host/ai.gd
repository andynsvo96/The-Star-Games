extends RefCounted

const Evaluator = preload("res://Games/poker/host/evaluator.gd")


# Deliberately accepts the same own-hand/public-table view as a phone. Sampling
# excludes known cards only; real opponents' cards and the real deck are absent.
static func choose(view: Dictionary, difficulty := 1) -> Dictionary:
	if view.get("phase") != "betting" or int(view.get("viewer", -1)) != int(view.get("turn", -2)): return {}
	var legal: Dictionary = view.legal
	var rng := RandomNumberGenerator.new(); rng.seed = int(view.revision) * 971 + int(view.turn_serial) * 1009 + int(view.viewer) * 37
	var unknown := range(52)
	for card in view.hand + view.board: unknown.erase(int(card))
	var opponents := 0
	for index in view.players.size():
		if index != int(view.viewer) and not view.players[index].out and not view.players[index].folded: opponents += 1
	var samples: int = [10, 28, 64][clampi(difficulty, 0, 2)]
	var equity := 0.0
	for sample in samples:
		var pool := unknown.duplicate()
		# Shuffle just the prefix needed by this simulation.
		var needed: int = 5 - view.board.size() + opponents * (4 if view.variant == "omaha" else 2)
		for index in needed:
			var other := rng.randi_range(index, pool.size() - 1); var held: int = pool[index]; pool[index] = pool[other]; pool[other] = held
		var community: Array = view.board.duplicate(); var cursor := 0
		while community.size() < 5: community.append(pool[cursor]); cursor += 1
		var mine: Dictionary = Evaluator.best(view.hand, community, view.variant)
		var beaten := false; var ties := 1
		for opponent in opponents:
			var hand: Array = []
			for index in (4 if view.variant == "omaha" else 2): hand.append(pool[cursor]); cursor += 1
			var other: Dictionary = Evaluator.best(hand, community, view.variant)
			if int(other.score) > int(mine.score): beaten = true; break
			if int(other.score) == int(mine.score): ties += 1
		if not beaten: equity += 1.0 / ties
	equity /= samples
	equity = clampf(equity + rng.randf_range(-.22, .22) if difficulty == 0 else equity + rng.randf_range(-.05, .05) if difficulty == 1 else equity, 0, 1)
	var call := maxi(0, int(legal.call))
	var odds := float(call) / maxf(1, float(view.pot) + call)
	var edge := equity - 1.0 / (opponents + 1)
	if legal.can_raise and (edge > .17 or (legal.check and rng.randf() < .08)):
		var desired := int(view.current_bet) + maxi(int(view.big_blind), roundi((float(view.pot) + call) * (.5 if edge < .4 else 1.0)))
		return {"action": "raise", "amount": clampi(desired, int(legal.min_raise_to), int(legal.max_raise_to))}
	if legal.check: return {"action": "check"}
	if equity + .035 < odds: return {"action": "fold"}
	return {"action": "call"}
