extends SceneTree

var checks := 0
var failures := 0
var output := "res://.test_data/quoridor-visual/"


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func capture(name: String) -> void:
	for frame in 12:
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output + name + ".png")


func _resize(width: int, height: int) -> void:
	root.min_size = Vector2i(1, 1)
	root.content_scale_size = Vector2i(width, height)
	root.size = Vector2i(width, height)
	for frame in 10:
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	await _resize(1280, 720)
	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new(output + "profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	app._play_from_lobby()
	await capture("catalog")
	var module: Dictionary = app.game_catalog.games.filter(func(game: Dictionary) -> bool: return game.id == "quoridor")[0]
	check(app._can_launch(module), "Real catalog launches solo Quoridor")
	app._launch_game(module)
	var host = app.active_game
	for sound in host.sounds.values():
		sound.volume_db = -80
	await capture("host")
	check(host.board.get_global_rect().get_center().distance_to(app.size / 2) < 2, "Shared foundation centers the square board")
	check(host.move_button.icon != null and host.wall_button.icon != null and host.score_cards[0].presentation == "ornate", "Illustrated controls and ornate stats use the shared foundation")
	host.rules.walls = [{"row": 3, "col": 3, "orientation": "h", "side": 1}, {"row": 5, "col": 1, "orientation": "v", "side": 2}]
	host.rules.remaining = [9, 9]
	host.rules.revision += 1
	host._publish()
	await capture("walls")
	var wall_rect: Rect2 = host.board._wall_rect(host.rules.walls[0])
	check(wall_rect.size.y >= host.board._geometry().y * 0.29, "Placed walls are raised bars clearly wider than the board grooves")
	host._set_wall_mode(true)
	check(host.board.anchors[3 * 8 + 3].disabled, "Blocked wall junction is greyed out and rejects placement")
	await capture("blocked-walls")
	host._set_wall_mode(false)
	host.rules.remaining[0] = 0
	host.rules.revision += 1
	host._publish()
	await capture("walls-disabled")
	var disabled_style: StyleBoxFlat = host.wall_button.get_theme_stylebox("disabled")
	check(host.wall_button.disabled and disabled_style.bg_color == GameLook.DISABLED_FILL and host.wall_button.icon == host.wall_button.get_meta("game_disabled_icon"), "Empty wall stock uses an opaque grey control and icon")
	host._set_wall_mode(true)
	check(not host.wall_mode, "Grey Wall control cannot enable placement")
	host.rules.walls = []
	host.rules.remaining = [10, 10]
	host.rules.revision += 1
	host._publish()
	var opening: Rect2 = host.board.get_global_rect()
	host._set_wall_mode(true)
	host._host_anchor(3, 3)
	await capture("wall-preview")
	check(not host.preview.is_empty() and not host.confirm_button.disabled, "Wall preview has an explicit reachable confirmation")
	check(host.board.get_global_rect().position.distance_to(opening.position) < 1 and host.board.size.distance_to(opening.size) < 1, "Wall confirmation reserves space without shifting or shrinking the board")
	host._rotate()
	await capture("wall-vertical")
	host._set_wall_mode(false)
	for shape in [Vector2i(480, 850), Vector2i(850, 480), Vector2i(1920, 1080)]:
		await _resize(shape.x, shape.y)
		host._set_wall_mode(true)
		host._host_anchor(3, 3)
		await capture("active-%dx%d" % [shape.x, shape.y])
		check(host.controls.get_global_rect().end.y <= app.size.y and host.controls.get_global_rect().end.x <= app.size.x and host.confirm_button.get_global_rect().end.y <= app.size.y, "Move/Wall/Rotate/Place fit %dx%d" % [shape.x, shape.y])
		host._set_wall_mode(false)
	await _resize(1280, 720)
	var before: Rect2 = host.board.get_global_rect()
	host.rules.pawns = [9, 71]
	host.rules.revision += 1
	host._publish()
	host._host_cell(0)
	await capture("victory")
	check(host.replay_button.visible and host.replay_button.get_global_rect().end.y <= app.size.y and host.board.get_global_rect().position.distance_to(before.position) < 1, "Replay remains visible without shifting the board")
	for shape in [Vector2i(480, 850), Vector2i(850, 480), Vector2i(1920, 1080)]:
		await _resize(shape.x, shape.y)
		await capture("host-%dx%d" % [shape.x, shape.y])
		check(host.board.get_global_rect().end.x <= app.size.x + 1 and host.board.get_global_rect().end.y <= app.size.y and host.replay_button.get_global_rect().end.y <= app.size.y, "Board and replay fit %dx%d" % [shape.x, shape.y])
	check(host.board.cells.all(func(button: Button) -> bool: return button.tooltip_text.is_empty()), "Board controls omit hover popups")
	await _resize(1280, 720)
	host._select_players(1)
	host._apply_settings()
	await capture("four-player")
	check(host.rules.remaining == [5, 5, 5, 5] and host.board.visuals.all(func(pawn: Control) -> bool: return pawn.visible), "Four-player host displays four pawns and five walls each")
	check(host.score_cards.all(func(card: Dictionary) -> bool: return card.panel.visible and card.compact), "All four score cards use shared compact presentation")
	for shape in [Vector2i(480, 850), Vector2i(850, 480), Vector2i(1920, 1080)]:
		await _resize(shape.x, shape.y)
		await capture("four-player-%dx%d" % [shape.x, shape.y])
		check(host.board.get_global_rect().get_center().distance_to(app.size / 2) < 2, "Four-player board stays centered at %dx%d" % [shape.x, shape.y])
		var settings: Button = host.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.text.begins_with("SETTINGS"))[0]
		settings.button_pressed = true
		await capture("four-settings-%dx%d" % [shape.x, shape.y])
		check(host.player_choice.is_visible_in_tree() and host.computer_choice.is_visible_in_tree() and host.host_toggle.is_visible_in_tree() and host.apply_button.is_visible_in_tree(), "Host lineup settings remain reachable at %dx%d" % [shape.x, shape.y])
		settings.button_pressed = false
	await _resize(1280, 720)
	check(host.score_cards.all(func(card: Dictionary) -> bool: return root.get_visible_rect().encloses(card.panel.get_global_rect())), "Four compact host cards fit on desktop")
	host.rules.pawns = [67, 37, 13, 46]
	host.rules.turn = 4
	host.rules.move(45, 4)
	host._publish()
	await capture("four-victory")
	check(host.replay_button.visible and host.rules.session_wins == [0, 0, 0, 1], "Fourth-seat victory restores all cards and replay")
	host.return_to_lobby()
	await process_frame
	check(app.current_state == "game_menu" and app.active_game == null and app.lan_server.running, "Rendered launcher returns cleanly to Games")
	app.lan_server.stop_server()
	app.queue_free()
	await process_frame
	print("Quoridor visual: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
