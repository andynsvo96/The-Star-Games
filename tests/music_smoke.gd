extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(30).timeout.connect(func() -> void: printerr("FAIL: music smoke watchdog"); quit(1))
	var folder := "res://.test_data/music-smoke-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(folder.path_join("songs"))
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = 8000
	var samples := PackedByteArray()
	samples.resize(80000)
	samples.fill(128)
	audio.data = samples
	for index in 4:
		assert(audio.save_to_wav(folder.path_join("songs/track%d.wav" % index)) == OK)
	var app := (load("res://Main.tscn") as PackedScene).instantiate()
	app.profile_store = ProfileStore.new(folder.path_join("profiles.json"))
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	app.game_catalog = GameCatalog.new("res://tests/fixtures/Games")
	root.add_child(app)
	await process_frame
	await process_frame
	var music = app.menu_music
	music.song_dir = folder.path_join("songs")
	music.reload_assets()
	assert(music.playlist.size() == 4, "Synthetic songs load without local media or FFmpeg")
	for source in music.playlist:
		assert(music.playable_paths[source] == source, "Native audio uses the original file")
	assert(music.player.playing and music.player.bus == "Music")
	var cycle: Array[String] = [music.history.back()]
	for index in 3:
		music.player.finished.emit()
		assert(not cycle.has(music.history.back()), "No repeats within a shuffle")
		cycle.append(music.history.back())
	var last: String = music.history.back()
	music.next.pressed.emit()
	assert(music.history.back() != last, "No immediate repeat across cycles")
	var next_song: String = music.history.back()
	music.previous.pressed.emit()
	assert(music.history[music.history_index] == last)
	music.next.pressed.emit()
	assert(music.history[music.history_index] == next_song)
	music.toggle.pressed.emit()
	assert(music.player.stream_paused and music.toggle.icon == music.icons["play"])
	music.next.pressed.emit()
	assert(music.player.stream_paused, "Skipping should preserve pause")
	var before_lobby: String = music.history[music.history_index]
	app._show_lobby()
	assert(music.player.stream_paused and music.visible)
	assert(music.history[music.history_index] == before_lobby, "Entering the lobby preserves the song and manual pause")
	app._show_settings("lobby")
	app._return_from_settings()
	assert(music.history[music.history_index] == before_lobby and music.player.stream_paused, "Host settings preserves a manually paused menu song")
	music.toggle.pressed.emit()
	assert(not music.player.stream_paused and music.toggle.icon == music.icons["pause"])
	var stream: AudioStream = music.player.stream
	app.current_state = "game"
	app._replace_screen()
	assert(music.player.stream_paused and not music.visible)
	app._show_title()
	assert(not music.player.stream_paused and music.player.stream != stream, "Returning to the splash screen starts a new song")
	for destination in [app._show_lobby, app._show_game_menu, app._show_title]:
		var previous_song: String = music.history[music.history_index]
		var previous_history: Array = music.history.duplicate()
		stream = music.player.stream
		music.player.seek(2.0)
		await create_timer(0.1).timeout
		assert(music.player.get_playback_position() >= 2.0)
		destination.call()
		assert(music.history[music.history_index] == previous_song and music.history == previous_history, "The title, lobby, and game selection share one shuffle session")
		assert(music.player.stream == stream and music.player.get_playback_position() >= 2.0, "Menu navigation preserves playback without restarting")
		var caller: String = app.current_state
		app._show_settings(caller)
		assert(music.active and music.player.stream == stream and not music.player.stream_paused, "Opening Host Settings keeps menu music playing")
		app._return_from_settings()
		assert(app.current_state == caller and music.history == previous_history, "Returning from Host Settings preserves the menu shuffle")
		assert(music.player.stream == stream and music.player.get_playback_position() >= 2.0, "Returning from Host Settings preserves playback position")
		if app.current_state == "game_menu":
			var selection_stream: AudioStream = music.player.stream
			app._set_game_view("icons")
			app._set_game_view("list")
			app._scan_games()
			app._on_roster_changed([])
			assert(music.player.stream == selection_stream, "Game selection controls and catalog/roster refreshes keep the current song")
	stream = music.player.stream
	music.player.seek(2.0)
	await create_timer(0.1).timeout
	app._show_title()
	assert(music.player.stream == stream and music.player.get_playback_position() >= 2.0, "Rebuilding the current screen must not restart music")
	app._show_settings("title")
	assert(music.player.stream == stream, "Opening settings preserves the current menu song")
	app._return_from_settings()
	assert(music.player.stream == stream and music.player.get_playback_position() >= 2.0, "Returning to the splash screen from settings keeps the current song")
	music.trigger.mouse_entered.emit()
	await process_frame
	assert(music.panel.visible)
	await create_timer(0.25).timeout
	assert(is_equal_approx(music.panel.modulate.a, 1.0), "Reveal should finish fully visible")
	assert(music.panel.size.y <= 44.0, "Player should remain a compact single row")
	assert(music.panel.tooltip_text.is_empty(), "Song title must not be duplicated in a tooltip")
	assert(music.panel.get_global_rect().end.x <= app.size.x)
	assert(music.previous.global_position.x < music.toggle.global_position.x)
	assert(music.toggle.global_position.x < music.next.global_position.x)
	music.song_title.text = "A deliberately very long song title to verify scrolling within the music menu"
	music.song_title.size = music.song_title.get_minimum_size()
	music.hide_elapsed = -100.0
	music._process(3.0)
	assert(music.song_title.position.x < 0.0)
	music.reduced_motion = true
	music._process(0.1)
	assert(music.song_title.position.x == 0.0)
	music.reduced_motion = false
	music._dismiss()
	await create_timer(0.2).timeout
	assert(not music.panel.visible, "Dismiss animation should hide the player")
	music._reveal()
	await create_timer(0.25).timeout
	assert(music.panel.visible and is_equal_approx(music.panel.modulate.a, 1.0))
	music._play_current()
	var saved_volume: float = app.profile_store.get_settings()["music_volume"]
	music.volume_dragging = true
	music._process(0.01)
	assert(music.volume_slider.visible, "Volume control must stay available while dragging")
	music.volume_slider.value = 0.37
	var restored := ProfileStore.new(app.profile_store.data_path)
	assert(restored.load_data())
	assert(is_equal_approx(float(restored.get_settings()["music_volume"]), 0.37), "Music volume must be saved to disk")
	var music_bus := AudioServer.get_bus_index("Music")
	assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(music_bus)), 0.37))
	music.volume_slider.value = 0.0
	assert(AudioServer.is_bus_mute(music_bus), "Zero volume must mute music")
	app._save_setting("music_volume", saved_volume)
	assert(is_equal_approx(music.volume_slider.value, saved_volume), "Settings and hover volume must stay in sync")
	if DisplayServer.get_name() != "headless":
		await create_timer(0.5).timeout
		music._reveal()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.test_data/music_menu.png")
	music.volume_dragging = false
	music._dismiss(true)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.test_data/music_icon.png")
	if not await _check_game_entries(app, folder):
		app.queue_free()
		quit(1)
		return
	for controller in [app.menu_music, app.game_music]:
		controller.player.stop()
		controller.player.stream = null
	await create_timer(0.1).timeout
	print("PASS: music shuffle, continuous menus/settings, fresh game boundaries, history, pause, empty/single-song libraries, controls, and marquee")
	app.queue_free()
	await process_frame
	quit()


