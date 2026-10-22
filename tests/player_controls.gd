extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var app = load("res://Main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app._enter_lobby()
	await create_timer(0.7).timeout
	for card in app.lobby_roster.get_children():
		for label in card.find_children("*", "Label", true, false):
			assert(label.text.is_empty())
	assert(app.screen_root.find_children("*", "ColorPickerButton", true, false).is_empty())
	var server: LanServer = app.lan_server
	assert(LanServer.PLAYER_COLORS.size() == 16)
	for i in 16:
		var color := server._first_available_color()
		assert(not color.is_empty())
		server.active_players[str(i)] = {"id": str(i), "display_name": "Player %d" % i, "color": color, "lifetime_points": 0}
	assert(server._first_available_color().is_empty())
	assert(not server.change_player_color("0", LanServer.PLAYER_COLORS[1]))
	assert(not server.change_player_color("0", "#123456"))
	server.kick_player("1")
	assert(server.active_players.size() == 15)
	assert(server.change_player_color("0", LanServer.PLAYER_COLORS[1]))
	assert(server.color_available(LanServer.PLAYER_COLORS[0]))
	app._show_player_menu("0")
	await process_frame
	var popup: PopupMenu = app.get_child(app.get_child_count() - 1)
	assert(popup.item_count == 4)
	popup.hide()
	app._show_player_colors("0")
	await process_frame
	popup = app.get_child(app.get_child_count() - 1)
	assert(popup.item_count == 16)
	assert(popup.is_item_disabled(2))
	assert(not popup.is_item_disabled(0))
	popup.hide()
	server.active_players.clear()
	var result: Dictionary = app.profile_store.create_or_get_profile("Stats Test")
	var id: String = result["profile"]["id"]
	app.profile_store.set_game_points(id, "test-game", 42)
	app._show_player_stats(id)
	await process_frame
	var dialog: AcceptDialog = app.get_child(app.get_child_count() - 1)
	var labels := dialog.find_children("*", "Label", true, false)
	var found := false
	for label in labels:
		if label.text.contains("test-game: 42 points"):
			found = true
	assert(found)
	dialog.queue_free()
	app._leave_lobby()
	print("PASS: 16 exclusive colors, host controls, kick, empty avatars and scores")
	quit()
