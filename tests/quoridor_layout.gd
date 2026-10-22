extends SceneTree

const Host = preload("res://Games/quoridor/host/main.tscn")
var host: Node
var failures := 0
var checks := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func geometry() -> Array:
	var result: Array = [host.board.get_global_rect(), host.controls.get_global_rect(), host.screen.content.get_global_rect(), host.screen.content_scroll.scroll_vertical]
	for card in host.score_cards:
		result.append(card.panel.get_global_rect())
	return result


func _run() -> void:
	root.min_size = Vector2i(1, 1)
	for shape in [Vector2i(1280, 720), Vector2i(480, 850), Vector2i(850, 480), Vector2i(1920, 1080)]:
		root.content_scale_size = shape
		root.size = shape
		await _human_move(4, false)
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1920, 1080)
	await _human_move(4, true)
	await _human_move(2, false)
	print("Quoridor layout: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _human_move(player_count: int, reduced: bool) -> void:
	host = Host.instantiate()
	root.add_child(host)
	var context := GameSessionContext.new("quoridor", [], {"id": "host", "display_name": "Host", "color": "#25b3ab"}, false)
	context.reduced_motion = reduced
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	if player_count == 4:
		host._select_players(1)
		host._apply_settings()
	else:
		host.start_game()
	for sound in host.sounds.values(): sound.volume_db = -80
	for frame in 20: await process_frame
	if player_count == 4:
		for index in 4:
			var panel: Rect2 = host.score_cards[index].panel.get_global_rect()
			var content: Rect2 = host.score_cards[index].content.get_global_rect()
			check(content.position.x >= panel.position.x + 24 and content.end.x <= panel.end.x - 24 and content.position.y >= panel.position.y + 30 and content.end.y <= panel.end.y - 30, "Compact card %d keeps its content inset from the frame" % index)
			check(host.wall_labels[index].get_global_rect().end.y <= panel.end.y - 30, "Wall counter %d stays above the lower ornament" % index)
	var settings: Button = host.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.text.begins_with("SETTINGS"))[0]
	var history: Button = host.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.text.begins_with("HISTORY"))[0]
	check(settings.size.y >= 60 and history.size.y >= 60 and settings.get_theme_font_size("font_size") <= 12, "Utility buttons give smaller text and icons more room")
	check(not history.text.contains("SESSION") and history.get_global_rect().end.x <= root.get_visible_rect().size.x, "History uses the shorter caption and remains reachable")
	check(host.move_button.size.y >= 60 and host.move_button.get_theme_font_size("font_size") <= 14 and host.move_button.get_theme_constant("icon_max_width") <= 24, "Board actions use roomy shared controls")
	var before := geometry()
	var point: Vector2 = root.get_final_transform() * host.board.cells[67].get_global_rect().get_center()
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.position = point
	pressed.global_position = point
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame
	var released := pressed.duplicate()
	released.pressed = false
	Input.parse_input_event(released)
	for frame in 20:
		await process_frame
		if geometry() != before:
			print("Layout frame %d before=%s after=%s status=%s" % [frame, before, geometry(), host.screen.status.text])
		check(geometry() == before, "A real human click leaves layout fixed on frame %d" % frame)
	check(host.rules.pawns[0] == 67, "Real mouse input moves the human pawn at %s, scale %s" % [root.size, root.content_scale_size])
	host.shutdown_game()
	host.queue_free()
	await process_frame
