extends SceneTree

var output := "res://.test_data/spyfall-visual/"
var failures := 0
var app: Control
var clients: Array = []


func _init() -> void:
	call_deferred("_run")


func capture(name: String) -> void:
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + name + ".png")


func resize_view(width: int, height: int) -> void:
	root.min_size = Vector2i(1, 1)
	root.content_scale_size = Vector2i(width, height)
	root.size = Vector2i(width, height)
	for frame in 10:
		await process_frame


func check_result_layout(host: Control) -> void:
	var dialog: Dictionary = host.voting_dialog
	if dialog.scroll.size.y - dialog.body.get_combined_minimum_size().y > 2.0:
		failures += 1
		printerr("FAIL: Result leaves empty space between its content and replay")
	if not root.get_visible_rect().encloses(dialog.panel.get_global_rect()) or not root.get_visible_rect().encloses(host.replay.get_global_rect()):
		failures += 1
		printerr("FAIL: Result popup or replay exceeds the viewport")


func check_host_columns(host: Control) -> void:
	var roster: Control = host.roster_rows[0].content.get_parent().get_parent()
	var timer_rect: Rect2 = host.dossier.get_global_rect()
	var roster_rect := roster.get_global_rect()
	var history_rect: Rect2 = host.history_log.get_parent().get_meta("outer_panel").get_global_rect()
	if host.find_children("*", "Button", true, false).any(func(button: Button) -> bool: return button.text.begins_with("HISTORY")):
		failures += 1
		printerr("FAIL: Permanent history must not have a toggle")
	if roster_rect.position.y < timer_rect.end.y or not roster_rect.encloses(host.roster_rows[0].content.get_global_rect()):
		failures += 1
		printerr("FAIL: Players must sit below the timer and history row")
	if history_rect.position.x <= timer_rect.end.x or not is_equal_approx(history_rect.position.y, timer_rect.position.y) or not host.history_log.is_visible_in_tree():
		failures += 1
		printerr("FAIL: Permanent clipboard history must sit to the right of the timer")


func joined(name: String) -> WebSocketPeer:
	var socket := WebSocketPeer.new()
	socket.connect_to_url("ws://127.0.0.1:%d/" % app.lan_server.websocket_port)
	var sent := false
	for frame in 300:
		socket.poll()
		while socket.get_available_packet_count() > 0:
			var packet: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if packet.get("type") == "hello" and not sent:
				socket.send_text(JSON.stringify({"type":"join", "name":name}))
				sent = true
			if packet.get("type") == "joined":
				return socket
		await process_frame
	failures += 1
	return socket


