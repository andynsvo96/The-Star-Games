extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var app := (load("res://Main.tscn") as PackedScene).instantiate()
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	await process_frame
	var music = app.game_music
	assert(app.menu_music.song_dir == "res://asset/lobby_songs")
	assert(app.title_background.source_dir == "res://asset/splash_background")
	assert(music.song_dir == "res://asset/music")
	assert(not music.active and not music.visible)
	# Temporary silent tracks exercise playback without requiring user media.
	var folder := "user://game_music_test_%s" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = 8000
	var samples := PackedByteArray()
	samples.resize(80000)
	audio.data = samples
	for index in 3:
		assert(audio.save_to_wav(folder.path_join("track%d.wav" % index)) == OK)
	music.song_dir = folder
	music._scan()
	assert(music.playlist.size() == 3 and music.player.stream_paused)
	app._launch_game(app.game_catalog.games.filter(func(game: Dictionary) -> bool: return game["id"] == "tic-tac-toe")[0])
	await process_frame
	assert(app.active_game != null and music.active and music.visible)
	assert(music.player.playing and not music.player.stream_paused)
	assert(not app.menu_music.active and not app.menu_music.visible)
	assert(not app.menu_music.player.playing or app.menu_music.player.stream_paused)
	assert(music.player.bus == "Music")
	if DisplayServer.get_name() != "headless":
		music._reveal()
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.test_data/game_music.png")
	var cycle: Array[String] = [music.history.back()]
	for index in 2:
		music.player.finished.emit()
		assert(not cycle.has(music.history.back()))
		cycle.append(music.history.back())
	var last: String = music.history.back()
	music.player.finished.emit()
	assert(music.history.back() != last)
	music.toggle_pause()
	app._return_from_game()
	assert(not music.active and music.player.stream_paused)
	assert(app.menu_music.active)
	await process_frame
	app._launch_game(app.game_catalog.games.filter(func(game: Dictionary) -> bool: return game["id"] == "tic-tac-toe")[0])
	assert(music.active and music.player.stream_paused, "Manual pause survives navigation")
	music.toggle_pause()
	assert(not music.player.stream_paused)
	app._return_from_game()
	await process_frame
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)
	print("PASS: renamed media folders, game music shuffle, switching, and manual pause")
	quit()
