extends SceneTree

# Visual regression coverage for the template and games using shared GameScreen.
var checks := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var folder := "res://.test_data/shared-game-visual/"
	DirAccess.make_dir_recursive_absolute(folder)
	for id in ["_Template", "tic-tac-toe", "four-in-a-row", "checkers", "chess"]:
		for view in [["desktop", 1280, 720, false], ["portrait", 390, 844, false], ["landscape", 844, 390, false], ["reduced", 390, 844, true]]:
			root.min_size = Vector2i(1, 1)
			root.content_scale_size = Vector2i(view[1], view[2])
			root.size = Vector2i(view[1], view[2])
			var host = load("res://Games/%s/host/main.tscn" % id).instantiate()
			root.add_child(host)
			var context := GameSessionContext.new(id, [], {"id": "host", "display_name": "Host", "color": "#2463eb"}, false)
			context.reduced_motion = view[3]
			host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
			host.initialize_session(context)
			host.start_game()
			if id == "checkers":
				host._host_cell(40)
			if id == "_Template":
				var corner_captions: Array[String] = ["OPTIONS", "PLAY LOG"]
				var panels: Array[VBoxContainer] = host.screen.add_corner_details(corner_captions)
				host.screen.add_sidebar_text(panels[0], "Shared corner sheet")
				host.screen.add_history_log(panels[1]).text = "1. Host · Red 5"
				for button in host.find_children("*", "Button", true, false):
					if button.text.begins_with("OPTIONS") or button.text.begins_with("PLAY LOG"):
						button.button_pressed = true
			for frame in 12:
				await process_frame
			check(host.screen.instruction_label.visible == false and host.screen.back_button.get_global_rect().end.x <= host.size.x, "%s/%s shared heading and navigation fit" % [id, view[0]])
			if host.screen.board_anchor != null:
				var rect: Rect2 = host.screen.board_anchor.get_global_rect()
				check(rect.position.x >= 0 and rect.end.x <= host.size.x and rect.end.y <= host.size.y, "%s/%s board fits the viewport" % [id, view[0]])
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(folder + id + "-" + str(view[0]) + ".png")
			if id == "_Template":
				host.phase_dialog.overlay.show()
				for frame in 12:
					await process_frame
				check(root.get_visible_rect().encloses(host.phase_dialog.panel.get_global_rect()), "Template/%s phase dialog fits with shared scrolling" % view[0])
				check(host.screen.back_button.z_index > host.phase_dialog.overlay.z_index, "Template/%s phase dialog preserves return navigation" % view[0])
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(folder + id + "-dialog-" + str(view[0]) + ".png")
				for tone in ["danger", "success"]:
					host.screen.set_phase_dialog_tone(host.phase_dialog, tone)
					check(host.phase_dialog.body.get_child(0).get_theme_color("font_color") == GameLook.result_colors(tone).ink, "Template/%s/%s result text stays readable in the shared light theme" % [view[0], tone])
					if DisplayServer.get_name() != "headless":
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(folder + id + "-" + tone + "-" + str(view[0]) + ".png")
				host.screen.set_phase_dialog_tone(host.phase_dialog)
				check(host.phase_dialog.overlay.theme == host.screen.theme, "Template/%s restores its regular dialog palette" % view[0])
			host.shutdown_game()
			host.queue_free()
			await process_frame
			await process_frame
	# Also exercise discovery, host options and return navigation in the real app.
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new(folder + "profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	app._play_from_lobby()
	for id in ["tic-tac-toe", "four-in-a-row", "checkers", "chess"]:
		var module: Dictionary = app.game_catalog.games.filter(func(game: Dictionary) -> bool: return game.id == id)[0]
		app._launch_game(module)
		var host = app.active_game
		check(host != null and app.active_game_id == id, "%s launches from the validated catalog" % id)
		for frame in 12:
			await process_frame
		var before: Rect2 = host.screen.board_anchor.get_global_rect()
		var toggles: Array[Node] = host.find_children("*", "Button", true, false)
		if id == "tic-tac-toe":
			check(toggles.filter(func(button: Button) -> bool: return button.text.begins_with("SETTINGS")).is_empty(), "Tic Tac Toe omits the Settings disclosure")
			check(host.difficulty_choice.is_visible_in_tree(), "Tic Tac Toe solo difficulty remains directly available")
		if id in ["tic-tac-toe", "four-in-a-row"]:
			var session_toggle: Button = toggles.filter(func(button: Button) -> bool: return button.text.begins_with("SESSION "))[0]
			var history_toggle: Button = toggles.filter(func(button: Button) -> bool: return button.text.begins_with("HISTORY "))[0]
			check(session_toggle.get_global_rect().end.x < before.position.x and history_toggle.global_position.x > before.end.x, "%s has separate Session on the left and History on the right" % id)
			session_toggle.button_pressed = true
			history_toggle.button_pressed = true
		elif id == "checkers":
			host.clock_input.value = 1.5
			host.clock_toggle.button_pressed = true
			check(host.rules.clock_seconds == 90 and host.clock_labels[0].visible, "Checkers timer is configured through the shared host controls")
			toggles.filter(func(button: Button) -> bool: return button.text.begins_with("SETTINGS"))[0].button_pressed = true
		else:
			toggles.filter(func(button: Button) -> bool: return button.text.begins_with("SETTINGS"))[0].button_pressed = true
		for frame in 12:
			await process_frame
		check(host.screen.board_anchor.get_global_rect().is_equal_approx(before), "%s host details preserve the board's position and size" % id)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder + id + "-host-options.png")
		host.screen.exit_requested.emit()
		check(app.active_game == null and app.current_state == "game_menu" and app.lan_server.running, "%s returns cleanly through the launcher without stopping controllers" % id)
		await process_frame
	app.lan_server.stop_server()
	app.queue_free()
	await create_timer(0.15).timeout
	var art_image := Image.create(120, 180, false, Image.FORMAT_RGBA8)
	art_image.fill(Color.RED)
	var art_texture := ImageTexture.create_from_image(art_image)
	var art_grid := GameCardGrid.new()
	root.add_child(art_grid)
	art_grid.set_items([{"card":{"id":1,"layout":"art","display_name":"Literal <card>"},"texture":art_texture}])
	check(art_grid.get_child(0).accessibility_name == "Literal <card>", "Complete card faces retain literal accessible names without invented monetary values")
	art_grid.queue_free()
	if DisplayServer.get_name() != "headless":
		var art_view := SubViewport.new()
		art_view.size = Vector2i(120, 180)
		art_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(art_view)
		var art_card := GameCard.new()
		art_card.card = {"layout":"art", "display_name":"Artwork already contains its lettering"}
		art_card.texture = art_texture
		art_card.size = Vector2(120, 180)
		art_view.add_child(art_card)
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var rendered_art := art_view.get_texture().get_image()
		check([Vector2i(2,2),Vector2i(60,22),Vector2i(60,90),Vector2i(60,160),Vector2i(60,175)].all(func(point: Vector2i) -> bool: return rendered_art.get_pixelv(point).is_equal_approx(Color.RED)), "Complete illustrated card faces occupy the full card without composed headers or money footers")
		art_view.queue_free()
	print("Shared game visual: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
