extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://Main.tscn") as PackedScene
	var app := scene.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	if app.current_state != "title":
		return _finish(false, "Application did not start on the title screen")
	var buttons: Array[Node] = app.screen_root.find_children("*", "Button", true, false)
	if buttons.size() != 1 or buttons[0].text != "PLAY":
		return _finish(false, "Title should contain only the Play button")
	var play := buttons[0] as Button
	if play.get_global_rect().get_center().distance_to(app.size * Vector2(0.5, 0.75)) > 2.0:
		return _finish(false, "Play button should be horizontally centered at three-quarter height")
	if not app.screen_root.find_children("*", "Label", true, false).is_empty():
		return _finish(false, "Title should not contain text labels")
	if app.title_background.last_video.get_extension().to_lower() in app.title_background.IMAGE_EXTENSIONS:
		if app.title_background.picture.texture == null:
			return _finish(false, "Splash image did not load")
		app._show_settings("title")
		await process_frame
		app._return_from_settings()
		await process_frame
	else:
		if app.title_background.playlist.is_empty() or not app.title_background.player.is_playing():
			return _finish(false, "Supplied video did not start")
		await create_timer(0.5).timeout
		if app.title_background.player.stream_position <= 0.0:
			return _finish(false, "Background playback did not advance")
		var outgoing_texture: Texture2D = app.title_background.picture.texture
		var prepared_player: VideoStreamPlayer = app.title_background.standby
		if not app.title_background.standby_ready or not prepared_player.paused:
			return _finish(false, "Next loop should already be decoded and waiting")
		app.title_background._play_next()
		if app.title_background.picture.texture != outgoing_texture:
			return _finish(false, "Transition should keep the outgoing video visible underneath")
		if not app.title_background.blending or prepared_player.paused:
			return _finish(false, "Transition should resume the predecoded video")
		app._show_settings("title")
		await process_frame
		if not prepared_player.paused or not app.title_background.player.paused:
			return _finish(false, "Both videos should pause outside the title")
		app._return_from_settings()
		await create_timer(0.25).timeout
		if app.title_background.player != prepared_player or app.title_background.blending:
			return _finish(false, "Transition should finish using the prepared player")
	if app.current_state != "title" or app.lan_server.running:
		return _finish(false, "Title settings did not return to the inactive title screen")
	app._enter_lobby()
	await create_timer(0.7).timeout
	if app.current_state != "lobby" or not app.lan_server.running:
		return _finish(false, "Play did not enter a live lobby")
	if app.title_background.visible or not app.title_background.player.paused:
		return _finish(false, "Title background should pause in the lobby")
	app._show_settings("lobby")
	await process_frame
	if app.current_state != "settings" or not app.lan_server.running:
		return _finish(false, "Lobby settings did not preserve the LAN session")
	app._return_from_settings()
	await process_frame
	if app.current_state != "lobby":
		return _finish(false, "Settings did not return to the lobby")
	app._leave_lobby()
	await process_frame
	if app.current_state != "title" or app.lan_server.running:
		return _finish(false, "Returning to title did not stop the LAN session")
	_finish(true, "PASS: title, lobby, caller-aware settings, and server lifecycle smoke test")


func _finish(success: bool, message: String) -> void:
	print(message) if success else printerr("FAIL: %s" % message)
	quit(0 if success else 1)
