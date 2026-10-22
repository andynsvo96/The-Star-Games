extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var app := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	var music = app.menu_music
	var deadline := Time.get_ticks_msec() + 60000
	while music.playlist.size() < 4 and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(music.playlist.size() == 4, "All supplied songs should load")
	for source in music.playlist:
		assert(source.ends_with(".mp4"), "Playlist should scan original MP4 files")
		assert(music.playable_paths[source].begins_with("user://menu_music/"), "Prepared audio belongs in the private cache")
		assert(not FileAccess.file_exists(source.get_basename() + ".ogg"), "Do not generate siblings in the source folder")
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
	app._show_lobby()
	assert(music.player.stream_paused and music.visible)
	music.toggle.pressed.emit()
	assert(not music.player.stream_paused and music.toggle.icon == music.icons["pause"])
	var stream: AudioStream = music.player.stream
	app.current_state = "game"
	app._replace_screen()
	assert(music.player.stream_paused and not music.visible)
	app._show_title()
	assert(not music.player.stream_paused and music.player.stream == stream)
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
	var restored := ProfileStore.new()
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
	print("PASS: music shuffle, looping, history, pause, screen lifecycle, controls, and marquee")
	app.queue_free()
	await process_frame
	quit()
