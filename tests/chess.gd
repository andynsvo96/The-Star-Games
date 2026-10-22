extends SceneTree

const Rules = preload("res://Games/chess/host/rules.gd")
const Host = preload("res://Games/chess/host/main.tscn")
const LOCAL := {"id": "host", "display_name": "Host", "color": "#ff9800"}
const PHONE := {"id": "phone", "profile_id": "p1", "display_name": "Phone", "color": "#2463eb"}
const SECOND := {"id": "second", "profile_id": "p2", "display_name": "Second", "color": "#00ffff"}
var failures := 0
var checks := 0
var awards: Array = []
var reports: Array = []
var snapshot: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


static func fen(text: String) -> Dictionary:
	var fields := text.split(" ")
	var board: Array = []
	for letter in fields[0]:
		if letter == "/":
			continue
		if letter.is_valid_int():
			for _empty in int(letter):
				board.append(0)
		else:
			var kind := "pnbrqk".find(letter.to_lower()) + 1
			board.append(kind if letter == letter.to_upper() else -kind)
	var rights := 0
	for letter in fields[2]:
		rights |= {"K": 1, "Q": 2, "k": 4, "q": 8}.get(letter, 0)
	var ep := -1
	if fields[3] != "-":
		ep = (8 - int(fields[3][1])) * 8 + "abcdefgh".find(fields[3][0])
	return {"board": board, "turn": 1 if fields[1] == "w" else 2, "castling": rights, "en_passant": ep, "halfmove": int(fields[4])}


static func perft(state: Dictionary, depth: int) -> int:
	if depth == 0:
		return 1
	var count := 0
	for step in Rules.legal_moves_for(state):
		count += perft(Rules.apply(state, step), depth - 1)
	return count


func position(text: String) -> RefCounted:
	var rules := Rules.new()
	rules.position = fen(text)
	rules.positions = {Rules.position_key(rules.position): 1}
	return rules


func has_move(rules: RefCounted, from_cell: int, to_cell: int, promotion := 0) -> bool:
	return rules.legal_moves().any(func(step: Dictionary) -> bool: return step.from == from_cell and step.to == to_cell and step.promotion == promotion)


func _host(players: Array) -> Node:
	var host := Host.instantiate()
	root.add_child(host)
	var context := GameSessionContext.new("chess", players, LOCAL, not players.is_empty())
	context.reduced_motion = true
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	host.set_process(false)
	for sound in host.sounds.values():
		sound.volume_db = -80
	host.controller_state_updated.connect(func(state: Dictionary) -> void: snapshot = state)
	host.points_awarded.connect(func(id: String, amount: int) -> void: awards.append([id, amount]))
	host.result_reported.connect(func(id: String, won: bool) -> void: reports.append([id, won]))
	host.start_game()
	return host


func send(host: Node, id: String, action: String, input: Dictionary = {}) -> void:
	var message := {"action": action, "revision": host.rules.revision}
	message.merge(input, true)
	host.handle_controller_message(id, message)


