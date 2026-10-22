extends SceneTree

const Host = preload("res://Games/checkers/host/main.tscn")
const Rules = preload("res://Games/checkers/host/rules.gd")
var failures := 0
var checks := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var host = Host.instantiate()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for sound in host.sounds.values():
		sound.volume_db = -80
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(GameSessionContext.new("checkers", [], {"id": "host", "display_name": "Host"}, false))
	host.seats[1].id = "opponent"
	host.start_game()
	await process_frame
	await process_frame
	host._host_cell(40)
	check(host.selection_rings[40].visible and host.selection_rings[40].mouse_filter == Control.MOUSE_FILTER_IGNORE, "Selection follows the piece with an input-transparent circular ring")
	host.missing["opponent"] = true
	host._publish()
	check(host.selection_rings.all(func(ring: GameSelectionRing) -> bool: return not ring.visible), "Paused play clears piece selection cues")
	host.missing.clear()
	host._publish()
	host._host_cell(33)
	var movement = host.board_motion
	check(movement.busy and movement.moving_piece.texture == host.PIECES[0], "A move creates a traveling circular piece")
	check(host.selection_rings.all(func(ring: GameSelectionRing) -> bool: return not ring.visible), "Movement clears the static selection ring")
	check(host.pieces[40].texture == null and host.pieces[33].texture == null, "Static source and target do not duplicate the traveler")
	check(movement.moving_piece.global_position.is_equal_approx(host.pieces[40].global_position), "Movement begins at the actual source square")
	var tween: Tween = movement.tween
	host._publish()
	host._select_force_jump(false)
	check(movement.tween == tween, "Duplicate sync and option changes preserve the running movement")
	await create_timer(.15).timeout
	check(movement.moving_piece.global_position.distance_to(host.pieces[40].global_position) > 1 and movement.moving_piece.global_position.distance_to(host.pieces[33].global_position) > 1, "A piece visibly travels between its two squares")
	await create_timer(.3).timeout
	check(not movement.busy and host.pieces[33].texture == host.PIECES[0], "Movement settles at the exact destination")
	host.rules = Rules.new()
	host.rules.board.fill(0)
	host.rules.board[42] = 3
	host.rules.board[35] = 2
	host.rules.board[19] = 2
	host._publish()
	host._move(42, 28, 1)
	check(movement.busy and host.pieces[35].texture == host.PIECES[1], "The jumped piece remains visible as the jump begins")
	host._move(28, 10, 1)
	check(movement.queue.size() == 1 and not host.celebration.banner.visible, "Rapid chained jumps queue and defer the win celebration")
	await create_timer(.45).timeout
	check(movement.busy and movement.displayed[28] == 3 and host.pieces[35].texture == null, "The second jump starts after the first capture lands")
	await create_timer(.5).timeout
	check(not movement.busy and host.pieces[10].texture == host.PIECES[2] and host.pieces[19].texture == null and host.celebration.banner.visible, "Capture chain and celebration finish in order")
	host._next_round()
	host.rules.turn = 1
	host._configure_clock(30)
	host._move(40, 33, 1)
	host.last_tick -= 31000
	host._process(0)
	check(movement.busy and host.rules.outcome == 1 and not host.celebration.banner.visible, "Timeout during a slide records the win and waits for landing feedback")
	await create_timer(.4).timeout
	check(not movement.busy and host.celebration.banner.visible, "Timeout celebration appears when the moving piece settles")
	host._next_round()
	host.rules.turn = 1
	host._publish()
	host._move(40, 33, 1)
	host._select_difficulty(0)
	check(not movement.busy and movement.queue.is_empty() and host.pieces[40].texture == host.PIECES[0], "Reset cancels unfinished movement and restores the new board")
	host.session.reduced_motion = true
	host._move(40, 33, 1)
	check(not movement.busy and host.pieces[33].texture == host.PIECES[0], "Reduced motion places instantly without a traveling overlay")
	host._select_difficulty(1)
	host.session.reduced_motion = false
	host._move(40, 33, 1)
	host.shutdown_game()
	check(not movement.busy and movement.queue.is_empty(), "Exit cancels all movement and queued feedback")
	host.queue_free()
	await process_frame
	print("Checkers motion: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
