extends SceneTree

const Host = preload("res://Games/uno/host/main.tscn")
var output := "res://.test_data/uno-no-mercy-visual/"
var failures := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func capture(name: String) -> void:
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + name + ".png")


func resize_view(dimensions: Vector2i) -> void:
	root.min_size = Vector2i(1,1)
	root.content_scale_size = dimensions
	root.size = dimensions
	for frame in 8: await process_frame


func close_settings(host: Node) -> void:
	for button in host.find_children("*","Button",true,false):
		if button.text == "CLOSE" and button.is_visible_in_tree(): button.pressed.emit()
		if button.accessibility_name == "SETTINGS": button.button_pressed = false


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new(output + "profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	app._enter_lobby()
	app._play_from_lobby()
	app._launch_game(app.game_catalog.games.filter(func(module: Dictionary) -> bool: return module.id == "uno")[0])
	var host = app.active_game
	for humans in [0,6]:
		if humans > 0:
			host.return_to_lobby()
			await process_frame
			host = Host.instantiate()
			root.add_child(host)
			var players: Array = []
			for index in humans: players.append({"id":"fixture-%d" % index,"display_name":"Player %d" % (index + 1),"color":["#ed202e","#0869db","#08a750","#f7cf05","#ae39f2","#f52191"][index]})
			var context := GameSessionContext.new("uno",players,{},true)
			context.reduced_motion = true
			host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
			host.initialize_session(context)
			host.start_game()
		for timer in [host.ai_timer,host.auto_timer,host.jump_timer,host.catch_timer]: timer.process_mode = Node.PROCESS_MODE_DISABLED
		host.session.reduced_motion = true
		host.motion_timer.stop()
		host.dealing = false
		host.animating = false
		host._set_gamemode(2)
		host._apply_options()
		for dimensions in [Vector2i(1280,720),Vector2i(390,844),Vector2i(844,390)]:
			await resize_view(dimensions)
			var name := "%s-%dx%d" % ["solo" if humans == 0 else "spectator",dimensions.x,dimensions.y]
			close_settings(host)
			host.rules.turn = 0
			host.rules.phase = "play"
			host.rules.pending_draw = 0
			host.rules.pending_color = ""
			host.rules.drawn = -1
			host.rules.motion.clear()
			host.rules.feedback.clear()
			host.rules.color = "red"
			host.rules.discard = [host.rules.cards.filter(func(face: Dictionary) -> bool: return face.color == "red" and face.kind == "4")[0].id]
			if humans == 0:
				host.rules.hands[0].clear()
				for definition in [["red","draw4"],["red","discard_all"],["blue","skip_all"],["wild","reverse_draw4"],["wild","draw6"],["wild","draw10"],["wild","color_roulette"]]:
					host.rules.hands[0].append(host.rules.cards.filter(func(face: Dictionary) -> bool: return face.color == definition[0] and face.kind == definition[1])[0].id)
			host._publish()
			await capture(name + "-table")
			var board: Rect2 = host.table.get_global_rect()
			for button in host.find_children("*","Button",true,false):
				if button.accessibility_name == "SETTINGS" and button.is_visible_in_tree(): button.button_pressed = true
			await capture(name + "-settings")
			check(host.gamemode_choice.is_visible_in_tree() and host.table.get_global_rect().is_equal_approx(board), "Settings stay visible without shifting the board")
			for control in [host.gamemode_choice,host.difficulty_choice,host.apply_options] + host.rule_choices.values():
				if not control.is_visible_in_tree(): continue
				var bounds: Rect2 = control.get_global_rect()
				check(bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= dimensions.x and bounds.end.y <= dimensions.y, "Selectors, rules and Apply stay reachable: " + name)
			close_settings(host)
			if humans == 0:
				var roulette: int = host.rules.cards.filter(func(face: Dictionary) -> bool: return face.kind == "color_roulette")[0].id
				host.rules.discard = [roulette]
				host.rules.phase = "roulette_color"
				host.rules.revision += 1
				host._publish()
				await capture(name + "-roulette")
				check(host.color_dialog.visible and not host.color_dialog.cancel_button.visible and not host.color_dialog.uno_button.visible, "Roulette uses the existing picker as a required recipient choice")
				check(host.color_dialog.card_rect.position.y >= 0 and host.color_dialog.card_rect.end.y <= dimensions.y, "Native roulette picker fits: " + name)
				host._clear_selection()
				host.rules.phase = "play"
				host.rules.revision += 1
				host._publish()
		if humans > 0:
			host.rules._eliminate(2)
			host.rules.revision += 1
			host._publish()
			await capture("spectator-eliminated")
			host.shutdown_game()
			host.queue_free()
			await process_frame
	app.lan_server.stop_server()
	app.queue_free()
	await process_frame
	await create_timer(.15).timeout
	print("UNO No Mercy visual: %d failures; captures in .test_data/uno-no-mercy-visual" % failures)
	quit(1 if failures else 0)
