extends SceneTree

# Run without --headless to inspect the actual launcher and rendered naval effects.
var checks := 0
var failures := 0
var output := "res://.test_data/battleship-visual/"


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func capture(name: String) -> void:
	for frame in 4:
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output + name + ".png")


func _resize(width: int, height: int) -> void:
	root.min_size = Vector2i(1, 1)
	root.content_scale_size = Vector2i(width, height)
	root.size = Vector2i(width, height)
	for frame in 8:
		await process_frame


func local_bounds(control: Control, ancestor: Control) -> Rect2:
	var transform := ancestor.get_global_transform().affine_inverse() * control.get_global_transform()
	return Rect2(transform.origin, control.size)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	await _resize(1280, 720)
	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new(output + "profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	app._play_from_lobby()
	await capture("catalog")
	var module: Dictionary = app.game_catalog.games.filter(func(game: Dictionary) -> bool: return game.id == "battleship")[0]
	check(app._can_launch(module), "Battleship can launch in solo mode from the real catalog")
	app._launch_game(module)
	var host = app.active_game
	host.session.reduced_motion = false
	host.seats[1].id = "fixture"
	for sound in host.sounds.values():
		sound.volume_db = -80
	host._setup_action(1, "auto")
	await create_timer(0.65).timeout
	await capture("setup")
	var monitor: Control = host.console_slots[0]
	check(host.deck_docked and [host.ship_choice, host.auto_button, host.clear_button, host.ready_button].all(func(control: Control) -> bool: return Rect2(Vector2.ZERO, monitor.size).grow(0.1).encloses(local_bounds(control, monitor))), "Every tilted setup control fits inside the player bridge monitor")
	var selection_bounds := local_bounds(host.ship_choice, host.setup_controls)
	var auto := local_bounds(host.auto_button, host.setup_controls)
	var clear := local_bounds(host.clear_button, host.setup_controls)
	var ready := local_bounds(host.ready_button, host.setup_controls)
	check(selection_bounds.end.y <= auto.position.y and auto.end.y <= clear.position.y and is_equal_approx(clear.position.y, ready.position.y) and host.ready_button.text == "READY" and not host.console_slots[1].visible, "Setup has ship selection, Auto Place, then Clear and READY together on the player side")
	check(monitor.size.y - local_bounds(host.ready_button, monitor).end.y >= 2, "Tilted setup controls retain clearance for their shadows inside the bezel")
	check(is_zero_approx(monitor.rotation_degrees) and is_equal_approx(host.setup_controls.get_global_transform().get_rotation(), monitor.get_global_transform().get_rotation()), "Setup controls and click targets remain upright inside the player monitor")
	var click_revision: int = host.rules.revision
	var click_point: Vector2 = host.auto_button.get_global_transform() * (host.auto_button.size / 2)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = click_point
		click.global_position = click_point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click)
		await process_frame
	check(host.rules.revision == click_revision + 1, "A pointer click on the tilted Auto Place button reaches the authoritative setup action")
	host._setup_action(1, "ready")
	await capture("battle")
	check(host.board_frame.get_global_rect().get_center().distance_to(app.size / 2.0) < 2, "The shared foundation centers the two-board playfield")
	check(host.console_slots[0].size.is_equal_approx(host.console_slots[1].size) and is_zero_approx(host.console_slots[0].rotation_degrees) and is_zero_approx(host.console_slots[1].rotation_degrees), "Fleet displays have identical dimensions and remain upright")
	var toggles: Array = host.screen._details_toggles
	check(is_equal_approx(toggles[0].size.x, toggles[1].size.x) and is_equal_approx(toggles[0].global_position.y, toggles[1].global_position.y) and toggles[0].global_position.y - host.board_frame.get_global_rect().end.y < 16, "Equal options/history controls align directly beneath the boards")
	check(is_equal_approx(toggles[1].global_position.x - toggles[0].get_global_rect().end.x, 12), "Options and history buttons have a compact gap during play")
	var centered_before: Rect2 = host.board_frame.get_global_rect()
	for toggle in toggles:
		toggle.button_pressed = true
	await capture("details")
	check(host.details_bodies[0].get_parent().size.is_equal_approx(host.details_bodies[1].get_parent().size), "Expanded options and history share the same panel size")
	var options_rect: Rect2 = host.details_bodies[0].get_parent().get_global_rect()
	var history_rect: Rect2 = host.details_bodies[1].get_parent().get_global_rect()
	check(is_equal_approx(history_rect.position.x - options_rect.end.x, 12) and is_equal_approx((options_rect.position.x + history_rect.end.x) / 2, app.size.x / 2), "Expanded options/history panels stay adjacent and centered as one group")
	check(host.board_frame.get_global_rect().position.distance_to(centered_before.position) < 1 and host.board_frame.size.is_equal_approx(centered_before.size), "Opening supplementary panels preserves board placement and scale")
	check(host.score_cards.all(func(card: Dictionary) -> bool: return card.score.get_theme_font_size("font_size") <= 18 and card.content.find_children("*", "PanelContainer", true, false).is_empty()), "Session wins use regular text without decorative score boxes")
	check(host.ready_button.get_theme_stylebox("normal").bg_color.b > host.ready_button.get_theme_stylebox("normal").bg_color.r and host.auto_button.get_theme_color("font_color").get_luminance() > 0.7, "Shared naval buttons use blue surfaces and readable light text")
	for toggle in toggles:
		toggle.button_pressed = false
	var target: int = host.rules.fleets[1][0].cells[0]
	host._fire(1, target)
	await create_timer(0.18).timeout
	await capture("cannon")
	await create_timer(0.38).timeout
	await capture("hit")
	await create_timer(0.80).timeout
	var miss: int = range(100).filter(func(cell: int) -> bool: return not host.rules.fleets[0].any(func(ship: Dictionary) -> bool: return ship.cells.has(cell)))[0]
	host._fire(2, miss)
	await create_timer(0.58).timeout
	await capture("miss")
	await create_timer(0.8).timeout
	var wreck: Dictionary = host.rules.fleets[1][0]
	for cell in wreck.cells:
		host.rules.shots[0][cell] = 2
	target = wreck.cells[-1]
	host.rules.shots[0][target] = 0
	host.rules.turn = 1
	host._fire(1, target)
	await create_timer(0.6).timeout
	await capture("sunk")
	await create_timer(0.8).timeout
	var before: Rect2 = host.board_frame.get_global_rect()
	for ship in host.rules.fleets[1]:
		for cell in ship.cells:
			host.rules.shots[0][cell] = 3
	target = host.rules.fleets[1][-1].cells[-1]
	host.rules.shots[0][target] = 0
	host.rules.turn = 1
	host._fire(1, target)
	await create_timer(1.45).timeout
	await capture("victory")
	check(host.replay_button.get_global_rect().end.y <= app.size.y and host.board_frame.get_global_rect().position.distance_to(before.position) < 1, "Replay fits without scrolling or shifting the boards")
	for toggle in toggles:
		toggle.button_pressed = true
	await capture("victory-details")
	check(host.replay_button.get_global_rect().end.y <= app.size.y and host.board_frame.get_global_rect().position.distance_to(before.position) < 1, "Expanded panels preserve visible replay after a win")
	check(is_equal_approx(toggles[1].global_position.x - toggles[0].get_global_rect().end.x, 12) and host.replay_button.global_position.y >= toggles[0].get_global_rect().end.y, "Replay uses its own row while options and history retain their compact gap")
	await _resize(1920, 1080)
	var replay_minimum: Vector2 = host.replay_button.custom_minimum_size
	host.replay_button.custom_minimum_size.x = 960
	await capture("wide-details")
	options_rect = host.details_bodies[0].get_parent().get_global_rect()
	history_rect = host.details_bodies[1].get_parent().get_global_rect()
	check(is_equal_approx(history_rect.position.x - options_rect.end.x, 12) and is_equal_approx((options_rect.position.x + history_rect.end.x) / 2, app.size.x / 2), "A wider action row keeps expanded options/history compact and centered")
	check(is_equal_approx(toggles[1].global_position.x - toggles[0].get_global_rect().end.x, 12) and is_equal_approx((toggles[0].global_position.x + toggles[1].get_global_rect().end.x) / 2, app.size.x / 2), "Options/history buttons remain centered with their panels on wide hosts")
	host.replay_button.custom_minimum_size = replay_minimum
	for toggle in toggles:
		toggle.button_pressed = false
	await _resize(390, 844)
	await capture("portrait")
	check(host.board_frame.get_global_rect().end.x <= app.size.x and host.board_frame.get_global_rect().end.y <= app.size.y, "Native portrait view wraps to one reachable fleet")
	check(host.console_slots.all(func(slot: Control) -> bool: return is_zero_approx(slot.rotation)), "Wrapped fleet panels return to an upright layout")
	host._play_again()
	await capture("portrait-setup")
	check(host.ready_button.get_global_rect().end.y <= app.size.y and host.ship_choice.get_global_rect().end.x <= app.size.x, "Portrait setup keeps its controls and ready action reachable")
	host._setup_action(1, "auto")
	host._setup_action(1, "ready")
	await _resize(844, 390)
	await capture("landscape")
	check(host.board_frame.get_global_rect().end.x <= app.size.x and host.replay_button.get_global_rect().end.y <= app.size.y, "Short native landscape retains both boards and replay")
	host._select_difficulty(2)
	await capture("landscape-setup")
	check(host.screen.content_scroll.get_global_rect().encloses(host.ready_button.get_global_rect()) and host.board_frame.get_global_rect().end.y <= app.size.y, "Landscape setup keeps the grouped controls inside the usable viewport")
	host.return_to_lobby()
	await capture("return")
	check(app.current_state == "game_menu" and app.active_game == null, "Visual navigation returns to the existing game menu")
	app.lan_server.stop_server()
	app.queue_free()
	await process_frame
	await process_frame
	print("Battleship visual: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
