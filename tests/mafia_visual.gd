extends SceneTree

const Host = preload("res://Games/mafia/host/main.tscn")
var output := "res://.test_data/mafia-visual/"
var failures := 0


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


func check_visible(control: Control, message: String) -> void:
	check(root.get_visible_rect().encloses(control.get_global_rect()), message)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func check_history_layout(host) -> void:
	check(host.history_log.is_visible_in_tree(), "Host history remains open")
	check(host.find_children("*", "Button", true, false).all(func(button: Button) -> bool: return not button.text.begins_with("HISTORY")), "History has no disclosure button")
	if root.size.x >= 800:
		var primary: Rect2 = host.social_layout.primary.get_global_rect()
		var history: Rect2 = host.social_layout.history.get_global_rect()
		check(primary.size.x > history.size.x * 2 and history.position.x >= primary.end.x, "Voting and suspicions share the wider left column")
		check(is_equal_approx(primary.position.y, history.position.y), "Permanent history aligns with public voting")
	check(host.scores_button.text == "SCORES" and host.scores_button.size.is_equal_approx(host.settings_button.size), "Scores uses a short label and matches Settings dimensions")
	check(host.suspicion_label.get_parent().get_parent().get_theme_stylebox("panel").texture.resource_path.ends_with("paper-fill.png"), "Suspicions match the shared parchment instead of a sticky note")


func complete_night(host) -> void:
	for actor in host.rules.night_actors():
		var role: String = host.rules.roles[actor]
		host.rules.night_action(actor, actor if role == "doctor" else (host.rules.night_targets(actor)[0] if role == "detective" else -1))
	for seat in host.rules.players.size():
		if host.rules.alive[seat] and host.rules.roles[seat] == "civilian": host.rules.suspect(seat, (seat + 1) % 16)