func _check_game_entries(app: Control, folder: String) -> bool:
	var music = app.game_music
	var menu = app.menu_music
	music.song_dir = folder.path_join("songs")
	music.reload_assets()
	assert(music.history.is_empty() and music.player.stream == null, "Inactive game music must not consume the shuffle before the first entry")
	var host := BaseGame.new()
	var scene := PackedScene.new()
	assert(scene.pack(host) == OK)
	assert(ResourceSaver.save(scene, folder.path_join("host.tscn")) == OK)
	host.free()
	var game := {"id": "music-test", "host_scene_path": folder.path_join("host.tscn"), "modes": ["singleplayer"], "min_players": 1, "max_players": 1}
	var cycle: Array[String] = []
	for entry in 4:
		var previous_menu: String = menu.history[menu.history_index]
		menu.player.seek(2.0)
		if entry == 2:
			menu.toggle_pause()
		app._launch_game(game)
		assert(app.active_game != null and music.active and music.visible)
		assert(music.player.playing and not music.player.stream_paused)
		assert(not app.menu_music.active and app.menu_music.player.stream_paused)
		var current: String = music.history[music.history_index]
		assert(not cycle.has(current), "Repeated game entries draw without repeats until every song has played")
		cycle.append(current)
		assert(music.player.get_playback_position() < 0.5, "Each game entry starts its song at the beginning")
		music.player.seek(2.0)
		await create_timer(0.1).timeout
		assert(music.player.get_playback_position() >= 2.0)
		music.set_active(true)
		assert(music.history[music.history_index] == current, "Ordinary activation must not skip songs")
		if entry == 0:
			var screen := GameScreen.new()
			app.active_game.add_child(screen)
			screen.configure("Music test")
			screen.use_playful_style()
			var settings: VBoxContainer = screen.add_corner_details(["Host Settings"], Callable(), false, false, false, true, true)[0]
			var dock_button: Button = settings.get_meta("toggle_button")
			dock_button.get_parent().z_index = 2
			var music_reduced_motion: bool = music.reduced_motion
			music.reduced_motion = true
			music._reveal()
			await process_frame
			assert(music.z_index > dock_button.get_parent().z_index and music.panel.get_global_rect().intersects(dock_button.get_global_rect()), "The expanded music player renders above an overlapping raised game Settings dock")
			var toggle_point: Vector2 = music.toggle.get_global_rect().get_center()
			var pointer := InputEventMouseMotion.new()
			pointer.position = toggle_point
			pointer.global_position = toggle_point
			root.push_input(pointer, true)
			await process_frame
			assert(root.gui_get_hovered_control() == music.toggle, "The visible music button receives pointer input above game Settings: %s, target %s, viewport %s" % [root.gui_get_hovered_control(), toggle_point, root.get_visible_rect()])
			music._dismiss(true)
			music.reduced_motion = music_reduced_motion
			var game_stream: AudioStream = music.player.stream
			var game_history: Array = music.history.duplicate()
			for paused in [false, true]:
				if paused: music.toggle_pause()
				var settings_button: Button = settings.get_meta("toggle_button")
				settings_button.button_pressed = true
				await process_frame
				assert(settings.is_visible_in_tree() and music.active and not menu.active, "In-game Host Settings stays in the game music session")
				(settings.get_meta("settings_close") as Button).pressed.emit()
				assert(not settings.is_visible_in_tree(), "In-game Host Settings closes normally")
				assert(music.player.stream == game_stream and music.history == game_history, "Opening and closing in-game Host Settings preserves the song and shuffle")
				assert(music.player.get_playback_position() >= 2.0 and music.player.stream_paused == paused, "In-game Host Settings preserves playback position and manual pause")
			music.toggle_pause()
		app._return_from_game()
		assert(not music.active and music.player.stream_paused)
		assert(app.menu_music.active)
		assert(menu.history[menu.history_index] != previous_menu, "Exiting a game starts a new shuffled menu song")
		assert(menu.player.get_playback_position() < 0.5, "Returning from a game starts menu music at the beginning")
		assert(menu.player.stream_paused == (entry == 2), "Manual menu pause survives a game and the fresh song on exit")
		if entry == 2:
			menu.toggle_pause()
		await process_frame
	app._launch_game(game)
	assert(music.history[music.history_index] != cycle.back(), "Shuffle rollover avoids the song heard on the previous visit")
	var first: String = music.history[music.history_index]
	music.next.pressed.emit()
	var forward: String = music.history[music.history_index]
	music.previous.pressed.emit()
	assert(music.history[music.history_index] == first)
	music.toggle_pause()
	app._return_from_game()
	await process_frame
	app._launch_game(game)
	assert(music.history[music.history_index] not in [first, forward], "Reentry draws a fresh shuffled song instead of replaying forward history")
	assert(music.user_paused and music.player.stream_paused, "Manual pause survives selecting a fresh song")
	music.toggle_pause()
	assert(not music.player.stream_paused and music.player.get_playback_position() < 0.5)
	var last: String = music.history[music.history_index]
	var other := game.duplicate(true)
	other.id = "music-other"
	var game_stream: AudioStream = music.player.stream
	music.player.seek(2.0)
	await create_timer(0.1).timeout
	app._launch_game(other)
	assert(music.history[music.history_index] == last and music.player.stream == game_stream, "Switching games or collection variants within the game session keeps the song")
	assert(music.player.get_playback_position() >= 2.0, "Only crossing the menu/game boundary restarts playback")
	app._return_from_game()
	await process_frame
	# A song prepared or added while outside a game waits until the next entry.
	var single := folder.path_join("single")
	DirAccess.make_dir_recursive_absolute(single)
	music.song_dir = single
	music.reload_assets()
	app._launch_game(game)
	assert(music.playlist.is_empty() and music.player.stream == null, "An empty music library does not prevent launching")
	app._return_from_game()
	await process_frame
	assert(DirAccess.copy_absolute(folder.path_join("songs/track0.wav"), single.path_join("only.wav")) == OK)
	music._scan()
	assert(music.history.is_empty() and music.player.stream == null, "Background scans leave newly available game songs unplayed")
	for entry in 2:
		app._launch_game(game)
		assert(music.player.playing and not music.player.stream_paused, "A one-song library can be selected repeatedly")
		assert(music.player.get_playback_position() < 0.5, "A lone song restarts instead of resuming")
		music.player.seek(2.0)
		await create_timer(0.1).timeout
		app._return_from_game()
		await process_frame
	return true