func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var input := InputEventMouseButton.new()
		input.position = point
		input.global_position = point
		input.button_index = MOUSE_BUTTON_LEFT
		input.pressed = pressed
		root.push_input(input)
		await create_timer(0.12).timeout


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	await resize_view(1280, 720)
	app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new(output + "profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	for seat in 8:
		clients.append(await joined("Visual Agent %d" % (seat + 1)))
	app._play_from_lobby()
	await capture("catalog-list")
	app._set_game_view("icons")
	await capture("catalog-icons")
	var module: Dictionary = app.game_catalog.games.filter(func(game: Dictionary) -> bool: return game.id == "spyfall")[0]
	app._launch_game(module)
	var host = app.active_game
	host.settings = load("res://Games/spyfall/host/settings.gd").new(output + "settings.json")
	await capture("playing-desktop")
	check_host_columns(host)
	await resize_view(390, 844)
	await capture("playing-portrait")
	await resize_view(844, 390)
	await capture("playing-landscape")
	await resize_view(1280, 720)
	var settings_button: Button = host.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.text.begins_with("SETTINGS"))[0]
	await click(settings_button)
	await capture("settings-desktop")
	await click(settings_button)
	var locations_button: Button = host.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.text.begins_with("EDIT LOCATIONS"))[0]
	await click(locations_button)
	await capture("locations-desktop")
	host.location_input.text = "Observatory"
	host._add_location()
	host.location_remove_buttons[0].pressed.emit()
	for frame in 10:
		await process_frame
	host.screen.content_scroll.ensure_control_visible(host.save_locations_button)
	for frame in 10:
		await process_frame
	await capture("locations-save-desktop")
	await click(host.save_locations_button)
	if host.rules.phase != "playing" or not host.rules.locations.has("Observatory") or not host.save_locations_button.disabled:
		failures += 1
		printerr("FAIL: Rendered host Save did not save and immediately restart")
	await capture("locations-saved-desktop")
	host.screen.content_scroll.ensure_control_visible(locations_button)
	for frame in 10:
		await process_frame
	await click(locations_button)
	host.screen.content_scroll.scroll_vertical = 0
	host._publish()
	await capture("conversation-desktop")
	host.session.reduced_motion = false
	host.rules.timer_started = true
	host.rules.remaining = 10
	host._publish()
	await capture("countdown-desktop")
	host.session.reduced_motion = true
	host.rules.remaining = 9
	host._publish()
	await capture("countdown-reduced")
	if host.timer_label.scale != Vector2.ONE:
		failures += 1
	host.rules.remaining = host.rules.duration
	var accuser: int = (host.rules.spy + 1) % 8
	host.rules.accuse(accuser, host.rules.spy)
	host._publish()
	await capture("vote-desktop")
	host.rules.vote_remaining = 10
	host._publish()
	await capture("vote-countdown-desktop")
	host.rules.vote((accuser + 1) % 8 if (accuser + 1) % 8 != host.rules.spy else (accuser + 2) % 8, false)
	host.rules.tick(host.rules.duration)
	for seat in 4:
		host.rules.final_vote(seat, (seat + 1) % 8)
	host._publish()
	await capture("final-vote-desktop")
	await resize_view(390, 844)
	await capture("final-vote-portrait")
	await resize_view(844, 390)
	await capture("final-vote-landscape")
	host.rules.anonymous_voting = true
	host.rules.revision += 1
	host._publish()
	await capture("final-vote-anonymous")
	for seat in range(4, 8):
		host.rules.final_vote(seat, (seat + 1) % 8)
	host._record_result()
	host._publish()
	await resize_view(1280, 720)
	await capture("result-desktop")
	check_result_layout(host)
	await resize_view(390, 844)
	await capture("result-portrait")
	check_result_layout(host)
	await resize_view(844, 390)
	await capture("result-landscape")
	check_result_layout(host)
	var panel: Control = host.voting_dialog.panel
	if not root.get_visible_rect().encloses(panel.get_global_rect()) or not root.get_visible_rect().has_point(host.replay.get_global_rect().get_center()):
		failures += 1
		printerr("FAIL: Phase popup or replay exceeds the landscape viewport")
	await click(host.replay)
	if host.rules.phase != "playing" or host.voting_dialog.overlay.visible or not host.dossier.visible:
		failures += 1
	# Show the complete seven-person civilian team using the same result layout.
	host.rules.finish(false, "caught")
	host._publish()
	for view in [[1280, 720, "desktop"], [390, 844, "portrait"], [844, 390, "landscape"]]:
		await resize_view(view[0], view[1])
		await capture("civilian-result-" + view[2])
		check_result_layout(host)
		if not root.get_visible_rect().encloses(host.voting_dialog.panel.get_global_rect()) or host.result_team.get_child_count() != 7:
			failures += 1
	await click(host.replay)
	await resize_view(390, 844)
	host.screen.content_scroll.ensure_control_visible(locations_button)
	for frame in 10:
		await process_frame
	await click(locations_button)
	for frame in 10:
		await process_frame
	host.screen.content_scroll.scroll_vertical = int(host.screen.content_scroll.get_v_scroll_bar().max_value)
	await capture("locations-portrait")
	await resize_view(844, 390)
	host.screen.content_scroll.ensure_control_visible(host.save_locations_button)
	for frame in 10:
		await process_frame
	if not root.get_visible_rect().has_point(host.save_locations_button.get_global_rect().get_center()):
		failures += 1
		printerr("FAIL: Location Save is unreachable in landscape")
	await capture("locations-landscape")
	await resize_view(390, 844)
	await click(locations_button)
	await capture("replay-portrait")
	for button in host.find_children("*", "Button", true, false):
		if not button.tooltip_text.is_empty():
			failures += 1
		if button.text.begins_with("HOW TO PLAY") or button.text.begins_with("SESSION & HISTORY"):
			failures += 1
	for client in clients:
		client.close()
	clients.clear()
	app.lan_server.stop_server()
	app.queue_free()
	await process_frame
	# Short four-player results must shrink as well as the full eight-player lineup.
	host = load("res://Games/spyfall/host/main.tscn").instantiate()
	host.settings = load("res://Games/spyfall/host/settings.gd").new(output + "four-player-settings.json")
	root.add_child(host)
	var players: Array = []
	for seat in 4:
		players.append({"id": "p%d" % seat, "display_name": ["Andy", "Jack", "John", "Tony"][seat], "color": ["#008000", "#202020", "#ffffff", "#ff0000"][seat], "pose": seat})
	var context := GameSessionContext.new("spyfall", players, {}, true)
	context.reduced_motion = true
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	host.start_game()
	await resize_view(1280, 720)
	await capture("four-player-host")
	check_host_columns(host)
	for spy_wins in [true, false]:
		host.rules.finish(spy_wins, "guessed" if spy_wins else "caught")
		host._publish()
		for view in [[1280, 720, "desktop"], [390, 844, "portrait"], [844, 390, "landscape"]]:
			await resize_view(view[0], view[1])
			await capture("four-player-%s-%s" % ["spy" if spy_wins else "civilian", view[2]])
			check_result_layout(host)
		await click(host.replay)
		if host.rules.phase != "playing" or host.voting_dialog.overlay.visible:
			failures += 1
	host.shutdown_game()
	host.queue_free()
	await process_frame
	print("Spyfall visual: %d failures; captures in %s" % [failures, output])
	quit(0 if failures == 0 else 1)
