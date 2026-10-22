extends SceneTree

const HOST = preload("res://Games/tic-tac-toe/host/main.tscn")
var failures := 0
var snapshot: Dictionary


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var host := HOST.instantiate()
	root.add_child(host)
	var players := [{"id": "x", "display_name": "X"}, {"id": "o", "display_name": "O"}]
	var context := GameSessionContext.new("tic-tac-toe", players)
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	for sound in host.sounds.values():
		sound.stream = null
	host.controller_state_updated.connect(func(value: Dictionary) -> void: snapshot = value)
	host.start_game()
	await process_frame
	host._move(0, 1)
	check(host.pieces[0].scale.x < 1.0, "New mark begins its placement pop")
	var placement: Tween = host.pieces[0].get_meta("game_motion")
	host._publish()
	check(host.pieces[0].get_meta("game_motion") == placement, "Duplicate snapshots do not restart placement")
	host._move(3, 2)
	host._move(1, 1)
	host._move(4, 2)
	host._move(2, 1)
	check(snapshot.winning_cells == [0, 1, 2], "Host identifies the completed winning row")
	check(snapshot.winning_lines == [[0, 1, 2]], "Snapshot preserves winning line geometry")
	check(host.celebration.sparks.size() == 64 and host.celebration.banner.visible, "Win launches confetti and a banner")
	host.celebration.age = 0.5
	var victory: Tween = host.pieces[0].get_meta("game_motion")
	host.player_reconnected(players[0])
	check(host.pieces[0].get_meta("game_motion") == victory, "Reconnect does not repeat host victory")
	check(host.celebration.age == 0.5, "Reconnect does not restart the celebration")
	var old_round: String = snapshot.round_id
	host._next_round()
	check(snapshot.winning_cells.is_empty() and snapshot.round_id != old_round, "New round clears victory and changes board identity")
	check(not victory.is_valid() and host.pieces[0].scale == Vector2.ONE, "Reset cancels old victory motion")
	check(host.celebration.lines.is_empty() and host.celebration.sparks.is_empty(), "Reset clears strike and confetti")
	context.reduced_motion = true
	host._move(0, 2)
	check(host.pieces[0].scale == Vector2.ONE and not host.pieces[0].has_meta("game_motion"), "Reduced motion places the mark immediately")
	# A final center placement can complete both diagonals at once.
	host.rules.board = [1, 2, 1, 2, 1, 2, 1, 2, 1]
	host.rules.outcome = 1
	host._publish()
	check(snapshot.winning_cells.size() == 5, "Both completed diagonals remain highlighted")
	check(not host.pieces[4].has_meta("game_motion"), "Reduced-motion win remains static")
	check(host.celebration.lines.size() == 2 and host.celebration.sparks.is_empty() and not host.celebration.banner.visible, "Reduced motion keeps both strikes without particles or banner motion")
	host.rules.outcome = 3
	host.rules.board = [1, 2, 1, 1, 2, 2, 2, 1, 1]
	host._publish()
	check(snapshot.winning_cells.is_empty(), "Draw does not celebrate a winning line")
	host.shutdown_game()
	host.queue_free()
	await process_frame
	print("Tic Tac Toe motion: %d failures" % failures)
	quit(1 if failures else 0)
