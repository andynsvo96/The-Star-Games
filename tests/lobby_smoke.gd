extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var app = load("res://Main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.profile_store.data["settings"]["reduced_motion"] = false
	app._enter_lobby()
	assert(app.entering_lobby and app.current_state == "title")
	var transition: Tween = app.title_transition
	app._enter_lobby()
	assert(app.title_transition == transition)
	await create_timer(0.12).timeout
	assert(app.title_background.visible and app.title_background.modulate.a < 1.0)
	await create_timer(0.6).timeout
	assert(not app.entering_lobby and app.current_state == "lobby")
	assert(not app.title_background.visible and app.screen_root.modulate.a == 1.0)
	assert(app.screen_root.position == Vector2.ZERO)
	assert(app.lobby_roster.columns == 4 and app.lobby_roster.get_child_count() == 16)
	assert(app.lan_server.lobby_open)
	for button in app.screen_root.find_children("*", "Button", true, false):
		assert(button.text != "SCAN FOR GAMES")
	var players: Array = []
	for i in 16:
		players.append({"id": str(i), "display_name": "Player %02d" % (i + 1), "color": LanServer.PLAYER_COLORS[i % 16], "pose": i % 6})
	app.lan_server.active_players[players[0].id] = players[0].duplicate(true)
	app._on_roster_changed(players)
	await process_frame
	await process_frame
	for card in app.lobby_roster.get_children():
		assert(card.get_global_rect().end.y <= app.size.y)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.test_data/lobby.png")
	app._play_from_lobby()
	await process_frame
	assert(app.current_state == "game_menu" and not app.lan_server.lobby_open)
	assert(app.lobby_game_list.get_child_count() > 0)
	app._set_game_view("list")
	var view_toggle: Button = app.game_view_toggle
	view_toggle.pressed.emit()
	for frame in 4:
		await process_frame
	assert(app.lobby_game_list.columns > 1 and view_toggle.button_pressed and view_toggle.text == "View: Icons")
	assert(app.profile_store.get_settings().game_view == "icons")
	view_toggle.pressed.emit()
	await process_frame
	assert(app.lobby_game_list.columns == 1 and not view_toggle.button_pressed and view_toggle.text == "View: List")
	assert(app.game_view_toggle == view_toggle, "One button switches both views")
	app.game_catalog.games_root = "res://tests/fixtures/Games"
	await create_timer(5.1).timeout
	assert(app.game_catalog.games.size() == 1)
	assert(app.lobby_game_list.get_child_count() == 1)
	app._show_settings("game_menu")
	await process_frame
	app._return_from_settings()
	await process_frame
	assert(app.current_state == "game_menu" and not app.lan_server.lobby_open)
	assert(app.game_view == "list" and app.game_view_toggle.text == "View: List")
	app._show_lobby()
	await process_frame
	assert(app.lan_server.lobby_open)
	assert(is_instance_valid(app.lobby_avatars[players[0].id]), "Returning rebuilds the admitted player's freed lobby avatar")
	app._leave_lobby()
	assert(app.title_background.visible and app.title_background.modulate.a == 1.0)
	app.profile_store.data["settings"]["reduced_motion"] = true
	app._enter_lobby()
	assert(app.current_state == "lobby" and not app.entering_lobby)
	app._leave_lobby()
	print("PASS: 4x4 grid, list/icons selection, settings lock and lobby reopening")
	quit()