func check_city_occlusion() -> void:
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop := TextureRect.new()
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(backdrop)
	var sky = preload("res://Games/mafia/host/sky.gd").new()
	viewport.add_child(sky)
	for view in [[1280, 720, "desktop"], [390, 844, "portrait"]]:
		viewport.size = Vector2i(view[0], view[1])
		for daytime in [false, true]:
			backdrop.texture = RuntimeAssets.texture("res://Games/mafia/art/%s.png" % ("town-day" if daytime else "town-night"))
			sky.set_daytime(daytime, false)
			sky.cycle = 0.4 if daytime else 1.4
			for frame in 4: await process_frame
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			image.save_png(output + "city-occlusion-%s-%s.png" % ["day" if daytime else "night", view[2]])
			var point: Vector2 = sky.orbit_position(sky.cycle + (0 if daytime else 1)) - Vector2(clampf(minf(sky.size.x, sky.size.y) * 0.075, 26, 67) * 0.55, 0)
			var city: Image = (sky.city_day if daytime else sky.city_night).get_image()
			var dimensions := Vector2(city.get_size())
			var scale := maxf(sky.size.x / dimensions.x, sky.size.y / dimensions.y)
			var source := Vector2i((point - (sky.size - dimensions * scale) / 2) / scale)
			var expected := city.get_pixelv(source)
			var sun: Texture2D = sky.sun
			var moon: Texture2D = sky.moon
			sky.sun = null
			sky.moon = null
			sky.queue_redraw()
			for frame in 4: await process_frame
			await RenderingServer.frame_post_draw
			# Compare rendered sampling; photographic PNGs have fine color detail.
			var reference := viewport.get_texture().get_image().get_pixelv(Vector2i(point))
			sky.sun = sun
			sky.moon = moon
			var actual := image.get_pixelv(Vector2i(point))
			check(expected.a > 0.99 and absf(actual.r - reference.r) < 0.02 and absf(actual.g - reference.g) < 0.02 and absf(actual.b - reference.b) < 0.02, "Buildings fully cover the passing %s in %s" % ["sun" if daytime else "moon", view[2]])
	viewport.queue_free()
	await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	await check_city_occlusion()
	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new(output + "profiles.json")
	root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	app._show_game_menu()
	app._set_show_all_games(true)
	await capture("catalog")
	app.lan_server.stop_server()
	app.queue_free()
	await process_frame
	for count in [4, 8]:
		var assembly_host = Host.instantiate()
		root.add_child(assembly_host)
		var assembly_players: Array = []
		for seat in count:
			assembly_players.append({"id": "a%d" % seat, "display_name": ["Andy", "Jack", "John", "Tony", "Emma", "Alex", "Sam", "Riley"][seat], "color": ["#008000", "#202020", "#ffffff", "#e53935"][seat % 4], "pose": seat % 6})
		var assembly_context := GameSessionContext.new("mafia", assembly_players, {}, true)
		assembly_context.reduced_motion = true
		assembly_host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
		assembly_host.initialize_session(assembly_context)
		assembly_host.start_game()
		assembly_host._replay()
		await resize_view(1280, 720)
		await capture("assembly-%d-desktop" % count)
		var dark_avatar: TextureRect = assembly_host.living_team.get_child(1).get_child(0)
		check(dark_avatar.size.y >= 96 and dark_avatar.texture.resource_path.ends_with("assembly-avatar.svg"), "Small Mafia rosters use large rounded busts")
		check(dark_avatar.self_modulate == Color("202020") and dark_avatar.get_child(1).texture.resource_path.ends_with("assembly-avatar-detail.svg"), "Black avatars keep their color with a separate contrast rim")
		if count == 4:
			var first: Control = assembly_host.living_team.get_child(0)
			var last: Control = assembly_host.living_team.get_child(3)
			check(last.get_global_rect().end.x - first.global_position.x <= 500, "Four players stay closely grouped on a wide host")
		assembly_host.shutdown_game()
		assembly_host.queue_free()
		await process_frame
	var host = Host.instantiate()
	root.add_child(host)
	var players: Array = []
	for seat in 16:
		players.append({"id": "p%d" % seat, "display_name": "Player %d" % (seat + 1), "color": ["#008000", "#202020", "#ffffff", "#e53935"][seat % 4], "pose": seat % 6})
	var context := GameSessionContext.new("mafia", players, {}, true)
	context.reduced_motion = true
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	host.start_game()
	for view in [[1280, 720, "desktop"], [390, 844, "portrait"], [844, 390, "landscape"]]:
		await resize_view(view[0], view[1])
		check_visible(host.start_button, "Start Game must fit in " + view[2])
		check(host.screen.content_scroll.get_global_rect().encloses(host.suspicion_label.get_parent().get_parent().get_global_rect()), "Whole sticky note is visible on first entry in " + view[2])
		await capture("setup-" + view[2])
		check_history_layout(host)
	await resize_view(1280, 720)
	host._set_option("godfather", true)
	host._set_option("boxer", true)
	host._apply_options()
	await capture("night-desktop")
	host.session.reduced_motion = false
	host.screen.background_media.reduced_motion = false
	complete_night(host)
	host._publish()
	await create_timer(0.5).timeout
	check(host.sky.cycle > 1 and host.sky.cycle < 2, "Rendered dawn shows an intermediate sun/moon orbit")
	check(root.get_visible_rect().has_point(host.sky.orbit_position(host.sky.cycle + 1)), "Setting moon remains visible while descending along its arc")
	await capture("dawn-orbit-desktop")
	await create_timer(1.4).timeout
	check(is_equal_approx(host.sky.cycle, 2.0), "Rendered dawn settles with the sun above the horizon")
	host.session.reduced_motion = true
	host.screen.background_media.reduced_motion = true
	for view in [[1280, 720, "desktop"], [390, 844, "portrait"], [844, 390, "landscape"]]:
		await resize_view(view[0], view[1])
		check(host.screen.content_scroll.get_global_rect().encloses(host.suspicion_label.get_parent().get_parent().get_global_rect()), "Whole anonymous note remains visible during day in " + view[2])
		await capture("day-" + view[2])
	check(host.rules.phase == "vote" and host.rules.votes.is_empty(), "Dawn must open actual voting before any controller requests it")
	for seat in range(0, 14):
		host.rules.vote(seat, (seat + 1) % 16)
	host._publish()
	for view in [[1280, 720, "desktop"], [390, 844, "portrait"], [844, 390, "landscape"]]:
		await resize_view(view[0], view[1])
		check(not host.phase_dialog.overlay.visible and host.ballot_scroll.visible, "Voting is inline without obscuring the other columns in " + view[2])
		check_visible(host.ballot_scroll, "Voting panel must fit in " + view[2])
		await capture("vote-" + view[2])
		check_history_layout(host)
	host.rules._finish(false)
	host._record_result()
	host._publish()
	for view in [[1280, 720, "desktop"], [390, 844, "portrait"], [844, 390, "landscape"]]:
		await resize_view(view[0], view[1])
		check_visible(host.phase_dialog.panel, "Town result must fit in " + view[2])
		check_visible(host.replay, "Play Again must remain reachable in " + view[2])
		await capture("town-result-" + view[2])
	# Settings remain available from results, with staged Apply and no instructions.
	for view in [[1280, 720, "desktop"], [390, 844, "portrait"], [844, 390, "landscape"]]:
		await resize_view(view[0], view[1])
		host._open_settings()
		await capture("settings-" + view[2])
		check_visible(host.apply_button, "Apply remains reachable in " + view[2])
		host.settings_dialog.overlay.hide()
	host._replay()
	host.rules._finish(true)
	host._publish()
	await resize_view(1280, 720)
	await capture("mafia-result-desktop")
	host._replay()
	await capture("replay-desktop")
	# Capture a real host-owned ejection before it settles into the next night.
	host.session.reduced_motion = false
	host.rules.options.ejection = true
	host.staged_options.ejection = true
	complete_night(host)
	for seat in 16: host.rules.vote(seat, 15 if seat != 15 else 14)
	host._publish()
	check(host.rules.phase == "ejection", "Optional host animation enters its authoritative phase")
	await create_timer(0.9).timeout
	await capture("ejection-desktop")
	check(host.living_team.get_child_count() == 16 and host.living_team.get_child(15).get_meta("eliminated"), "Eliminated player's seat immediately becomes a tombstone")
	check(host.ejection_stage.message.text == "Player 16 is %s." % ("Mafia" if host.rules.ejection.mafia else "innocent") and host.ejection_stage.message.show_behind_parent, "Alignment appears behind the moving figure")
	check(host.ejection_stage.message.get_theme_color("font_color") == Color.WHITE, "Ejection text is white independently of the player's identity")
	# Hold the host timeline while inspecting its completed reveal across sizes.
	host.set_process(false)
	host.rules.ejection.elapsed = host.rules.EJECTION_DURATION * 0.7
	for view in [[1280, 720, "desktop"], [390, 844, "portrait"], [844, 390, "landscape"]]:
		await resize_view(view[0], view[1])
		host._render()
		await capture("ejection-reveal-" + view[2])
		check_visible(host.ejection_stage, "Ejection scene fits in " + view[2])
		check(host.ejection_stage.message.visible_characters >= host.ejection_stage.message.get_total_character_count(), "Alignment finishes appearing in " + view[2])
	host.session.reduced_motion = true
	host._render()
	await capture("ejection-reduced-landscape")
	check(host.ejection_stage.reduced_motion and host.ejection_stage.message.visible_characters == -1, "Reduced motion shows the full alignment immediately")
	check(host.ejection_stage.message.get_global_rect().end.y <= host.ejection_stage.global_position.y + 100, "Reduced-motion figure leaves the full alignment unobscured")
	host.session.reduced_motion = false
	host.set_process(true)
	await create_timer(host.rules.EJECTION_DURATION * 0.3 + 0.2).timeout
	check(host.rules.phase == "night", "Ejection automatically resumes gameplay")
	await resize_view(1280, 720)
	var scores_button: Button = host.scores_button
	scores_button.button_pressed = true
	await capture("dead-names-desktop")
	check(host.scores_button.size.is_equal_approx(host.settings_button.size), "Opening Scores preserves the matching button sizes")
	scores_button.button_pressed = false
	host.rules._finish(false)
	host._publish()
	await capture("dead-player-result-desktop")
	host.phase_dialog.scroll.scroll_vertical = int(host.phase_dialog.body.size.y)
	await capture("dead-player-result-roles-desktop")
	host.shutdown_game()
	host.queue_free()
	await process_frame
	print("Mafia visual: %d failures; captures in %s" % [failures, output])
	quit(1 if failures else 0)
