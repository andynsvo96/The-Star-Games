extends SceneTree

const Host = preload("res://Games/battleship/host/main.tscn")
const PHONE := {"id": "phone", "display_name": "Captain", "color": "#2463eb"}
const OTHER := {"id": "other", "display_name": "Admiral", "color": "#e53935"}
var checks := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _host(players: Array, reduced := false) -> Node:
	var host := Host.instantiate()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var context := GameSessionContext.new("battleship", players, {"id": "host", "display_name": "Host", "color": "#2463eb"}, not players.is_empty())
	context.reduced_motion = reduced
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	for sound in host.sounds.values():
		sound.volume_db = -80
	host.start_game()
	return host


func _run() -> void:
	var host := _host([])
	host.seats[1].id = "fixture"
	host._place_ship(1, 0, 0, false)
	check(host.boards[0].poses[0].scale.x < 1 and host.boards[0].placement_left > 0, "Deploying a ship creates a shared pop and water landing")
	var placement: Tween = host.boards[0].poses[0].get_meta("game_motion")
	host._publish()
	check(host.boards[0].poses[0].get_meta("game_motion") == placement, "Duplicate publications preserve placement motion")
	await create_timer(0.65).timeout
	check(host.boards[0].poses[0].scale == Vector2.ONE and host.boards[0].placement_left == 0, "The ship settles without moving click targets")
	var board: Control = host.boards[0]
	check(board.size.y - board.field_rect().end.y >= board.size.x * 0.08 and is_equal_approx(board.field_rect().size.x, board.field_rect().size.y), "The enlarged casing encloses all ten square rows")
	var plate := Rect2(Vector2(22, 60) * board.size.x / 424, Vector2(380, 376) * board.size.x / 424)
	check(range(10).all(func(index: int) -> bool: return plate.encloses(board.coordinate_rect(index, true)) and plate.encloses(board.coordinate_rect(index, false))), "Letters and numbers occupy dedicated space inside the inner casing")
	var held_revision: int = host.rules.revision
	board.buttons[9].button_down.emit()
	await create_timer(0.5).timeout
	board.buttons[9].button_up.emit()
	board.buttons[9].pressed.emit()
	check(host.rules.revision == held_revision and host.rules.fleets[0].size() == 1 and host.selected_ship == 1 and host.vertical, "An empty-water hold rotates only the preview without placing or changing selection")
	await process_frame
	board.buttons[9].button_down.emit()
	board.buttons[9].button_up.emit()
	board.buttons[9].pressed.emit()
	check(host.rules.fleets[0].size() == 2 and host.rules.fleets[0][1].cell == 9 and host.rules.fleets[0][1].vertical, "A separate short click places the rotated preview")
	held_revision = host.rules.revision
	board.buttons[2].button_down.emit()
	await create_timer(0.5).timeout
	board.buttons[2].button_up.emit()
	board.buttons[2].pressed.emit()
	check(host.rules.revision == held_revision + 1 and host.rules.fleets[0][0].vertical and host.rules.fleets[0][0].cell == 0, "Holding an existing ship rotates around its start exactly once, without a release tap")
	check(host.rules.fleets[0].size() == 2 and host.selected_ship == 0 and board.preview == -1, "Existing-ship rotation adds no ship, keeps its selection and leaves no deployment ghost")
	board.buttons[50].button_down.emit()
	board.buttons[50].button_up.emit()
	held_revision = host.rules.revision
	await create_timer(0.5).timeout
	check(host.rules.revision == held_revision, "Releasing before the hold threshold cannot queue a rotation")
	board.buttons[50].button_down.emit()
	var drag := InputEventMouseMotion.new()
	drag.global_position = board.hold_origin + Vector2(20, 0)
	board.buttons[50].gui_input.emit(drag)
	board.buttons[50].button_up.emit()
	board.buttons[50].pressed.emit()
	await create_timer(0.5).timeout
	check(host.rules.revision == held_revision, "Dragging cancels a native hold and suppresses the release placement")
	host._setup_action(1, "auto")
	host._setup_action(1, "ready")
	await process_frame
	var before: Rect2 = host.board_frame.get_global_rect()
	host._fire(1, 99)
	check(host.animating and host.boards[0].source_cannon and host.boards[1].shot_age < 0.1, "Fire starts cannon recoil, a traveling shell and an authoritative input lock")
	check(host.fleet_consoles[0].states.size() == 5 and host.fleet_consoles[1].states == [0, 0, 0, 0, 0], "Both fleet monitors show five lamps while enemy ships remain private")
	check(host.boards[1].buttons.all(func(button: Button) -> bool: return button.disabled), "All host targets disable throughout the shot")
	var tween: Tween = host.shot_tween
	host._publish()
	check(host.shot_tween == tween, "Duplicate snapshots never restart a shot")
	var revision: int = host.rules.revision
	host._fire(2, 98)
	check(host.rules.revision == revision, "Taps during movement are discarded")
	await create_timer(0.6).timeout
	check(host.boards[1].shot_age >= 0.48 and host.animating, "Impact occurs after shell flight and remains locked through splash/explosion")
	await create_timer(0.8).timeout
	check(not host.animating and host.boards[1].shot_age >= 1.25, "Host unlocks only after the complete effect")
	# Complete the final ship to exercise delayed victory and stable replay space.
	host.rules.shots[0].fill(3)
	var final_cell: int = host.rules.fleets[1][0].cells[0]
	host.rules.shots[0][final_cell] = 0
	# Leave all non-ship cells as misses so exactly 17 segments become sunk.
	for cell in 100:
		if not host.rules.fleets[1].any(func(ship: Dictionary) -> bool: return ship.cells.has(cell)):
			host.rules.shots[0][cell] = 1
	host.rules.turn = 1
	host._fire(1, final_cell)
	check(host.rules.outcome == 1 and not host.celebration.banner.visible and host.replay_button.disabled, "Victory waits for the final impact before celebrating or replaying")
	await create_timer(1.35).timeout
	check(host.celebration.banner.visible and not host.replay_button.disabled, "The final landing starts shared victory feedback")
	check(host.fleet_consoles[1].states == [2, 2, 2, 2, 2], "Sunk enemy ships extinguish all five monitor lamps")
	check(host.board_frame.get_global_rect().position.distance_to(before.position) < 1, "Play Again appears without shifting the board")
	host._play_again()
	check(host.rules.phase == "setup" and not host.celebration.banner.visible and host.boards[0].shot.is_empty(), "Replay removes old shells, explosions and banners")
	host._setup_action(1, "auto")
	host._setup_action(1, "ready")
	host.rules.turn = 1
	host._fire(1, 50)
	host._select_difficulty(2)
	check(not host.animating and host.rules.phase == "setup" and host.boards[0].shot.is_empty(), "Difficulty changes cancel an in-flight shot")
	host.shutdown_game()
	check(host.ai_timer.is_stopped() and not host.animating and not host.screen.background_media.visible, "Exit cancels AI, effects and background playback")
	host.queue_free()
	await process_frame
	var reduced := _host([PHONE, OTHER], true)
	reduced._setup_action(1, "auto")
	reduced._setup_action(2, "auto")
	reduced._setup_action(1, "ready")
	reduced._setup_action(2, "ready")
	reduced._fire(1, 99)
	check(not reduced.animating and reduced.boards[1].shot_age == 2.0 and reduced.boards[0].placement_left == 0, "Reduced motion settles ships and shots immediately")
	reduced.shutdown_game()
	reduced.queue_free()
	await process_frame
	var reduced_solo := _host([], true)
	reduced_solo.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	reduced_solo.size = Vector2(390, 844)
	reduced_solo.seats[1].id = "fixture"
	reduced_solo._place_ship(1, 4, 9, true)
	var invalid_revision: int = reduced_solo.rules.revision
	reduced_solo._host_hold(0, 19)
	check(reduced_solo.rules.revision == invalid_revision and reduced_solo.rules.fleets[0][0].vertical, "A held ship cannot rotate through the right border")
	reduced_solo._setup_action(1, "auto")
	reduced_solo._setup_action(1, "ready")
	check(reduced_solo.screen.available_size().x < 700 and reduced_solo.view_choice.selected == 1, "Narrow hosts enter battle on the enemy fleet")
	reduced_solo._fire(1, 99)
	reduced_solo._fire(2, 98)
	check(reduced_solo.rules.turn == 1 and reduced_solo.view_choice.selected == 1, "Reduced-motion incoming fire immediately restores enemy targeting")
	reduced_solo.shutdown_game()
	reduced_solo.queue_free()
	await process_frame
	var computer := _host([])
	computer._setup_action(1, "auto")
	computer._setup_action(1, "ready")
	computer._fire(1, 40)
	await create_timer(0.8).timeout
	check(computer.rules.last_shot.seat == 1, "Computer cannot reply before the player's shell settles")
	await create_timer(1.25).timeout
	check(computer.rules.last_shot.seat == 2 and computer.animating, "Computer fires after settling and its own shell holds the lock")
	await create_timer(1.3).timeout
	check(computer.rules.turn == 1 and not computer.animating, "The computer reply settles and returns input to the player")
	computer.shutdown_game()
	computer.queue_free()
	await process_frame
	# Give the headless audio mixer time to release stopped sample playbacks.
	await create_timer(0.15).timeout
	print("Battleship motion: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
