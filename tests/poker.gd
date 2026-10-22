extends SceneTree

const Rules = preload("res://Games/poker/host/rules.gd")
const Evaluator = preload("res://Games/poker/host/evaluator.gd")
var checks := 0
var failures := 0


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(label)


func cards(text: String) -> Array:
	var result: Array = []
	for token in text.split(" "):
		result.append("23456789TJQKA".find(token[0]) + "cdhs".find(token[1]) * 13)
	return result


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixtures := ["2c 5d 7h 9s Jc", "2c 2d 7h 9s Jc", "2c 2d 7h 7s Jc", "2c 2d 2h 9s Jc", "Ac 2d 3h 4s 5c", "2c 5c 7c 9c Jc", "2c 2d 2h Js Jc", "2c 2d 2h 2s Jc", "9c Tc Jc Qc Kc", "Tc Jc Qc Kc Ac"]
	var previous := -1
	for index in fixtures.size():
		var value: Dictionary = Evaluator.five(cards(fixtures[index]))
		check(int(value.score) > previous, "Five-card category ordering %d" % index); previous = int(value.score)
	check(Evaluator.five(cards("Ac 2d 3h 4s 5c")).score < Evaluator.five(cards("2c 3d 4h 5s 6c")).score, "Ace-low straight loses to six-high")
	check(Evaluator.five(cards("Ac Ad Kh 9s 2c")).score > Evaluator.five(cards("Ac Ad Qh Js Tc")).score, "Pair kickers compare lexicographically")
	check(Evaluator.five(cards("Ac Kc Qc Jc Tc")).score == Evaluator.five(cards("Ah Kh Qh Jh Th")).score, "Suits never break a tie")
	var board := cards("Ah Kh Qh Jh Th")
	check(Evaluator.best(cards("2c 3d"), board, "texas").name == "Royal Flush", "Hold’em may play the board")
	check(Evaluator.best(cards("2c 3d 4s 5c"), board, "omaha").category == 0, "Omaha cannot play the board")
	check(Evaluator.best(cards("9h 8h Ac Ad"), board, "omaha").name == "Straight Flush", "Omaha selects exactly two private and three community cards")
	check(Evaluator.best(cards("Ac Ad Ah As"), cards("2c 3d 4s 8h 9c"), "omaha").category == 1, "Four held aces do not become Omaha quads")
	var game := Rules.new(); check(game.start(2, "texas", Rules.DEFAULTS, 0, 17), "Starts heads-up")
	check(game.turn == game.dealer and game.small_seat == game.dealer, "Heads-up dealer posts small blind and acts first pre-flop")
	check(game.act(game.turn, "call") and game.turn == game.big_seat, "Big blind retains an unraised option")
	check(game.view_for(-1).players[0].last_action == "call" and game.view_for(-1).players[0].last_amount == 10, "Public call feedback uses the chips actually paid")
	check(game.act(game.turn, "check") and game.stage == "flop" and game.turn == game.big_seat, "Heads-up big blind acts first post-flop")
	check(game.players.all(func(player: Dictionary) -> bool: return player.last_action.is_empty() and player.last_amount == 0), "A new street clears the prior call and raise indicators")
	game.start(3, "omaha", Rules.DEFAULTS, 0, 18)
	check(game.legal(game.turn).max_raise_to == 70, "Opening PLO pot raise is to 70 at 10/20")
	check(not game.act(game.turn, "all_in"), "PLO rejects an all-in beyond the pot limit")
	check(not game.act(game.turn, "raise", 71) and not game.act(game.turn, "raise", 39), "Rejects excessive and undersized raises")
	check(game.act(game.turn, "raise", 70), "Accepts exact pot-limit maximum")
	check(game.view_for(-1).players[0].last_action == "raise" and game.view_for(-1).players[0].last_amount == 50, "Raise feedback is the accepted increase above the previous current bet")
	var legacy := game.export_state()
	for player in legacy.players: player.erase("last_amount")
	check(Rules.new().import_state(legacy), "Earlier saved tournaments remain valid without the new feedback amount")
	var invalid_feedback := game.export_state(); invalid_feedback.players[0].last_amount = game.total_chips + 1
	check(not Rules.new().import_state(invalid_feedback), "Session validation rejects an impossible feedback amount")
	game.start(3, "texas", Rules.DEFAULTS, 0, 19)
	game.players[1].stack = 45
	check(game.act(0, "raise", 40) and game.act(1, "all_in") and game.act(2, "call"), "Creates a short all-in raise")
	check(game.turn == 0 and not game.legal(0).can_raise and game.legal(0).call == 15, "Short raise requires a call without reopening earlier raiser")
	check(not game.act(0, "raise", 100), "Cannot forge a raise after action was not reopened")
	game.start(4, "texas", Rules.DEFAULTS, 0, 191)
	game.players[0].stack = 55; game.players[1].stack = 60
	check(game.act(3, "raise", 40) and game.act(0, "all_in") and game.act(1, "all_in") and game.act(2, "call"), "Creates cumulative short all-ins")
	check(game.turn == 3 and game.legal(3).can_raise and game.legal(3).min_raise_to == 90, "Cumulative full-raise exposure reopens betting with the last full increment")
	game.start(4, "omaha", Rules.DEFAULTS, 0, 192)
	game.players[2].street = 10; game.players[2].committed = 10; game.players[2].stack = 0
	check(game.legal(3).max_raise_to == 70, "Pre-flop PLO assumes a full short all-in blind for its pot limit")
	for mode: String in ["texas", "omaha"]:
		game.start(3, mode, Rules.DEFAULTS, 0, 193)
		game.act(0, "call"); game.act(1, "call"); game.act(2, "check")
		game.players[1].stack = 10
		check(game.act(1, "all_in") and game.legal(2).min_raise_to == 30, "A short opening all-in requires a full 20-chip raise above its 10-chip wager in " + mode)
		check(not game.act(2, "raise", 20), "A short opener cannot be completed to the big blind in " + mode)
		check(game.act(2, "raise", 30) and game.legal(0).min_raise_to == 50, "The full raise retains its 20-chip increment in " + mode)
		game.start(3, mode, Rules.DEFAULTS, 0, 194)
		game.act(0, "call"); game.act(1, "call"); game.act(2, "check"); game.act(1, "check")
		game.players[2].stack = 10
		check(game.act(2, "all_in") and game.act(0, "call") and not game.legal(1).can_raise, "A short opening all-in does not reopen a previous checker in " + mode)
	game.start(3, "texas", Rules.DEFAULTS, 0, 20)
	game.players[0].hand = cards("Ac Ad"); game.players[1].hand = cards("Kc Kd"); game.players[2].hand = cards("Qc Qd")
	game.board = cards("2c 3d 4h 8s 9c"); game.stage = "river"; game.total_chips = 250
	for seat in 3:
		game.players[seat].stack = 0; game.players[seat].committed = 50 if seat == 0 else 100; game.players[seat].street = game.players[seat].committed
	game._settle(true)
	check(game.players[0].stack == 150 and game.players[1].stack == 100 and game.players[2].stack == 0, "Independent main and side-pot winners conserve chips")
	var ranked: Array = game.view_for(-1).hand_results
	check(ranked.map(func(entry: Dictionary) -> int: return int(entry.seat)) == [0, 1, 2] and ranked.map(func(entry: Dictionary) -> int: return int(entry.rank)) == [1, 2, 3], "Completed hands rank strongest first including the eliminated showdown contender")
	check(ranked[0].amount == 150 and ranked[1].amount == 100 and ranked[2].amount == 0 and ranked.all(func(entry: Dictionary) -> bool: return entry.cards.size() == 5), "Ranked rows preserve independent pot awards and show the best five cards")
	game.start(3, "texas", Rules.DEFAULTS, 0, 21)
	game.board = board; game.total_chips = 15
	for seat in 3: game.players[seat].stack = 0; game.players[seat].committed = 5; game.players[seat].street = 5
	game.players[2].folded = true; game._settle(true)
	check(game.players[0].stack == 7 and game.players[1].stack == 8, "Odd chip goes to first winner clockwise from dealer")
	ranked = game.view_for(-1).hand_results
	check(ranked[0].rank == 1 and ranked[1].rank == 1 and ranked[0].score == ranked[1].score, "Identical hands share a rank regardless of odd-chip awards")
	check(ranked[2].rank == 0 and ranked[2].category == "Folded" and ranked[2].cards.is_empty(), "Folded rows follow ranked contenders without exposing their cards or strength")
	game.start(2, "texas", Rules.DEFAULTS, 0, 22); game.act(game.turn, "fold")
	check(game.last_pot == 20 and game.players[1].stack == 2010, "Uncalled blind is refunded before uncontested award")
	check(not game.showdown and game.view_for(-1).players[1].hand.is_empty(), "Uncontested winner never exposes private cards")
	ranked = game.view_for(-1).hand_results
	check(ranked[0].seat == 1 and ranked[0].category == "Won uncontested" and ranked[0].rank == 1 and ranked.all(func(entry: Dictionary) -> bool: return entry.cards.is_empty()), "Uncontested results list the survivor first and keep every private hand hidden")
	check(ranked[0].net == 10 and ranked[1].net == -10, "Hand changes subtract contributions and exclude the uncalled refund")
	var legacy_net: Dictionary = game.export_state()
	for player in legacy_net.players: player.erase("hand_net")
	check(Rules.new().import_state(legacy_net), "Older Poker saves without net results remain valid")
	var bad_net: Dictionary = game.export_state(); bad_net.players[0].hand_net = -game.total_chips - 1
	check(not Rules.new().import_state(bad_net), "Invalid signed hand changes are rejected")
	check(game.next_hand() and game.dealer == 1, "Next hand rotates dealer")
	check(game.view_for(-1).hand_results.is_empty(), "A new hand clears the previous ranked reveal")
	game.start(2, "texas", Rules.DEFAULTS, 0, 23)
	for hand_index in 10: game.act(game.turn, "fold"); game.next_hand()
	check(game.hand_number == 11 and game.small_blind == 20 and game.big_blind == 40, "Default blinds double after ten completed hands")
	game.start(2, "texas", Rules.DEFAULTS, 0, 24)
	game.players[1].stack = 980
	game.act(0, "all_in")
	check(game.phase == "betting" and game.view_for(-1).players.all(func(player: Dictionary) -> bool: return player.hand.is_empty()), "An all-in does not expose cards while another player still has a decision")
	game.act(1, "call")
	check(game.phase == "runout" and game.current_bet == 1000 and game.players[0].stack == 1000, "Uncalled all-in excess restores stack and public current bet")
	check(game.board.is_empty() and game.view_for(-1).players.all(func(player: Dictionary) -> bool: return player.hand.size() == 2), "Closed all-in betting reveals contenders before the first community card")
	for mode in ["texas", "omaha"]:
		for count in [2, 3, 10]:
			var settings := Rules.DEFAULTS.duplicate(); settings.starting_chips = 100; settings.blind_interval = 2
			game = Rules.new(); game.start(count, mode, settings, 0, 12345 + count)
			var decisions := 0
			while game.phase != "finished" and decisions < 20000:
				decisions += 1
				var restored := Rules.new()
				var parsed: Dictionary = JSON.parse_string(JSON.stringify(game.export_state()))
				check(restored.import_state(parsed), "Valid state round trip %s/%d/%d" % [mode, count, decisions])
				var chips := game.pot()
				for player in game.players: chips += int(player.stack)
				check(chips == count * 100, "Every transition conserves chips")
				var public: Dictionary = game.view_for(-1)
				check(not public.has("deck") and not public.has("burns") and public.hand.is_empty(), "Public state omits deck, burns and private hand")
				if not game.showdown and game.phase != "runout":
					check(public.players.all(func(player: Dictionary) -> bool: return player.hand.is_empty()), "Live public player hands remain hidden")
				if game.phase == "runout":
					check(range(count).all(func(seat: int) -> bool: return public.players[seat].hand == ([] if game.players[seat].folded else game.players[seat].hand)), "Every runout reveals eligible hands while folded and earlier eliminated hands remain hidden")
				if game.phase == "runout": game.advance_runout()
				elif game.phase == "hand_over": game.next_hand()
				else:
					var choice: Dictionary = game.legal(game.turn)
					var action := "check" if choice.check else "call"
					var amount := -1
					if decisions % 5 == 0 and choice.can_raise: action = "raise"; amount = int(choice.max_raise_to)
					elif decisions % 7 == 0: action = "fold"
					check(game.act(game.turn, action, amount), "Offered action accepted")
			check(game.phase == "finished", "Bounded simulated tournament completes %s/%d" % [mode, count])
			var invalid: Dictionary = game.export_state(); invalid.players[0].stack += 1
			check(not Rules.new().import_state(invalid), "Corrupt chip total rejected")
			invalid = game.export_state(); invalid.deck.append(0)
			check(not Rules.new().import_state(invalid), "Duplicate cards rejected")
	var random := RandomNumberGenerator.new(); random.seed = 4702026
	for mode: String in ["texas", "omaha"]:
		for tournament in 20:
			var settings := Rules.DEFAULTS.duplicate(); settings.starting_chips = 100; settings.ante = tournament % 3; settings.blind_interval = 2
			var count: int = [2, 3, 6, 10][tournament % 4]; game = Rules.new(); game.start(count, mode, settings, 0, tournament + 600)
			var decisions := 0
			while game.phase != "finished" and decisions < 5000:
				decisions += 1
				if game.phase == "hand_over": game.next_hand()
				elif game.phase == "runout": game.advance_runout()
				else:
					var legal: Dictionary = game.legal(game.turn); var roll := random.randf(); var action := "check" if legal.check else "call"; var amount := -1
					if roll < .2: action = "fold"
					elif roll < .5 and legal.can_raise: action = "raise"; amount = random.randi_range(int(legal.min_raise_to), int(legal.max_raise_to))
					check(game.act(game.turn, action, amount), "Random offered move remains legal")
				check(Rules.new().import_state(game.export_state()), "Random tournament transition validates cards, pots and chip conservation")
			check(game.phase == "finished", "Random tournament reaches one solvent winner")
	print("Poker rules: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
