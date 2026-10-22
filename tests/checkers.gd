extends SceneTree

const Rules = preload("res://Games/checkers/host/rules.gd")
const Host = preload("res://Games/checkers/host/main.tscn")
const LOCAL := {"id": "local-host", "display_name": "Host", "color": "#ff9800"}
const PHONE := {"id": "phone", "display_name": "Phone", "color": "#2463eb"}
const SECOND := {"id": "second", "display_name": "Second", "color": "#00ffff"}
var failures := 0
var checks := 0
var awards := 0
var reports := 0
var snapshot: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _position(pieces: Dictionary, mark := 1) -> RefCounted:
	var rules := Rules.new()
	rules.board.fill(0)
	for cell in pieces:
		rules.board[cell] = pieces[cell]
	rules.turn = mark
	rules.positions = {Rules.position_key(rules.board, mark): 1}
	return rules


func _host(players: Array) -> Node:
	var host := Host.instantiate()
	root.add_child(host)
	var context := GameSessionContext.new("checkers", players, LOCAL, not players.is_empty())
	context.reduced_motion = true
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	check(host.sounds.size() == 5 and host.sounds.win.bus == "Effects", "All local cues use shared Effects volume")
	for sound in host.sounds.values():
		sound.volume_db = -80
	host.controller_state_updated.connect(func(state: Dictionary) -> void: snapshot = state)
	host.points_awarded.connect(func(_id: String, amount: int) -> void: awards += amount)
	host.result_reported.connect(func(_id: String, _won: bool) -> void: reports += 1)
	host.start_game()
	return host


func _send(host: Node, id: String, from_cell: Variant, to_cell: Variant, revision: Variant = null) -> void:
	host.handle_controller_message(id, {"action": "move", "from": from_cell, "to": to_cell, "revision": host.rules.revision if revision == null else revision})