func _run() -> void:
	seed(20261001)
	var rules := Rules.new()
	check(rules.legal_moves().size() == 20, "Twenty legal opening moves")
	check(perft(rules.position, 2) == 400 and perft(rules.position, 3) == 8902, "Published opening move-tree counts through depth three")
	var kiwipete := fen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
	check(perft(kiwipete, 1) == 48 and perft(kiwipete, 2) == 2039, "Kiwipete move-tree validates castling, checks and pins")
	var endgame := fen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
	check(perft(endgame, 3) == 2812, "Rook/pawn endgame move-tree validates en-passant and king safety")
	check(not rules.move(-1, 36, 1) and not rules.move(52, 64, 1) and not rules.move(52, 36, 2), "Bounds and wrong-turn moves rejected")
	check(rules.move(52, 36, 1) and rules.position.en_passant == 44, "Pawn double step sets transient en-passant target")
	check(rules.move(8, 16, 2) and rules.position.en_passant == -1, "En-passant expires after the next turn")
	var castle = position("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
	check(has_move(castle, 60, 62) and has_move(castle, 60, 58), "Both clear castling destinations allowed")
	check(castle.move(60, 62, 1) and castle.position.board[61] == Rules.ROOK and castle.position.board[63] == 0 and castle.position.castling == 12, "Castling moves the rook and permanently clears king rights")
	var attacked_castle = position("k4r2/8/8/8/8/8/8/4K2R w K - 0 1")
	check(not has_move(attacked_castle, 60, 62), "Cannot castle across an attacked square")
	var pinned = position("k3r3/8/8/8/8/8/4R3/4K3 w - - 0 1")
	check(not has_move(pinned, 52, 51) and has_move(pinned, 52, 12), "Pinned rook cannot expose its king")
	var ep = position("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
	check(ep.move(28, 19, 1) and ep.position.board[27] == 0 and ep.position.board[19] == 1, "En-passant removes the pawn on its original square")
	var ep_pin = position("k7/8/8/r4pPK/8/8/8/8 w - f6 0 1")
	check(not has_move(ep_pin, 30, 21), "En-passant exposing a horizontal rook check is illegal")
	var same: Dictionary = ep_pin.position.duplicate(true)
	same.en_passant = -1
	check(Rules.position_key(same) == Rules.position_key(ep_pin.position), "An unusable en-passant target does not change repetition identity")
	var promotion = position("4k3/P7/8/8/8/8/8/4K3 w - - 0 1")
	for kind in Rules.PROMOTIONS:
		check(has_move(promotion, 8, 0, kind), "Each promotion choice is legal")
	check(not promotion.move(8, 0, 1) and promotion.move(8, 0, 1, Rules.KNIGHT), "Promotion requires an explicit piece and supports underpromotion")
	var mate := Rules.new()
	for step in [[53, 45], [12, 28], [54, 38], [3, 39]]:
		check(mate.move(step[0], step[1], mate.position.turn), "Fool's mate move accepted")
	check(mate.outcome == 2 and mate.session_wins == [0, 1] and mate.moves[-1].ends_with("#"), "Checkmate immediately awards exactly one board win")
	check(not mate.finish(2, "duplicate") and mate.play_again() and mate.white_seat == 1 and mate.position.turn == 1 and mate.session_wins == [0, 1], "Replay swaps colors, White still starts, participant wins persist")
	mate.finish(1, "Test win")
	check(mate.session_wins == [0, 2] and mate.history[-1].winner == 1, "Wins track the participant after colors change")
	var stale = position("k7/8/1QK5/8/8/8/8/8 w - - 0 1")
	check(stale.move(17, 10, 1) and stale.outcome == 3 and stale.result_reason == "Stalemate", "Stalemate draws without a win")
	for text in ["4k3/8/8/8/8/8/8/4K3 w - - 0 1", "4k3/8/8/8/8/8/8/3BK3 w - - 0 1", "4k3/8/8/8/8/8/8/3NK3 w - - 0 1", "4kb2/8/8/8/8/8/8/2B1K3 w - - 0 1"]:
		check(Rules.dead_position(fen(text).board), "Standard dead material is detected")
	check(not Rules.dead_position(fen("4k3/8/8/8/8/8/8/2NNK3 w - - 0 1").board), "Two knights are not incorrectly declared a dead position")
	var repeat := Rules.new()
	for _cycle in 2:
		for step in [[62, 45], [6, 21], [45, 62], [21, 6]]:
			repeat.move(step[0], step[1], repeat.position.turn)
	check(repeat.outcome == 0 and repeat.claim_draw() and repeat.result_reason == "Threefold repetition", "Threefold is claimable, not an automatic premature draw")
	var five := Rules.new()
	for _cycle in 4:
		for step in [[62, 45], [6, 21], [45, 62], [21, 6]]:
			five.move(step[0], step[1], five.position.turn)
	check(five.outcome == 3 and five.result_reason == "Fivefold repetition", "Fivefold repetition draws automatically")
	var fifty = position("4k3/8/8/8/8/8/8/R3K3 w - - 99 1")
	check(not fifty.claim_draw() and fifty.claim_draw({"from": 56, "to": 48}), "The 50-move rule may be claimed using a legal intended move")
	var seventyfive = position("4k3/8/8/8/8/8/8/R3K3 w - - 149 1")
	check(seventyfive.move(56, 48, 1) and seventyfive.outcome == 3, "75-move rule draws automatically")
	var timed := Rules.new()
	check(timed.configure_clock(93) and timed.remaining == [93.0, 93.0], "Custom clock accepts arbitrary time instead of presets")
	check(not timed.advance_clock(50) and timed.remaining == [93.0, 93.0], "Clock waits for the first move")
	timed.move(52, 36, 1)
	check(not timed.configure_clock(600) and not timed.advance_clock(3) and is_equal_approx(timed.remaining[1], 90), "Only the side to move loses time; settings lock after a move")
	check(timed.advance_clock(90) and timed.outcome == 1 and timed.play_again() and timed.remaining == [93.0, 93.0], "Time expiry awards one win and replay restores custom clocks")
	var flag = position("4k3/8/8/8/8/8/p7/4K3 b - - 0 1")
	flag.configure_clock(1)
	flag.clock_started = true
	check(flag.advance_clock(2) and flag.outcome == 3, "Flag fall draws when the opponent cannot possibly mate")
	var resignation = position("4k3/8/8/8/8/8/p7/4K3 b - - 0 1")
	check(resignation.resign(2) and resignation.outcome == 3, "Resignation draws when the opponent cannot possibly mate")
	check(not Rules.can_mate(fen("4k3/8/8/8/8/8/8/3NK3 w - - 0 1").board, 1), "A single knight cannot mate a bare king on flag fall")
	var ai_position := fen("7k/5Q2/6K1/8/8/8/8/8 w - - 0 1")
	var ai := Rules.computer_move(ai_position, Rules.Difficulty.HARD)
	var ai_after := Rules.apply(ai_position, ai)
	check(Rules.in_check(ai_after, 2) and Rules.legal_moves_for(ai_after).is_empty(), "Hard computer finds an immediate mate")
	for level in [0, 1, 2]:
		var before := Rules.starting_position()
		var step := Rules.computer_move(before, level)
		check(Rules.legal_moves_for(before).has(step) and before == Rules.starting_position(), "Every computer difficulty returns legal moves without mutating the live board")
	var solo := _host([])
	check(solo.host_plays and solo.guidance and solo.rules.clock_seconds == 0 and solo.sounds.size() == 5, "Solo defaults match the existing games")
	solo._configure_clock(123)
	solo._select_guidance(false)
	solo._host_cell(52)
	solo._host_cell(36)
	check(solo.rules.position.board[36] == 1 and not snapshot.guidance and snapshot.clock_seconds == 123, "Guidance off still allows host moves and publishes custom time")
	solo._select_difficulty(0)
	check(solo.rules.moves.is_empty() and solo.rules.session_wins == [0, 0] and solo.rules.clock_seconds == 123 and not solo.guidance, "Solo difficulty resets scores while preserving clock and guidance")
	solo.shutdown_game()
	solo.queue_free()
	await process_frame
	var single := _host([PHONE])
	check(not single.host_plays and single._player(1).id == "phone", "One phone defaults to computer play")
	single._select_mode(1)
	check(single.host_plays and single._player(2).id == "phone", "Host versus phone maps identities to seats")
	send(single, "phone", "move", {"from": 52, "to": 36})
	check(single.rules.moves.is_empty(), "Phone cannot move the host's white pieces")
	single._move(52, 36, 1)
	send(single, "phone", "move", {"from": 12, "to": 28})
	check(single.rules.moves.size() == 2, "Phone's authorized black move accepted")
	single._select_mode(0)
	check(single.host_plays, "Opponents lock after the first move")
	single.player_disconnected("phone")
	var before_pause: Array = single.rules.position.board.duplicate()
	single._move(51, 35, 1)
	check(single.rules.position.board == before_pause and snapshot.paused, "Disconnect pauses host moves")
	single.player_joined(PHONE)
	check(not snapshot.paused and snapshot.board == before_pause, "SDK reconnect callback restores the same board")
	single.rules.finish(3, "Fixture draw")
	single._publish()
	single._play_again()
	check(single._host_side() == 2 and single._player(1).id == "phone" and awards.is_empty(), "Replay swaps host/phone colors without saved awards")
	single.shutdown_game()
	single.queue_free()
	await process_frame
	var party := _host([PHONE, SECOND])
	for invalid in [{"from": true, "to": 36}, {"from": 52.5, "to": 36}, {"from": 52, "to": 36, "revision": false}, {"from": 52, "to": 36, "revision": -1}, {"from": 52, "to": 36, "promotion": true}, {"from": 52, "to": 99}]:
		send(party, "phone", "move", invalid)
		check(party.rules.moves.is_empty(), "Malformed controller input ignored")
	send(party, "intruder", "resign")
	check(party.rules.outcome == 0, "Unadmitted identity cannot end a game")
	party._configure_clock(180)
	send(party, "phone", "move", {"from": 52, "to": 36})
	party.player_disconnected("second")
	var remaining: Array = party.rules.remaining.duplicate()
	party.last_tick -= 10000
	party._consume_clock()
	check(party.rules.remaining == remaining, "Disconnected time is not deducted")
	party.player_joined(SECOND)
	send(party, "second", "guidance", {"enabled": false})
	check(party.guidance and snapshot.board == party.rules.position.board, "Phone input cannot change host-only options")
	party._select_guidance(false)
	check(not snapshot.guidance, "Host guidance option publishes to controllers")
	party.rules.position.halfmove = 100
	party.rules.revision += 1
	party._publish()
	var before_removed: Dictionary = party.rules.position.duplicate(true)
	var before_revision: int = party.rules.revision
	for action in ["claim_draw", "offer_draw", "accept_draw", "resign"]:
		send(party, "second", action)
		check(party.rules.outcome == 0 and party.rules.position == before_removed and party.rules.revision == before_revision, "Removed %s input cannot change or end a game" % action)
	send(party, "second", "claim_draw", {"from": 12, "to": 28})
	check(party.rules.outcome == 0 and party.rules.position == before_removed, "An intended-move draw claim is also ignored")
	check(not snapshot.has("claim_moves") and not snapshot.has("claim_reason") and not snapshot.has("draw_offer"), "Snapshots omit removed draw controls")
	party.rules.position = fen("7k/5Q2/6K1/8/8/8/8/8 w - - 0 1")
	party.rules.last_move = {}
	party.rules.revision += 1
	party._publish()
	send(party, "phone", "move", {"from": 13, "to": 14})
	check(party.rules.outcome == 1 and party.rules.result_reason == "Checkmate", "An authorized controller checkmate ends the board")
	check(awards == [["p1", 1]] and reports == [["p1", true], ["p2", false]], "Decisive two-phone game awards the winner once")
	party._publish()
	check(awards.size() == 1 and reports.size() == 2, "Duplicate snapshots never duplicate points or results")
	send(party, "phone", "play_again")
	check(snapshot.players[0].id == "second" and snapshot.session_wins == [0, 1], "Controller snapshots remap colors while keeping participant wins")
	send(party, "second", "move", {"from": 52, "to": 36, "revision": 0})
	check(party.rules.moves.is_empty(), "Previous-round revision is rejected")
	party.rules.position = fen("7k/8/6K1/8/8/8/8/R7 w - - 149 1")
	party.rules.last_move = {}
	party.rules.revision += 1
	party._publish()
	send(party, "second", "move", {"from": 56, "to": 48})
	check(party.rules.outcome == 3 and party.rules.result_reason == "75-move rule" and awards.size() == 1 and reports.size() == 2, "Automatic draws award no saved points or win/loss")
	check(not snapshot.players[0].has("profile_id") and not snapshot.players[0].has("reconnect_token"), "Snapshots contain only public player identity")
	party.shutdown_game()
	party.queue_free()
	await process_frame
	var catalog := GameCatalog.new()
	var games := catalog.scan()
	check(games.filter(func(game: Dictionary) -> bool: return game.id == "chess").size() == 1 and catalog.diagnostics.is_empty(), "Chess is discovered exactly once with a valid manifest")
	await process_frame
	await create_timer(0.15).timeout
	print("Chess: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
