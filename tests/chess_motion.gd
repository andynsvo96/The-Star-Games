extends SceneTree

const Host = preload("res://Games/chess/host/main.tscn")
const Fixtures = preload("res://tests/chess.gd")
var checks := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var host := Host.instantiate()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(GameSessionContext.new("chess", [], {"id": "host", "display_name": "Host"}, false))
	host.seats[1].id = "fixture-opponent"
	for sound in host.sounds.values():
		sound.volume_db = -80
	host.start_game()
	await process_frame
	await process_frame
	host._host_cell(52)
	host._host_cell(36)
	var movement = host.board_motion
	check(movement.busy and movement.sprites.size() == 1 and host.pieces[52].texture == null, "A move creates a single traveler without duplicating its source")
	var tween: Tween = movement.tween
	host._publish()
	check(movement.tween == tween, "Duplicate snapshots preserve active movement")
	host._move(12, 28, 2)
	check(host.rules.moves.size() == 1, "Placement during movement is discarded")
	await create_timer(0.15).timeout
	check(movement.sprites[0].global_position.distance_to(host.pieces[52].global_position) > 1, "The pawn visibly travels")
	await create_timer(0.20).timeout
	check(not movement.busy and host.pieces[36].texture == host.textures[1], "The pawn lands on its authoritative destination")
	host.rules.position = Fixtures.fen("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
	host.rules.revision += 1
	host.rules.last_move = {}
	host._publish()
	host._move(60, 62, 1)
	check(movement.busy and movement.sprites.size() == 2, "Castling animates king and rook together")
	await create_timer(0.35).timeout
	check(host.pieces[62].texture == host.textures[6] and host.pieces[61].texture == host.textures[4], "Castling settles both pieces correctly")
	host._select_difficulty(0)
	host._move(52, 36, 1)
	host._select_difficulty(1)
	check(not movement.busy and host.pieces[52].texture == host.textures[1] and not host.celebration.banner.visible, "Difficulty reset cancels movement and old results")
	host.session.reduced_motion = true
	host._move(52, 36, 1)
	check(not movement.busy and host.pieces[36].texture == host.textures[1], "Reduced motion places pieces immediately")
	host._select_difficulty(0)
	host.session.reduced_motion = false
	host._move(52, 36, 1)
	host.shutdown_game()
	check(not movement.busy and movement.sprites.is_empty(), "Exit cancels movement and removes travelers")
	host.queue_free()
	await process_frame
	var ai_host := Host.instantiate()
	root.add_child(ai_host)
	var context := GameSessionContext.new("chess", [], {"id": "host", "display_name": "Host"}, false)
	context.reduced_motion = true
	ai_host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	ai_host.initialize_session(context)
	ai_host.start_game()
	ai_host._move(52, 36, 1)
	await create_timer(2.1).timeout
	check(ai_host.rules.moves.size() == 2 and ai_host.rules.position.turn == 1, "The worker computer completes a legal reply and returns control")
	ai_host._move(51, 35, 1)
	ai_host._select_difficulty(2)
	await create_timer(1.6).timeout
	check(ai_host.rules.moves.is_empty(), "Difficulty reset cancels a pending worker reply")
	ai_host.rules.finish(3, "Fixture draw")
	ai_host._publish()
	ai_host._play_again()
	for attempt in 200:
		await create_timer(0.02).timeout
		if ai_host.ai_thread.is_started():
			break
	check(ai_host.ai_thread.is_started() and ai_host.rules.moves.is_empty(), "The computer prepares White's opening after replay")
	ai_host._configure_clock(73.0)
	await create_timer(2.9).timeout
	check(ai_host.rules.moves.size() == 1 and ai_host.rules.position.turn == 2 and ai_host.rules.clock_seconds == 73.0, "Clock changes invalidate and restart a computer opening without stalling or duplicating moves")
	ai_host.shutdown_game()
	ai_host.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.15).timeout
	print("Chess motion and worker: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
