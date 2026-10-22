extends SceneTree

const Rules = preload("res://Games/tic-tac-toe/host/rules.gd")
const Host = preload("res://Games/tic-tac-toe/host/main.tscn")
const LOCAL := {"id": "local-host", "display_name": "Host", "color": "#ff9800"}
const PHONE := {"id": "phone", "display_name": "Phone", "color": "#2463eb"}
var failures := 0
var awards := 0
var snapshot: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _host(players: Array) -> Node:
	var host := Host.instantiate()
	root.add_child(host)
	# These rules/input checks run many moves in one frame; audio is tested separately.
	for sound in host.sounds.values():
		sound.stream = null
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(GameSessionContext.new("tic-tac-toe", players, LOCAL, not players.is_empty()))
	host.controller_state_updated.connect(func(state: Dictionary) -> void: snapshot = state)
	host.points_awarded.connect(func(_id: String, _amount: int) -> void: awards += 1)
	host.result_reported.connect(func(_id: String, _won: bool) -> void: awards += 1)
	host.start_game()
	return host


func _run() -> void:
	seed(20260927)
	var mistakes := [0, 0, 0]
	for level in 3:
		for attempt in 128:
			var board := [1, 1, 0, 0, 2, 0, 0, 0, 0]
			var move := Rules.computer_move(board, 2, level)
			check(move in [2, 3, 5, 6, 7, 8], "Every difficulty chooses a legal move")
			check(board == [1, 1, 0, 0, 2, 0, 0, 0, 0], "AI leaves input board intact")
			if move != 2:
				mistakes[level] += 1
				board[move] = 2
				board[2] = 1
				check(Rules.result(board) == 1, "An AI mistake can be beaten")
		check(Rules.computer_move([1, 1, 1, 2, 2, 0, 0, 0, 0], 2, level) == -1, "AI stops on a completed board")
	check(mistakes[0] > mistakes[1] and mistakes[1] > 0 and mistakes[2] == 0, "Easy errs more than Medium; Hard always blocks")
	var solo = _host([])
	check(solo.difficulty_choice.get_parent().visible and not solo.mode_choice.get_parent().visible, "Only solo difficulty shown to host alone")
	solo.difficulty_choice.item_selected.emit(Rules.Difficulty.EASY)
	check(solo.difficulty == Rules.Difficulty.EASY, "Host can choose difficulty before playing")
	solo.cells[0].pressed.emit()
	check(solo.rules.board.count(0) == 7 and not solo.difficulty_choice.disabled, "Difficulty stays available during play")
	var previous_revision: int = solo.rules.revision
	solo._select_difficulty(Rules.Difficulty.EASY)
	solo._select_difficulty(-1)
	solo._select_difficulty(3)
	check(solo.rules.revision == previous_revision and solo.rules.board.count(0) == 7, "Same or invalid difficulty preserves play")
	solo._select_difficulty(Rules.Difficulty.HARD)
	check(solo.difficulty == Rules.Difficulty.HARD and solo.rules.board.count(0) == 9 and solo.rules.turn == 1, "Difficulty change immediately resets active board")
	check(solo.rules.revision > previous_revision and snapshot.board.count(0) == 9, "Reset publishes fresh state with an advanced revision")
	# Seed prior session totals and finish a match to cover all reset state.
	solo.rules.session_wins = [3, 2]
	solo.rules.match_wins = [1, 1]
	solo.rules.draws = 2
	solo.rules.match_number = 3
	solo.rules.round_number = 4
	solo.rules.board = [1, 1, 0, 2, 2, 0, 0, 0, 0]
	solo.rules.wins = [0, 0]
	solo._host_move(2)
	check(solo.rules.champion == 1 and solo.result_sent, "Completed solo match records session result")
	previous_revision = solo.rules.revision
	solo.difficulty_choice.item_selected.emit(Rules.Difficulty.MEDIUM)
	check(solo.rules.board.count(0) == 9 and solo.rules.wins == [0, 0] and solo.rules.champion == 0 and solo.rules.outcome == 0, "Difficulty resets completed match without Play Again")
	check(solo.rules.session_wins == [0, 0] and solo.rules.match_wins == [0, 0] and solo.rules.draws == 0 and solo.rules.history.is_empty(), "Difficulty clears scoreboard, ties, and history")
	check(solo.rules.match_number == 1 and solo.rules.round_number == 1 and solo.rules.starter == 1, "Difficulty restarts match and round numbering with host first")
	check(not solo.result_sent and not solo.match_started and not solo.session_started and solo.rules.revision > previous_revision, "Difficulty clears lifecycle flags and advances revision")
	check(not solo.replay_button.visible and solo.history_log.text == "No completed rounds yet.", "Reset refreshes history and replay control")
	check(snapshot.session_wins == [0, 0] and snapshot.match_wins == [0, 0] and snapshot.draws == 0 and awards == 0, "Reset publishes cleared scoreboard without saved awards")
	solo.cells[0].pressed.emit()
	check(solo.rules.board.count(0) == 7, "Fresh game accepts host move and AI reply immediately")
	solo.shutdown_game()
	solo.queue_free()
	var host = _host([PHONE])
	check(not host.difficulty_choice.get_parent().visible and host.mode_choice.get_parent().visible, "One phone exposes opponent choice only")
	host._select_difficulty(Rules.Difficulty.EASY)
	check(host.difficulty == Rules.Difficulty.MEDIUM, "Phone sessions reject solo difficulty changes")
	host.cells[0].pressed.emit()
	check(host.rules.board.count(0) == 9, "Host cannot play phone's turn in AI mode")
	var old_revision: int = host.rules.revision
	host.mode_choice.item_selected.emit(1)
	check(host.host_plays and snapshot.players[0].id == LOCAL.id and snapshot.players[1].id == PHONE.id, "Host is X and connected player is O in snapshot")
	host.handle_controller_message(PHONE.id, {"action": "move", "cell": 0, "revision": old_revision})
	check(host.rules.board.count(0) == 9, "Mode switch invalidates queued input")
	host.handle_controller_message(LOCAL.id, {"action": "move", "cell": 0, "revision": host.rules.revision})
	check(host.rules.board.count(0) == 9, "Browser cannot impersonate local host")
	host.handle_controller_message(PHONE.id, {"action": "move", "cell": 0, "revision": host.rules.revision})
	check(host.rules.board.count(0) == 9, "Phone cannot play host's turn")
	host.cells[0].pressed.emit()
	check(host.rules.board.count(0) == 8 and host.rules.turn == 2, "Host move waits for phone without AI")
	host._select_mode(0)
	check(host.host_plays and host.mode_choice.disabled, "Opponents lock after first move")
	host.player_disconnected(PHONE.id)
	host.handle_controller_message(PHONE.id, {"action": "move", "cell": 3, "revision": host.rules.revision})
	check(host.rules.board[3] == 0 and snapshot.paused and not host.difficulty_choice.get_parent().visible, "Disconnect pauses instead of switching to solo")
	host.player_joined(PHONE)
	host.handle_controller_message(PHONE.id, {"action": "sync"})
	check(not snapshot.paused and snapshot.turn == 2 and snapshot.board[0] == 1 and snapshot.players[1].id == PHONE.id, "Reconnect restores phone's O seat and board")
	for cell in [3, 1, 4, 2]:
		if host.rules.turn == 1:
			host.cells[cell].pressed.emit()
		else:
			host.handle_controller_message(PHONE.id, {"action": "move", "cell": cell, "revision": host.rules.revision})
	host._next_round()
	check(host.rules.turn == 2 and host.rules.board.count(0) == 9, "Phone starts next round without AI")
	for cell in [3, 0, 4, 1, 8, 2]:
		if host.rules.turn == 1:
			host.cells[cell].pressed.emit()
		else:
			host.handle_controller_message(PHONE.id, {"action": "move", "cell": cell, "revision": host.rules.revision})
	check(host.rules.champion == 1 and host.rules.session_wins == [2, 0] and host.rules.match_wins == [2, 0] and awards == 0, "Each host-versus-phone board records a session win without saved standings")
	host.handle_controller_message(PHONE.id, {"action": "play_again", "revision": host.rules.revision})
	check(host.host_plays and host.rules.wins == [0, 0] and host.rules.match_wins == [2, 0], "Replay preserves opponents and session totals")
	host.shutdown_game()
	host.queue_free()
	var phone_ai = _host([PHONE])
	# Even an internal Easy setting must not weaken the AI in a phone session.
	phone_ai.difficulty = Rules.Difficulty.EASY
	for attempt in 32:
		phone_ai.rules.board = [1, 1, 0, 0, 2, 0, 0, 0, 0]
		phone_ai.rules.turn = 2
		phone_ai._computer_turn()
		check(phone_ai.rules.board[2] == 2, "Phone versus AI always uses Hard")
	phone_ai.shutdown_game()
	phone_ai.queue_free()
	var two = _host([PHONE, {"id": "second", "display_name": "Second"}])
	check(not two.difficulty_choice.get_parent().visible and not two.mode_choice.get_parent().visible, "Two phones hide solo and host opponent settings")
	check(not two.settings_hint.get_parent().get_parent().visible, "Two phones omit the entire setup card")
	two._select_mode(1)
	two._host_move(0)
	check(not two.host_plays and two.rules.board.count(0) == 9, "Two-phone match cannot add host")
	two.shutdown_game()
	two.queue_free()
	await process_frame
	print("Tic Tac Toe modes: %d failures; mistakes by difficulty: %s" % [failures, mistakes])
	quit(0 if failures == 0 else 1)
