extends SceneTree

const Rules = preload("res://Games/tic-tac-toe/host/rules.gd")
var failures := 0
var leaves := 0
var result_count := 0
var points := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _explore(board: Array, turn: int, ai: int) -> void:
	var outcome := Rules.result(board)
	if outcome != 0:
		leaves += 1
		check(outcome == ai or outcome == 3, "Perfect AI never loses")
		return
	if turn == ai:
		var cell := Rules.best_move(board, ai)
		board[cell] = ai
		_explore(board, 3 - turn, ai)
		board[cell] = 0
	else:
		for cell in 9:
			if board[cell] == 0:
				board[cell] = turn
				_explore(board, 3 - turn, ai)
				board[cell] = 0


func _run() -> void:
	seed(20260926)
	var openings: Dictionary = {}
	var replies: Dictionary = {}
	for attempt in 32:
		var empty := [0, 0, 0, 0, 0, 0, 0, 0, 0]
		openings[Rules.best_move(empty, 2)] = true
		check(empty == [0, 0, 0, 0, 0, 0, 0, 0, 0], "AI search preserves board")
		var center := [0, 0, 0, 0, 1, 0, 0, 0, 0]
		var reply := Rules.best_move(center, 2)
		replies[reply] = true
		check(reply in [0, 2, 6, 8], "AI answers center with a safe corner")
		check(Rules.best_move([1, 1, 0, 0, 2, 0, 0, 0, 0], 2) == 2, "Randomness preserves forced block")
		check(Rules.best_move([2, 2, 0, 1, 1, 0, 1, 0, 0], 2) == 2, "Randomness preserves forced win")
	check(openings.size() > 1, "Computer openings vary across fresh boards")
	check(replies.size() > 1, "Computer opening replies vary")
	check(Rules.best_move([1, 2, 1, 1, 2, 2, 2, 1, 1], 2) == -1, "Full board has no move")
	for ai in [1, 2]:
		_explore([0, 0, 0, 0, 0, 0, 0, 0, 0], 1, ai)
	var rules := Rules.new()
	check(not rules.move(-1, 1) and not rules.move(9, 1) and not rules.move(0, 2), "Reject invalid moves")
	for cell in [0, 1, 2, 4, 3, 5, 7, 6, 8]:
		check(rules.move(cell, rules.turn), "Draw sequence accepted")
	check(rules.outcome == 3 and rules.wins == [0, 0], "Draw leaves scores unchanged")
	check(rules.draws == 1 and rules.history.size() == 1, "Tie added to session history")
	check(rules.play_again() and rules.turn == 2, "Play Again works after a draw and alternates starters")
	check(not rules.play_again() and not rules.next_round(), "Cannot replay an unfinished board")
	for line in Rules.LINES:
		var board := [0, 0, 0, 0, 0, 0, 0, 0, 0]
		for cell in line:
			board[cell] = 2
		check(Rules.result(board) == 2, "Detect every winning line")
	var app = load("res://Main.tscn").instantiate()
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	await process_frame
	var catalog := GameCatalog.new()
	var games := catalog.scan().filter(func(item: Dictionary) -> bool: return item.id == "tic-tac-toe")
	check(games.size() == 1 and games[0]["id"] == "tic-tac-toe", "Catalog discovers game")
	var game: Dictionary = games[0]
	check(app.lan_server._resolve_game_web_path("/game/tic-tac-toe/controller.js") == "res://Games/tic-tac-toe/controller/controller.js", "Entry sibling assets resolve")
	check(app.lan_server._resolve_game_web_path("/game/tic-tac-toe/../main.gd").is_empty(), "Asset traversal rejected")
	for count in 4:
		app.lan_server.active_players.clear()
		for index in count:
			app.lan_server.active_players[str(index)] = {"id": str(index), "display_name": "Player %d" % index, "color": "#2463eb"}
		check(app._can_launch(game) == (count <= 2), "Player limit %d" % count)
	app.lan_server.active_players.clear()
	app._enter_lobby()
	await create_timer(0.7).timeout
	app._play_from_lobby()
	check(not app.lan_server.lobby_open, "Selection locks joining")
	app._launch_game(game)
	await process_frame
	var host = app.active_game
	check(host.seats[1]["id"] == "computer", "Local solo automatically gets AI")
	host.cells[0].pressed.emit()
	check(host.rules.board.count(0) == 7, "Host input triggers AI reply")
	app._return_from_game()
	check(app.current_state == "game_menu" and not app.lan_server.lobby_open, "Exit keeps joining locked")
	var players := [{"id": "a", "display_name": "Alice", "color": "#2463eb"}, {"id": "b", "display_name": "Bob", "color": "#e53935"}]
	host = load("res://Games/tic-tac-toe/host/main.tscn").instantiate()
	root.add_child(host)
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(GameSessionContext.new("tic-tac-toe", players, {}, true))
	host.result_reported.connect(func(_id: String, _won: bool) -> void: result_count += 1)
	host.points_awarded.connect(func(_id: String, amount: int) -> void: points += amount)
	host.start_game()
	for payload in [{"action": "move", "cell": []}, {"action": "move", "cell": 1.5}, {"action": "move", "cell": "0"}, {"action": "move", "cell": 9}, {"action": "move", "cell": true}]:
		payload["revision"] = 0
		host.handle_controller_message("a", payload)
	host.handle_controller_message("intruder", {"action": "move", "cell": 0, "revision": 0})
	host.handle_controller_message("b", {"action": "move", "cell": 0, "revision": 0})
	check(host.rules.revision == 0, "Malformed, unknown, out-of-turn inputs rejected")
	host.player_disconnected("b")
	host.handle_controller_message("a", {"action": "move", "cell": 0, "revision": 0})
	check(host.rules.revision == 0 and host.missing.has("b"), "Disconnect pauses input")
	host.player_joined(players[1])
	check(host.missing.is_empty(), "Reconnect restores same match")
	for cell in [0, 3, 1, 4, 2]:
		host.handle_controller_message(players[host.rules.turn - 1]["id"], {"action": "move", "cell": cell, "revision": host.rules.revision})
	check(host.rules.wins == [1, 0] and host.rules.champion == 1 and result_count == 2 and points == 1, "First completed board immediately records one win/loss and one point")
	host._publish()
	host.handle_controller_message("a", {"action": "sync"})
	host._move(8, 1)
	check(result_count == 2 and points == 1 and host.rules.wins == [1, 0], "Completion is idempotent")
	check(host.rules.session_wins == [1, 0] and host.rules.match_wins == [1, 0] and host.rules.history.size() == 1, "Session totals recorded once")
	check(host.replay_button.visible and host.score_cards[0].score.text == "1", "Completed round shows Play Again and its session win")
	var finished_revision: int = host.rules.revision
	host.player_disconnected("b")
	host.handle_controller_message("a", {"action": "play_again", "revision": finished_revision})
	check(host.rules.champion == 1, "Replay waits for disconnected opponent")
	host.player_joined(players[1])
	host.handle_controller_message("intruder", {"action": "play_again", "revision": finished_revision})
	check(host.rules.champion == 1, "Unknown sender cannot replay")
	host.handle_controller_message("b", {"action": "play_again", "revision": finished_revision})
	check(host.rules.champion == 0 and host.rules.wins == [0, 0] and host.rules.match_number == 2, "Multiplayer replay starts fresh match")
	check(host.rules.session_wins == [1, 0] and host.rules.history.size() == 1 and host.score_cards[0].score.text == "1", "Replay retains session scores and history")
	host.handle_controller_message("a", {"action": "move", "cell": 0, "revision": finished_revision})
	check(host.rules.board.count(0) == 9, "Pre-replay input cannot affect new match")
	for cell in [3, 0, 4, 1, 8, 2]:
		host._move(cell, host.rules.turn)
	check(result_count == 4 and points == 2 and host.rules.session_wins == [2, 0] and host.rules.match_wins == [2, 0], "Next completed board awards exactly once again")
	host._play_again()
	for cell in [0, 1, 2, 4, 3, 5, 7, 6, 8]:
		host._move(cell, host.rules.turn)
	check(host.rules.outcome == 3 and host.rules.champion == 0 and host.replay_button.visible, "Draw offers the same Play Again control")
	check(result_count == 4 and points == 2 and host.rules.draws == 1 and host.rules.history.size() == 3, "Draw records history without standings or points")
	host.handle_controller_message("b", {"action": "next", "revision": host.rules.revision})
	check(host.rules.turn == 2 and host.rules.board.count(0) == 9, "Legacy next action replays with alternating starter")
	for cell in [0, 3, 1, 4, 2]:
		host._move(cell, host.rules.turn)
	check(result_count == 6 and points == 3 and host.rules.session_wins == [2, 1], "O also earns a single immediate round win")
	host.shutdown_game()
	host.queue_free()
	host = load("res://Games/tic-tac-toe/host/main.tscn").instantiate()
	root.add_child(host)
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(GameSessionContext.new("tic-tac-toe", [players[0]], {}, true))
	host.start_game()
	host.handle_controller_message("a", {"action": "move", "cell": 0, "revision": 0})
	check(host.rules.board.count(0) == 7 and host.seats[1]["id"] == "computer", "One phone plays AI")
	host.handle_controller_message("a", {"action": "move", "cell": 1, "revision": 0})
	check(host.rules.board.count(0) == 7, "Stale input rejected")
	check(host.rules.history.is_empty() and host.rules.match_wins == [0, 0], "New game clears session history")
	# Complete AI matches through legal moves, then replay with the phone and host.
	for local in [false, true]:
		while host.rules.champion == 0:
			if host.rules.outcome != 0:
				host._next_round()
			else:
				host._move(host.rules.board.find(0), 1)
		check(host.replay_button.visible, "AI match offers replay")
		if local:
			host.replay_button.pressed.emit()
		else:
			host.handle_controller_message("a", {"action": "play_again", "revision": host.rules.revision})
		check(host.rules.champion == 0 and host.rules.wins == [0, 0], "AI replay resets match")
		check(host.rules.turn == 1, "Computer opening move runs on replay when needed")
	check(host.sounds.size() == 3 and host.sounds["win"].bus == "Effects", "Local effects use Effects volume")
	host.shutdown_game()
	host.queue_free()
	var template = load("res://Games/_Template/host/main.tscn").instantiate()
	root.add_child(template)
	template.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	template.initialize_session(GameSessionContext.new("template", [], {"id": "host"}, false))
	template.start_game()
	check(template.screen.status != null, "Template uses shared game screen")
	template.shutdown_game()
	template.queue_free()
	app._leave_lobby()
	app.queue_free()
	await process_frame
	print("Tic Tac Toe: %d AI terminal paths checked; %d failures" % [leaves, failures])
	quit(0 if failures == 0 else 1)
