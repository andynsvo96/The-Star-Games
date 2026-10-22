extends SceneTree

var failures := 0
var checks := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func check_center(app: Control, message: String) -> void:
	var panel: Control = app.screen_root.get_child(0).get_child(0)
	var expected := app.get_global_rect().get_center()
	var actual := panel.get_global_rect().get_center()
	check(actual.distance_to(expected) < 2.0, "%s (%s / %s)" % [message, actual, expected])
	check(app.screen_root.position.is_equal_approx(Vector2.ZERO), "Entrance animation settles the screen after " + message)


func _run() -> void:
	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new("res://.test_data/lobby_layout.json")
	root.add_child(app)
	await process_frame
	app.game_view = "list"
	app.profile_store.data.settings.reduced_motion = false
	app._enter_lobby()
	await create_timer(0.7).timeout
	check_center(app, "Joining lobby is centered before any input")
	var players: Array = []
	for index in 16:
		players.append({"id": str(index), "display_name": "Player %02d" % (index + 1), "color": LanServer.PLAYER_COLORS[index], "pose": index % 6})
	app._on_roster_changed(players)
	await create_timer(0.35).timeout
	check_center(app, "Joining lobby stays centered as players arrive")
	app._play_from_lobby()
	await create_timer(0.35).timeout
	check_center(app, "List selection is centered before toggling")
	check(app.game_view == "list" and app.lobby_game_list.columns == 1, "First game selection retains List view")
	app.game_view_toggle.pressed.emit()
	await process_frame
	await process_frame
	check_center(app, "Toggling to Icons preserves the center")
	var icons_rect: Rect2 = app.screen_root.get_child(0).get_child(0).get_global_rect()
	app._show_settings("game_menu")
	await create_timer(0.35).timeout
	app._return_from_settings()
	await create_timer(0.35).timeout
	check_center(app, "Saved Icons selection is centered without another toggle")
	check(app.game_view == "icons" and app.lobby_game_list.columns > 1, "Navigation restores Icons view")
	check(app.screen_root.get_child(0).get_child(0).get_global_rect().is_equal_approx(icons_rect), "First-open and toggled Icons layouts match")
	app._show_lobby()
	await create_timer(0.05).timeout
	app._play_from_lobby()
	await create_timer(0.05).timeout
	app._show_settings("game_menu")
	await create_timer(0.05).timeout
	app._return_from_settings()
	await create_timer(0.35).timeout
	check_center(app, "Rapid navigation cancels old screen movement")
	app._show_lobby()
	await create_timer(0.35).timeout
	check_center(app, "Returning to the joining lobby remains centered")
	app._leave_lobby()
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	for frame in 4:
		await process_frame
	check_center(app, "Reduced-motion lobby is centered")
	app._play_from_lobby()
	for frame in 4:
		await process_frame
	check_center(app, "Reduced-motion selection is centered")
	app.profile_store.data.settings.reduced_motion = false
	for viewport_size in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		app._show_lobby()
		await create_timer(0.05).timeout
		root.size = viewport_size
		root.content_scale_size = viewport_size
		app._on_roster_changed(players)
		await create_timer(0.35).timeout
		check_center(app, "Lobby centers after resizing and roster changes during entry at %s" % viewport_size)
		app._play_from_lobby()
		await create_timer(0.35).timeout
		check_center(app, "Game selection centers on first entry at %s" % viewport_size)
	app._leave_lobby()
	app.queue_free()
	await process_frame
	print("Lobby layout: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