func _run() -> void:
	seed(20261001)
	var rules := Rules.new()
	check(rules.board.size() == 64 and rules.board.count(1) == 12 and rules.board.count(2) == 12, "Twelve pieces each on an 8 by 8 board")
	check(rules.legal_moves().size() == 7, "Seven legal opening moves")
	for cell in 64:
		check(rules.board[cell] == 0 or Rules.playable(cell), "Pieces occupy only dark squares")
	check(not rules.move(-1, 32, 1) and not rules.move(40, 64, 1) and not rules.move(40, 32, 1), "Bounds and non-diagonal moves rejected")
	check(not rules.move(40, 33, 2) and rules.revision == 0, "Wrong side rejected without changing revision")
	check(rules.move(40, 33, 1) and rules.turn == 2 and rules.revision == 1, "Valid forward move switches turn")
	var backwards = _position({26: 1, 35: 2})
	check(not backwards.move(26, 44, 1) and not backwards.move(26, 33, 1), "Men cannot move or capture backwards")
	var king = _position({26: 3, 35: 4})
	check(king.move(26, 44, 1) and king.board[35] == 0 and king.outcome == 1, "Kings capture opposing kings backwards")
	var mandatory = _position({42: 1, 60: 1, 35: 2, 19: 2})
	check(mandatory.force_jump, "Force Jump is on by default")
	check(mandatory.legal_moves().size() == 1 and not mandatory.move(60, 51, 1), "A capture anywhere forbids quiet moves")
	check(mandatory.move(42, 28, 1) and mandatory.forced_from == 28 and mandatory.turn == 1, "First jump retains the turn and locks the piece")
	check(not mandatory.move(60, 51, 1) and mandatory.legal_moves()[0].from == 28, "Another piece cannot replace a chained jumper")
	check(mandatory.move(28, 10, 1) and mandatory.board[19] == 0 and mandatory.forced_from == -1 and mandatory.outcome == 1, "Completing a chain captures all opponents and wins")
	check(mandatory.champion == 1 and mandatory.session_wins == [1, 0], "One completed board is one completed game and win")
	var optional = _position({42: 1, 60: 1, 35: 2, 19: 2})
	var optional_board: Array = optional.board.duplicate()
	check(optional.set_force_jump(false) and optional.board == optional_board and optional.revision == 1, "Turning Force Jump off preserves the board and advances revision")
	check(optional.legal_moves().any(func(step: Dictionary) -> bool: return step.capture < 0) and optional.legal_moves().any(func(step: Dictionary) -> bool: return step.capture >= 0), "Optional captures expose both jumps and quiet moves")
	check(optional.move(60, 51, 1) and optional.board[35] == 2, "A player may decline a capture with Force Jump off")
	optional = _position({42: 1, 60: 1, 35: 2, 19: 2})
	optional.set_force_jump(false)
	check(optional.move(42, 28, 1) and optional.forced_from == 28 and not optional.move(60, 51, 1), "Optional capture still completes a started jump chain")
	check(not optional.set_force_jump(true) and not optional.force_jump, "Force Jump cannot change during a jump chain")
	check(optional.move(28, 10, 1) and optional.next_round() and not optional.force_jump, "Next round preserves the selected capture rule")
	var choice = _position({42: 1, 35: 2, 19: 2, 33: 2, 62: 1})
	check(choice.legal_moves().size() == 2, "Different capture paths are freely selectable")
	var crown = _position({17: 1, 10: 2, 12: 2, 55: 2})
	check(crown.move(17, 3, 1) and crown.board[3] == 3 and crown.forced_from == -1 and crown.turn == 2, "Promotion ends a capturing turn even if a backward jump opens")
	check(Rules.counts(crown.board, 1) == {"pieces": 1, "men": 0, "kings": 1}, "Material counters distinguish men and kings")
	var black_crown = _position({46: 2, 53: 1, 51: 1}, 2)
	check(black_crown.move(46, 60, 2) and black_crown.board[60] == 4, "Black crowns at the bottom row")
	var blocked = _position({40: 1, 58: 2})
	check(blocked.move(40, 33, 1) and blocked.outcome == 1, "Blocked opponents lose despite retaining pieces")
	var repeat = _position({56: 3, 7: 4})
	for cycle in 2:
		for step in [[56, 49, 1], [7, 14, 2], [49, 56, 1], [14, 7, 2]]:
			check(repeat.move(step[0], step[1], step[2]), "Repetition sequence remains legal")
	check(repeat.outcome == 3 and repeat.draws == 1 and repeat.wins == [0, 0], "Third position repetition draws without a win")
	check(repeat.next_round() and repeat.turn == 2 and repeat.board.count(1) == 12, "Draws replay with alternate starter and fresh pieces")
	var quiet = _position({56: 3, 7: 4})
	quiet.quiet_turns = 79
	check(quiet.move(56, 49, 1) and quiet.outcome == 3, "Eighty quiet king turns draw")
	var advance = _position({40: 1, 7: 4})
	advance.quiet_turns = 79
	check(advance.move(40, 33, 1) and advance.quiet_turns == 0 and advance.outcome == 0, "Moving any man resets the quiet-turn draw counter")
	var timed := Rules.new()
	check(timed.clock_seconds == 0 and timed.configure_clock(93) and timed.remaining == [93.0, 93.0], "Optional timer defaults off and accepts custom seconds")
	for invalid in [-1.0, 86401.0, INF, NAN]:
		check(not timed.configure_clock(invalid) and timed.clock_seconds == 93, "Invalid timer settings preserve the configured clock")
	check(not timed.advance_clock(50) and timed.remaining == [93.0, 93.0], "Countdown waits for the first legal move")
	check(timed.move(40, 33, 1) and not timed.configure_clock(600), "First move starts the timer and locks settings")
	check(not timed.advance_clock(3) and timed.remaining == [93.0, 90.0], "Only the active player's clock counts down")
	check(timed.advance_clock(90) and timed.outcome == 1 and timed.result_reason == "Time expired" and timed.session_wins == [1, 0], "Timeout immediately awards the opponent one win")
	check(not timed.advance_clock(100) and timed.history.size() == 1, "Repeated timer ticks cannot duplicate a result")
	check(timed.play_again() and timed.turn == 2 and timed.remaining == [93.0, 93.0] and not timed.clock_started and timed.session_wins == [1, 0], "Replay alternates starters, restores clocks and keeps wins")
	check(timed.configure_clock(0) and not timed.advance_clock(100), "Host can disable the timer between boards")
	var chain_clock = _position({42: 1, 35: 2, 19: 2, 7: 2})
	chain_clock.configure_clock(30)
	check(chain_clock.move(42, 28, 1) and not chain_clock.advance_clock(5) and chain_clock.remaining == [25.0, 30.0], "A multi-jump keeps the same player's clock running")
	check(chain_clock.move(28, 10, 1) and not chain_clock.advance_clock(4) and chain_clock.remaining == [25.0, 26.0], "Completing the chain switches the active clock")
	var expired_chain = _position({42: 1, 35: 2, 19: 2})
	expired_chain.configure_clock(1)
	expired_chain.move(42, 28, 1)
	check(expired_chain.advance_clock(2) and expired_chain.outcome == 2 and not expired_chain.move(28, 10, 1), "Timeout rejects a late continuation of a capture chain")
	for level in 3:
		var board := Rules.new().board
		var before := board.duplicate()
		var started := Time.get_ticks_msec()
		var step: Dictionary = Rules.computer_move(board, 1, level)
		print("Checkers AI level %d: %d ms" % [level, Time.get_ticks_msec() - started])
		check(Rules.available_moves(board, 1).has(step) and board == before, "AI returns legal input without modifying host state")
		var attack = _position({42: 1, 35: 2, 19: 2})
		step = Rules.computer_move(attack.board, 1, level)
		check(step.from == 42 and step.to == 28, "AI respects forced captures")
		check(Rules.computer_move(attack.board, 1, level, 28).is_empty(), "AI rejects an invalid chain origin")
		var no_moves = _position({58: 2}, 2)
		check(Rules.computer_move(no_moves.board, 2, level).is_empty(), "AI stops when no legal move remains")
		var relaxed = _position({42: 1, 60: 1, 35: 2, 19: 2})
		step = Rules.computer_move(relaxed.board, 1, level, -1, false)
		check(Rules.available_moves(relaxed.board, 1, -1, false).has(step), "All AI levels respect optional-capture legal moves")
	var relaxed_ai = _position({42: 1, 60: 1, 35: 2, 19: 2})
	var declined := false
	for attempt in 32:
		declined = declined or Rules.computer_move(relaxed_ai.board, 1, Rules.Difficulty.EASY, -1, false).capture < 0
	check(declined, "Easy AI can choose a quiet move when captures are optional")
	# Random legal play catches edge wraparound, stalled chains and piece creation.
	for game in 8:
		var random_game := Rules.new()
		for ply in 500:
			if random_game.outcome != 0:
				break
			var steps: Array = random_game.legal_moves()
			check(not steps.is_empty(), "Active games always have input available")
			if steps.is_empty():
				break
			var step: Dictionary = steps.pick_random()
			var count: int = 64 - random_game.board.count(0)
			check(random_game.move(step.from, step.to, random_game.turn), "Generated moves are accepted")
			check(64 - random_game.board.count(0) == count - (1 if step.capture >= 0 else 0), "Moves cannot create or lose unrelated pieces")
	print("Checkers rule checks complete; starting host lifecycle checks")
	var solo = _host([])
	solo._select_force_jump(false)
	check(not snapshot.force_jump and solo.force_jump_toggle.text == "FORCE JUMP: OFF", "Host toggle publishes the authoritative option")
	solo._host_cell(40)
	solo._host_cell(33)
	check(solo.rules.revision == 2 and solo.ai_pending, "Solo host has a delayed AI reply")
	await create_timer(1.0).timeout
	check(solo.rules.revision == 3 and solo.rules.turn == 1, "AI reply completes and returns control")
	solo._host_cell(42)
	solo._host_cell(35)
	var old_revision: int = solo.rules.revision
	solo._select_difficulty(Rules.Difficulty.HARD)
	await create_timer(0.6).timeout
	check(solo.rules.board.count(1) == 12 and solo.rules.revision > old_revision and solo.rules.history.is_empty() and solo.rules.turn == 1, "Changing difficulty resets scores and cancels queued AI")
	check(not solo.rules.force_jump and not solo.force_jump_toggle.button_pressed, "Difficulty resets preserve the Force Jump preference")
	solo.shutdown_game()
	solo.queue_free()
	await process_frame
	print("Checkers solo checks complete")
	var host = _host([PHONE])
	old_revision = host.rules.revision
	host._select_mode(1)
	_send(host, PHONE.id, 40, 33, old_revision)
	_send(host, LOCAL.id, 40, 33)
	_send(host, PHONE.id, 40, 33)
	check(host.rules.revision == old_revision + 1 and host.rules.board[40] == 1, "Stale moves, host impersonation and wrong-seat inputs rejected")
	host._host_cell(40)
	host._host_cell(33)
	host._select_mode(0)
	check(host.host_plays and host.mode_choice.disabled, "Opponents lock after the first move")
	host.player_disconnected(PHONE.id)
	_send(host, PHONE.id, 17, 24)
	check(snapshot.paused and host.rules.board[17] == 2, "Disconnect pauses play without replacing players")
	host.player_joined(PHONE)
	check(not snapshot.paused and snapshot.players[1].id == PHONE.id and snapshot.board[33] == 1, "Reconnect restores the same board and seat")
	old_revision = host.rules.revision
	for bad in [-1, 64, 17.5, "17", null, {}, true, INF, NAN]:
		_send(host, PHONE.id, bad, 24)
		_send(host, PHONE.id, 17, bad)
	for bad in [true, "2", 2.5, INF, NAN, {}, -1]:
		_send(host, PHONE.id, 17, 24, bad)
	check(host.rules.revision == old_revision, "Malformed squares and revisions are ignored safely")
	_send(host, PHONE.id, 17, 24)
	check(host.rules.board[24] == 2 and awards == 0 and reports == 0, "Host-versus-phone scores do not affect saved standings")
	host.shutdown_game()
	host.queue_free()
	await process_frame
	print("Checkers local-versus-phone checks complete")
	var two = _host([PHONE, SECOND])
	check(two.settings_details.get_parent().visible and two.force_jump_toggle.button_pressed, "Two-phone matches expose the default-on host option")
	two.rules = _position({42: 1, 60: 1, 35: 2, 19: 2})
	two._publish()
	old_revision = two.rules.revision
	two._select_force_jump(false)
	_send(two, PHONE.id, 60, 51, old_revision)
	check(two.rules.board[60] == 1 and not snapshot.force_jump, "A rule change rejects queued input from the previous revision")
	two.handle_controller_message(PHONE.id, {"action": "force_jump", "enabled": true, "revision": two.rules.revision})
	check(not two.rules.force_jump, "Controllers cannot change host options")
	_send(two, PHONE.id, 60, 51)
	check(two.rules.board[51] == 1 and two.rules.board[35] == 2, "Two-phone play accepts a quiet move while a capture is available")
	two.rules = _position({42: 1, 35: 2, 19: 2})
	_send(two, PHONE.id, 42, 28)
	check(snapshot.forced_from == 28 and snapshot.legal_moves.size() == 1 and snapshot.counts[1].men == 1, "Authoritative snapshot restores a capture in progress")
	check(two.force_jump_toggle.disabled, "Host rule toggle locks during a jump chain")
	two.player_disconnected(PHONE.id)
	_send(two, PHONE.id, 28, 10)
	check(two.rules.board[19] == 2, "Mid-chain disconnect preserves opponent pieces")
	two.player_joined(PHONE)
	check(snapshot.forced_from == 28 and not snapshot.paused, "Reconnect resumes the same forced piece")
	_send(two, PHONE.id, 28, 10)
	check(two.rules.wins == [1, 0] and awards == 1 and reports == 2 and snapshot.champion == 1, "One two-phone game awards one point and one result per player")
	check(two.score_cards[0].score.text == "1 WIN" and two.replay_button.visible and two.replay_button.text == "PLAY AGAIN", "Completed game shows a win total and one Play Again button")
	check(two.cells[10].get_theme_stylebox("disabled").border_color == Color("ffde55"), "Reduced motion retains a static gold winner highlight")
	two.handle_controller_message(PHONE.id, {"action": "sync"})
	check(awards == 1 and reports == 2, "Duplicate first-game snapshots cannot duplicate standings")
	old_revision = two.rules.revision
	two._play_again()
	check(two.rules.outcome == 0 and two.rules.revision > old_revision and two.rules.session_wins == [1, 0] and two.score_cards[0].score.text == "1 WIN", "Play Again starts a fresh board and keeps previous wins")
	two.rules.board.fill(0)
	two.rules.board[42] = 1
	two.rules.board[35] = 2
	two.rules.turn = 1
	_send(two, PHONE.id, 42, 28)
	check(two.rules.champion == 1 and awards == 2 and reports == 4, "Every completed two-phone board records its own win")
	two.handle_controller_message(PHONE.id, {"action": "sync"})
	two._publish()
	check(awards == 2 and reports == 4, "Duplicate snapshots cannot duplicate points or results")
	old_revision = two.rules.revision
	two._play_again()
	check(two.rules.wins == [0, 0] and two.rules.session_wins == [2, 0] and two.rules.history.size() == 2 and two.rules.round_number == 3 and two.rules.revision > old_revision, "Replay preserves game wins and history and increments the game number")
	check(two.score_cards[0].score.text == "2 WINS", "Scoreboard retains both wins after replay")
	var returned := [false]
	two.return_to_lobby_requested.connect(func() -> void: returned[0] = true)
	two.screen.exit_requested.emit()
	check(returned[0], "Back uses the launcher navigation signal")
	two.shutdown_game()
	old_revision = two.rules.revision
	_send(two, PHONE.id, 40, 33)
	check(two.rules.revision == old_revision and not two.ai_pending, "Shutdown cancels AI and rejects late input")
	two.queue_free()
	await process_frame
	print("Checkers two-phone checks complete")
	var phone_ai = _host([PHONE])
	phone_ai._host_cell(40)
	check(phone_ai.rules.revision == 0, "The host cannot play a phone's AI seat")
	_send(phone_ai, PHONE.id, 40, 33)
	print("Checkers phone-AI: move sent")
	phone_ai.player_disconnected(PHONE.id)
	await create_timer(0.6).timeout
	print("Checkers phone-AI: disconnect waited")
	check(phone_ai.rules.revision == 1 and not phone_ai.ai_pending, "Disconnect cancels the computer reply")
	phone_ai.player_joined(PHONE)
	print("Checkers phone-AI: rejoined")
	await create_timer(1.0).timeout
	print("Checkers phone-AI: reply waited")
	check(phone_ai.rules.revision == 2, "Reconnect resumes a paused computer turn")
	phone_ai.shutdown_game()
	phone_ai.queue_free()
	await process_frame
	var timed_host = _host([PHONE, SECOND])
	timed_host._configure_clock(180)
	check(snapshot.clock_seconds == 180 and not snapshot.clock_running and timed_host.clock_labels[0].visible, "Host publishes custom timer state and read-only clocks")
	var timer_revision: int = timed_host.rules.revision
	timed_host.handle_controller_message(PHONE.id, {"action": "clock", "seconds": 0, "revision": timer_revision})
	check(timed_host.rules.clock_seconds == 180 and timed_host.rules.revision == timer_revision, "Controllers cannot change the host's timer")
	_send(timed_host, PHONE.id, 40, 33)
	check(snapshot.clock_running and timed_host.clock_toggle.disabled and not timed_host.clock_input.editable, "Active game locks timer editing")
	timed_host.player_disconnected(SECOND.id)
	var saved_time: Array = timed_host.rules.remaining.duplicate()
	timed_host.last_tick -= 10000
	timed_host._consume_clock()
	check(timed_host.rules.remaining == saved_time and not snapshot.clock_running, "Disconnect freezes both clocks without discarding the board")
	timed_host.player_joined(SECOND)
	check(snapshot.clock_running and snapshot.board[33] == 1 and snapshot.remaining[1] > 179, "Reconnect restores the clock and position without charging disconnected time")
	var prior_awards := awards
	var prior_reports := reports
	timed_host.last_tick -= 181000
	_send(timed_host, SECOND.id, 17, 24)
	check(timed_host.rules.outcome == 1 and timed_host.rules.board[17] == 2 and snapshot.status.contains("Time expired"), "Host checks timeout before accepting a late move")
	check(awards == prior_awards + 1 and reports == prior_reports + 2 and snapshot.history.contains("Time expired"), "Two-phone timeout records one saved win, point and history entry")
	timed_host.handle_controller_message(PHONE.id, {"action": "sync"})
	check(awards == prior_awards + 1 and reports == prior_reports + 2, "Timeout sync cannot duplicate saved standings")
	timed_host._play_again()
	check(snapshot.remaining == [180.0, 180.0] and snapshot.session_wins == [1, 0] and not snapshot.clock_running, "Replay resets timer while retaining session wins")
	timed_host.shutdown_game()
	timed_host.queue_free()
	await process_frame
	var timed_solo = _host([])
	timed_solo._configure_clock(73)
	timed_solo._select_difficulty(Rules.Difficulty.HARD)
	check(timed_solo.rules.clock_seconds == 73 and timed_solo.rules.remaining == [73.0, 73.0], "Difficulty changes preserve custom timer settings")
	_send(timed_solo, PHONE.id, 40, 33)
	timed_solo._host_cell(40)
	timed_solo._host_cell(33)
	timed_solo.last_tick -= 74000
	timed_solo._process(0)
	await create_timer(0.6).timeout
	check(timed_solo.rules.outcome == 1 and not timed_solo.ai_pending and awards == prior_awards + 1, "Timeout cancels a queued computer move and solo games leave standings unchanged")
	timed_solo.shutdown_game()
	timed_solo.queue_free()
	var catalog := GameCatalog.new()
	var found := catalog.scan().filter(func(game: Dictionary) -> bool: return game.id == "checkers")
	check(found.size() == 1 and found[0].min_players == 1 and found[0].max_players == 2, "Catalog discovers Checkers once with one-to-two player limits")
	await process_frame
	print("Checkers: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
