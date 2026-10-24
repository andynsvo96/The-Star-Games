extends GameDebugAdapter

# Working finite sample: every test player submits once through the validated
# host handler. Replace with your own rules, not a second gameplay engine.
func is_complete() -> bool:
	return game.debug_sample_turn >= game.session.players.size()

func progress() -> String:
	return str(game.debug_sample_turn)

func step(_rng: RandomNumberGenerator) -> bool:
	var turn: int = game.debug_sample_turn
	return submit(str(game.session.players[turn].id), {"action":"debug_sample", "revision":turn})
