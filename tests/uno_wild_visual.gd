extends SceneTree

const Host = preload("res://Games/uno/host/main.tscn")
var failures := 0
var output := "res://.test_data/uno-wild-visual/"


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
	root.min_size = Vector2i(1,1)
	root.content_scale_size = Vector2i(width,height)
	root.size = Vector2i(width,height)
	for frame in 8: await process_frame


func tap_sector(picker: Control, suit: String) -> void:
	var offset: Vector2 = {"red":Vector2(-18,-28), "blue":Vector2(18,-28), "green":Vector2(18,28), "yellow":Vector2(-18,28)}[suit]
	var point: Vector2 = picker.global_position + picker.card_rect.position + (offset.rotated(deg_to_rad(25)) + Vector2(60,90)) * picker.card_rect.size / Vector2(120,180)
	var movement := InputEventMouseMotion.new()
	movement.position = point
	movement.global_position = point
	root.push_input(movement)
	for pressed in [true,false]:
		var input := InputEventMouseButton.new()
		input.position = point
		input.global_position = point
		input.button_index = MOUSE_BUTTON_LEFT
		input.pressed = pressed
		root.push_input(input)
		if pressed: await create_timer(.1).timeout
		else: await process_frame


func setup(host: Node, card: int) -> void:
	host.rules.turn = 0
	host.rules.phase = "play"
	host.rules.color = "red"
	host.rules.drawn = -1
	host.rules.pending_draw = 0
	host.rules.winner = -1
	host.rules.discard = [17]
	host.rules.hands = [[card, 79, 59], [9, 27], [13, 57], [15, 61]]
	host.rules.revision += 1
	host.rules.motion.clear()
	host.rules.feedback.clear()
	host.table.effects.clear()
	host._publish()
	host.ai_timer.stop()
	host.catch_timer.stop()
	host.jump_timer.stop()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	await resize_view(1280,720)
	var host := Host.instantiate()
	root.add_child(host)
	host.auto_timer.process_mode = Node.PROCESS_MODE_DISABLED
	var context := GameSessionContext.new("uno", [], {"id":"host", "display_name":"Host", "color":"#2463eb"}, false)
	context.reduced_motion = true
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	host.start_game()
	for dimensions in [Vector2i(1280,720), Vector2i(390,844), Vector2i(844,390)]:
		await resize_view(dimensions.x, dimensions.y)
		for card in [100, 104]:
			for suit in ["red", "yellow", "green", "blue"]:
				setup(host, card)
				host._select_card(card)
				await capture("picker-%d-%s-%dx%d" % [card,suit,dimensions.x,dimensions.y])
				var rect: Rect2 = host.color_dialog.card_rect
				var hand := Rect2(host.table.global_position + host.table.hand_rect.position,host.table.hand_rect.size)
				check(not Rect2(host.color_dialog.global_position + rect.position,rect.size).intersects(hand), "Wild picker artwork leaves the private hand unobstructed")
				check([host.color_dialog.uno_button,host.color_dialog.cancel_button].all(func(button: Button) -> bool: return not button.visible or not button.get_global_rect().intersects(hand)), "Wild picker actions leave the private hand unobstructed")
				check(host.color_dialog.visible and rect.position.x >= 0 and rect.end.x <= root.size.x and rect.end.y < root.size.y, "Compact Wild art fits each host orientation")
				if suit == "red":
					for step in 6:
						var key := InputEventKey.new()
						key.keycode = KEY_TAB
						key.pressed = true
						root.push_input(key)
						await process_frame
						check(host.color_dialog.is_ancestor_of(root.gui_get_focus_owner()), "Keyboard focus stays inside the Wild picker")
				var revision: int = host.rules.revision
				await tap_sector(host.color_dialog, suit)
				check(host.rules.revision == revision + (2 if card == 104 else 1) and host.rules.color == suit and host.rules.discard.back() == card and not host.color_dialog.visible, "A real held pointer selects the exact Wild pie color")
				host.ai_timer.stop()
				host.catch_timer.stop()
	setup(host, 104)
	host.rules.force_play = true
	host.rules.phase = "drawn_color"
	host.rules.drawn = 104
	host.rules.hands[0] = [79, 104]
	host.rules.revision += 1
	host._publish()
	await capture("forced-wild")
	check(host.color_dialog.visible and host.color_dialog.uno_button.visible and not host.color_dialog.cancel_button.visible and not host.table.drawn_keep.visible, "Forced Wild opens the compact picker with UNO and no Keep or Cancel action")
	await tap_sector(host.color_dialog, "green")
	check(host.rules.discard.back() == 104 and host.rules.drawn == -1 and host.rules.color == "green", "Forced Wild plays immediately when its pie color is chosen")
	setup(host, 3)
	host.rules.force_play = true
	host.rules.hands[0] = [79, 3]
	host.rules.drawn = 3
	host.rules.revision += 1
	host._publish()
	await capture("forced-number-uno")
	check(host.table.uno_button.visible and not host.table.drawn_keep.visible, "Forced penultimate number offers UNO without a manual selection or Keep action")
	host.table.uno_button.pressed.emit()
	check(host.rules.armed[0] and host.rules.drawn == 3, "Forced number UNO declares before the automatic play")
	host._automatic_turn()
	check(host.rules.catch_target == -1 and host.rules.discard.back() == 3, "Automatic play preserves the forced number's UNO declaration")
	host.rules.hands[0] = [79, 3]
	host.rules.turn = 1
	host.rules.drawn = 9
	host.rules.revision += 1
	host._publish()
	await capture("opponent-forced-draw")
	check(not host.table.uno_button.visible, "Another player's forced draw cannot show UNO on the host's private hand")
	host.shutdown_game()
	host.queue_free()
	await process_frame
	await create_timer(.15).timeout
	print("UNO Wild visual: %d failures" % failures)
	quit(1 if failures else 0)
