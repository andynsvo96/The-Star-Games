extends SceneTree

const Host = preload("res://Games/four-in-a-row/host/main.tscn")
var failures := 0
var snapshot: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
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
	host.initialize_session(GameSessionContext.new("four-in-a-row", [], {"id": "host", "display_name": "Host"}, false))
	host.controller_state_updated.connect(func(state: Dictionary) -> void: snapshot = state)
	host.start_game()
	await process_frame
	await process_frame
	host._preview_column(3)
	check(host.column_preview.target == 38 and host.column_preview.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Preview identifies the bottom landing slot without capturing input")
	var initial_revision: int = host.rules.revision
	host._preview_column(2)
	check(host.column_preview.target == 37 and host.rules.revision == initial_revision, "Column preview never sends a move")
	host._host_move(3)
	check(host.drop_tweens.size() == 2, "Human and AI moves each queue a drop")
	check(snapshot.animating and host.cells.all(func(cell: Button) -> bool: return cell.disabled), "Both drops lock host cells and authoritative controller state")
	check(host.column_preview.target == -1, "Landing preview disappears through all falling and bouncing")
	var revision: int = host.rules.revision
	host._host_move(2)
	check(host.rules.revision == revision and host.rules.board.count(0) == 40, "Clicks during a drop are rejected immediately")
	check(host.pieces[38].position.y < -100, "Bottom-row disc begins above its column")
	var first: Tween = host.drop_tweens[38]
	host._publish()
	check(host.drop_tweens[38] == first, "Duplicate sync preserves running animation")
	await create_timer(0.25).timeout
	check(host.pieces[38].position.y < 2 and host.pieces[38].modulate.a == 1, "Disc visibly falls before landing")
	var later := 0
	for index in host.drop_tweens:
		if index != 38 and host.pieces[index].modulate.a == 0:
			later += 1
	check(later == 1, "AI disc waits for the human landing")
	await create_timer(0.45).timeout
	check(host.drop_tweens.size() == 1 and snapshot.animating, "Input remains locked during the opponent's fall")
	host._host_move(2)
	check(host.rules.revision == revision, "A tap while the opponent falls is discarded")
	await create_timer(0.7).timeout
	check(host.drop_tweens.is_empty() and is_equal_approx(host.pieces[38].position.y, 2.0), "Drops finish at exact slot position")
	check(not snapshot.animating and host.cells.any(func(cell: Button) -> bool: return not cell.disabled), "Input unlocks only after the last bounce finishes")
	host._preview_column(3)
	check(host.column_preview.target >= 0 and host.rules.board[host.column_preview.target] == 0, "Settled preview points to an empty authoritative slot")
	check(host.rules.revision == revision, "Rejected clicks are never replayed after landing")
	host._host_move(2)
	host._select_difficulty(0)
	check(host.drop_tweens.is_empty() and host.pieces.all(func(piece: TextureRect) -> bool: return piece.position.y == 2.0 and piece.modulate.a == 1), "Reset cancels movement and restores transforms")
	host.session.reduced_motion = true
	host._host_move(3)
	check(host.drop_tweens.is_empty() and host.pieces[38].position.y == 2.0, "Reduced motion places instantly")
	host._select_difficulty(1)
	host.session.reduced_motion = false
	host.seats[1].id = "opponent"
	for column in [0, 6, 1, 6, 2, 5]:
		host._move(column, host.rules.turn)
		host._clear_drops()
	host._move(3, 1)
	check(host.celebration.lines.is_empty() and host.victory_tween.is_valid(), "Winning strike waits for landing")
	await create_timer(0.8).timeout
	check(not host.celebration.lines.is_empty() and host.drop_tweens.is_empty(), "Win celebration follows landing")
	host._next_round()
	host._move(0, host.rules.turn)
	host.shutdown_game()
	check(host.drop_tweens.is_empty(), "Exit cancels unfinished drops")
	host.queue_free()
	await process_frame
	var phones = Host.instantiate()
	root.add_child(phones)
	var players: Array = [{"id": "one", "display_name": "One"}, {"id": "two", "display_name": "Two"}]
	phones.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	phones.initialize_session(GameSessionContext.new("four-in-a-row", players, {}, true))
	phones.start_game()
	phones.handle_controller_message("one", {"action": "move", "column": 0, "revision": phones.rules.revision})
	revision = phones.rules.revision
	phones.handle_controller_message("two", {"action": "move", "column": 1, "revision": revision})
	check(phones.rules.revision == revision and phones.rules.board.count(0) == 41, "Host rejects even a current-revision phone move during opponent animation")
	await create_timer(0.8).timeout
	phones.handle_controller_message("two", {"action": "move", "column": 1, "revision": revision})
	check(phones.rules.board.count(0) == 40, "Phone move is accepted after the opponent settles")
	phones.shutdown_game()
	phones.queue_free()
	await process_frame
	print("Four in a Row motion: %d failures" % failures)
	quit(0 if failures == 0 else 1)
