extends SceneTree

const Rules = preload("res://Games/four-in-a-row/host/rules.gd")
const Host = preload("res://Games/four-in-a-row/host/main.tscn")
const LOCAL := {"id": "local-host", "display_name": "Host", "color": "#ff9800"}
const PHONE := {"id": "phone", "display_name": "Phone", "color": "#2463eb"}
const SECOND := {"id": "second", "display_name": "Second", "color": "#00ffff"}
var failures := 0
var awards := 0
var reports := 0
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
	check(host.sounds.size() == 3 and host.sounds["win"].bus == "Effects", "Bundled cues use shared Effects volume")
	# Keep valid local streams while muting rules-test audio.
	for sound in host.sounds.values():
		sound.volume_db = -80
	var context := GameSessionContext.new("four-in-a-row", players, LOCAL, not players.is_empty())
	context.reduced_motion = true
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	host.controller_state_updated.connect(func(state: Dictionary) -> void: snapshot = state)
	host.points_awarded.connect(func(_id: String, amount: int) -> void: awards += amount)
	host.result_reported.connect(func(_id: String, _won: bool) -> void: reports += 1)
	host.start_game()
	return host


func _send(host: Node, id: String, column: Variant) -> void:
	host.handle_controller_message(id, {"action": "move", "column": column, "revision": host.rules.revision})


