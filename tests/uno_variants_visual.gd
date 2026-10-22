extends SceneTree

const Host = preload("res://Games/uno/host/main.tscn")
var failures := 0
var output := "res://.test_data/uno-variants-visual/"


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


func resize_view(width: int, height: int) -> void:
	root.min_size = Vector2i(1, 1)
	root.content_scale_size = Vector2i(width, height)
	root.size = Vector2i(width, height)
	for frame in 8: await process_frame


func click(button: Button, window: Window) -> void:
	var point := button.get_global_rect().get_center()
	if window != root: point += Vector2(window.position)
	var movement := InputEventMouseMotion.new()
	movement.position = point
	movement.global_position = point
	root.push_input(movement, true)
	await process_frame
	for pressed in [true, false]:
		var input := InputEventMouseButton.new()
		input.position = point
		input.global_position = point
		input.button_index = MOUSE_BUTTON_LEFT
		input.pressed = pressed
		root.push_input(input, true)
		if pressed: await create_timer(.12).timeout
		await process_frame


func stop_ai(host: Node) -> void:
	host.ai_timer.stop()
	host.catch_timer.stop()
	host.jump_timer.stop()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.gui_embed_subwindows = true
	await resize_view(1280, 720)
	var host := Host.instantiate()
	root.add_child(host)
	host.auto_timer.process_mode = Node.PROCESS_MODE_DISABLED
	var context := GameSessionContext.new("uno", [], {"id":"host", "display_name":"Host", "color":"#2463eb"}, false)
	context.reduced_motion = true
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	host.start_game()
	stop_ai(host)
	var options: Button = host.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.accessibility_name == "SETTINGS")[0]
	check(host.rule_choices.size() == 6 and host.rule_choices.values().all(func(button: Button) -> bool: return not button.button_pressed), "All five native rule options default off")
	for dimensions in [Vector2i(1280,720), Vector2i(390,844), Vector2i(844,390)]:
		await resize_view(dimensions.x, dimensions.y)
		var board: Rect2 = host.table.get_global_rect()
		options.button_pressed = true
		await capture("options-%dx%d" % [dimensions.x, dimensions.y])
		check(host.table.get_global_rect() == board, "Opening variant settings preserves the centered board")
		var toggle: Button = host.rule_choices.force_play
		var parent := toggle.get_parent()
		while parent != null and not parent is ScrollContainer: parent = parent.get_parent()
		check(parent is ScrollContainer, "All settings use the shared sheet")
		if parent is ScrollContainer:
			check(parent.get_v_scroll_bar().max_value <= parent.get_v_scroll_bar().page + 1 and parent.scroll_vertical == 0, "Collapsed compact options fit without scrolling; expanded history may scroll")
			var inputs: Array = host.rule_choices.values().filter(func(button: Button) -> bool: return button.is_visible_in_tree()) + [host.difficulty_choice, host.gamemode_choice, host.apply_options]
			check(inputs.all(func(input: Control) -> bool: return parent.get_global_rect().encloses(input.get_global_rect()) and input.get_global_rect().end.y <= root.size.y), "All five rules, difficulty and Apply are visible together in each orientation")
			var previous: bool = host.rules.force_play
			await click(toggle, root)
			stop_ai(host)
			check(host.rules.force_play == previous and host.pending_options.force_play != previous and not host.apply_options.disabled, "A real host click stages a change and enables Apply")
			await click(host.apply_options, root)
			stop_ai(host)
			check(host.rules.force_play != previous and host.rules.plays.is_empty() and host.apply_options.disabled, "A real Apply click starts a fresh hand with the staged option")
		options.button_pressed = false
	await resize_view(390,844)
	host.rules.allow_seven_zero = true
	host.rules.turn = 0
	host.rules.phase = "play"
	host.rules.winner = -1
	host.rules.drawn = -1
	host.rules.pending_draw = 0
	host.rules.color = "red"
	host.rules.discard = [17]
	host.rules.hands = [[13, 79, 59], [27, 57], [15, 81], [61, 38]]
	host.rules.deck = range(108).filter(func(id: int) -> bool: return not host.rules.discard.has(id) and not host.rules.hands.any(func(hand: Array) -> bool: return hand.has(id)))
	host.rules.revision += 1
	host._publish()
	stop_ai(host)
	host._select_card(13)
	stop_ai(host)
	await capture("seven-swap-portrait")
	check(host.table.swap_buttons.filter(func(button: Button) -> bool: return button.visible).size() == 3, "Seven highlights the three existing opponent names")
	check(host.table.swap_buttons.filter(func(button: Button) -> bool: return button.visible).all(func(button: Button) -> bool: return button.get_global_rect().position.y >= 0 and button.get_global_rect().end.y <= root.size.y), "Native name targets fit portrait")
	var received: Array = host.rules.hands[2].duplicate()
	await click(host.table.swap_buttons[2], root)
	stop_ai(host)
	check(host.rules.phase == "play" and host.rules.hands[0] == received and host.table.swap_buttons.all(func(button: Button) -> bool: return not button.visible), "A held native name click swaps hands and clears targets")
	await capture("seven-swapped")
	await resize_view(844,390)
	host.rules.turn = 0
	host.rules.phase = "play"
	host.rules.color = "red"
	host.rules.hands = [[13, 79, 59], [27, 57], [15, 81], [61, 38]]
	host.rules.discard = [17]
	host.rules.revision += 1
	host._select_card(13)
	stop_ai(host)
	await capture("seven-swap-landscape")
	check(host.table.swap_buttons.filter(func(button: Button) -> bool: return button.visible).all(func(button: Button) -> bool: return button.get_global_rect().position.x >= 0 and button.get_global_rect().end.x <= root.size.x), "Native name targets fit landscape")
	host.shutdown_game()
	host.queue_free()
	await process_frame
	# Short public tables use a shared modal so disclosure buttons cannot hide inputs.
	var spectator := Host.instantiate()
	root.add_child(spectator)
	spectator.auto_timer.process_mode = Node.PROCESS_MODE_DISABLED
	var players: Array = []
	for seat in 6: players.append({"id":"phone-%d" % seat,"display_name":"Player %d" % seat,"color":"#2463eb"})
	context = GameSessionContext.new("uno",players,{},true)
	context.reduced_motion = true
	spectator.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	spectator.initialize_session(context)
	spectator.start_game()
	var disclosure: Button = spectator.find_children("*","Button",true,false).filter(func(button: Button) -> bool: return button.accessibility_name == "SETTINGS")[0]
	disclosure.button_pressed = true
	await capture("spectator-options-landscape")
	var close: Button = spectator.find_children("*","Button",true,false).filter(func(button: Button) -> bool: return button.text == "CLOSE" and button.is_visible_in_tree())[0]
	check(not disclosure.visible and close.is_visible_in_tree(), "Short public layouts keep all settings above a dim backdrop and hide overlapping disclosures")
	check(spectator.rule_choices.values().filter(func(button: Button) -> bool: return button.is_visible_in_tree()).size() == 5 and spectator.apply_options.is_visible_in_tree(), "Every option and Apply is visible in the shared modal")
	spectator.rule_choices.force_play.button_pressed = true
	await click(close,root)
	check(not disclosure.button_pressed and spectator.pending_options.force_play and not spectator.rules.force_play, "A held Close press dismisses the modal and retains unapplied edits")
	disclosure.button_pressed = true
	for frame in 8: await process_frame
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	for frame in 3: await process_frame
	check(not disclosure.button_pressed, "Escape dismisses the shared options modal")
	disclosure.button_pressed = true
	for frame in 8: await process_frame
	var outside := InputEventMouseButton.new()
	outside.position = Vector2(14,360)
	outside.global_position = outside.position
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	root.push_input(outside)
	for frame in 3: await process_frame
	check(not disclosure.button_pressed and spectator.pending_options.force_play, "An outside click dismisses options without applying the edit")
	spectator.shutdown_game()
	spectator.queue_free()
	await process_frame
	await create_timer(.15).timeout
	print("UNO variants visual: %d failures" % failures)
	quit(1 if failures else 0)