func _run() -> void:
	seed(20260930)
	var rules := Rules.new()
	check(Rules.LINES.size() == 69, "All 69 four-cell lines enumerated")
	for line in Rules.LINES:
		var board := Rules.new().board
		for cell in line:
			board[cell] = 2
		check(Rules.result(board) == 2, "Horizontal, vertical and both diagonal wins")
	check(not rules.move(-1, 1) and not rules.move(7, 1) and not rules.move(0, 2), "Invalid column and wrong turn rejected")
	for row in range(5, -1, -1):
		var mark := rules.turn
		check(rules.move(0, mark) and rules.board[row * 7] == mark, "Gravity fills column bottom to top")
	var revision := rules.revision
	check(not rules.move(0, rules.turn) and rules.revision == revision, "Full column rejected without changing revision")
	# A full board containing no horizontal, vertical or diagonal fours.
	var draw := [1,1,2,2,1,1,2, 2,2,1,1,2,2,1, 1,1,2,2,1,1,2, 2,2,1,1,2,2,1, 1,1,2,2,1,1,2, 2,2,1,1,2,2,1]
	check(Rules.result(draw) == 3, "Full board is a draw")
	rules.board = draw.duplicate()
	rules.board[0] = 0
	rules.turn = 1
	check(rules.move(0, 1) and rules.draws == 1 and rules.wins == [0, 0], "Draw updates history without points")
	check(rules.next_round() and rules.turn == 2 and rules.board.count(0) == 42, "Draw alternates starter and clears board")
	for level in 3:
		var board := Rules.new().board
		board[35] = 1
		board[36] = 1
		board[37] = 1
		var before := board.duplicate()
		var start := Time.get_ticks_msec()
		var column := Rules.computer_move(board, 2, level)
		print("AI level %d: %d ms" % [level, Time.get_ticks_msec() - start])
		check(column >= 0 and column < 7 and board == before, "AI chooses legal column without mutating board")
		if level != Rules.Difficulty.EASY:
			check(column == 3, "Medium and Hard block immediate threat")
		board[35] = 2
		board[36] = 2
		board[37] = 2
		if level != Rules.Difficulty.EASY:
			check(Rules.computer_move(board, 2, level) == 3, "AI takes immediate win")
		check(Rules.computer_move(draw, 2, level) == -1, "AI stops on draw")
	var solo = _host([])
	solo._host_move(3)
	check(solo.rules.board.count(0) == 40, "Solo host move receives computer reply")
	var old_revision: int = solo.rules.revision
	solo._select_difficulty(Rules.Difficulty.HARD)
	check(solo.rules.board.count(0) == 42 and solo.rules.revision > old_revision and solo.rules.history.is_empty(), "Difficulty resets session and invalidates stale input")
	solo.shutdown_game()
	solo.queue_free()
	var phone_ai = _host([PHONE])
	phone_ai._host_move(0)
	check(phone_ai.rules.board.count(0) == 42, "Host cannot play phone seat in AI mode")
	_send(phone_ai, PHONE.id, 3)
	check(phone_ai.rules.board.count(0) == 40, "One phone receives AI response")
	phone_ai.shutdown_game()
	phone_ai.queue_free()
	var host = _host([PHONE])
	old_revision = host.rules.revision
	host._select_mode(1)
	host.handle_controller_message(PHONE.id, {"action": "move", "column": 0, "revision": old_revision})
	_send(host, LOCAL.id, 0)
	_send(host, PHONE.id, 0)
	check(host.rules.board.count(0) == 42, "Stale inputs, host impersonation and wrong turn rejected")
	host._host_move(0)
	host._select_mode(0)
	check(host.host_plays and host.mode_choice.disabled, "Opponents lock after first move")
	host.player_disconnected(PHONE.id)
	_send(host, PHONE.id, 1)
	check(snapshot.paused and host.rules.board.count(0) == 41, "Disconnect pauses play")
	host.player_joined(PHONE)
	check(not snapshot.paused and snapshot.players[1].id == PHONE.id and snapshot.board[35] == 1, "Reconnect restores board and seats")
	for bad in [-1, 7, 1.5, "2", null, {}, true, INF, NAN]:
		_send(host, PHONE.id, bad)
	check(host.rules.board.count(0) == 41, "Malformed columns rejected")
	_send(host, PHONE.id, 1)
	check(host.rules.board[36] == 2 and awards == 0 and reports == 0, "Host vs phone uses session scores only")
	host.shutdown_game()
	host.queue_free()
	var two = _host([PHONE, SECOND])
	for column in [0, 6, 1, 6, 2, 5, 3]:
		_send(two, PHONE.id if two.rules.turn == 1 else SECOND.id, column)
	check(two.rules.outcome == 1 and snapshot.winning_cells == [35,36,37,38] and snapshot.winning_lines.size() == 1, "Win snapshot includes strike geometry")
	check(two.rules.champion == 1 and awards == 1 and reports == 2, "One completed board awards one point and one result per player")
	check(two.replay_button.visible and two.replay_button.text == "PLAY AGAIN", "One game win immediately offers Play Again")
	two.handle_controller_message(PHONE.id, {"action": "sync"})
	check(awards == 1 and reports == 2, "Repeated first-game sync never duplicates standings")
	old_revision = two.rules.revision
	two._play_again()
	check(two.rules.board.count(0) == 42 and two.rules.session_wins == [1, 0] and two.rules.revision > old_revision and two.score_cards[0].score.text == "1", "Play Again preserves wins while starting a fresh board")
	for column in [6, 0, 6, 1, 5, 2, 5, 3]:
		_send(two, PHONE.id if two.rules.turn == 1 else SECOND.id, column)
	check(two.rules.champion == 1 and awards == 2 and reports == 4, "Each completed phone game records one win")
	two.handle_controller_message(PHONE.id, {"action": "sync"})
	two._publish()
	check(awards == 2 and reports == 4, "Repeated sync never duplicates awards")
	two._play_again()
	check(two.rules.wins == [0,0] and two.rules.session_wins == [2,0] and two.rules.history.size() == 2 and two.rules.round_number == 3, "Replay preserves game wins and history and advances the game number")
	two.shutdown_game()
	_send(two, PHONE.id, 2)
	check(two.rules.board.count(0) == 42, "Shutdown blocks input")
	two.queue_free()
	var catalog := GameCatalog.new()
	var found := catalog.scan().filter(func(game: Dictionary) -> bool: return game.id == "four-in-a-row")
	check(found.size() == 1 and found[0].min_players == 1 and found[0].max_players == 2, "Catalog discovers one module with 1–2 player limits")
	await process_frame
	print("Four in a Row: %d failures" % failures)
	quit(0 if failures == 0 else 1)
