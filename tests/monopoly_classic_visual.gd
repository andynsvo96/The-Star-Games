extends SceneTree

var folder := "res://.test_data/monopoly-classic-visual/"
var failures := 0
var app: Control


func _init() -> void:
	call_deferred("_run")


func capture(label: String) -> void:
	for frame in 12: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + label + ".png")


func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; printerr("FAIL: " + message)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.min_size = Vector2i(1, 1)
	app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new(folder + "profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby(); app._play_from_lobby()
	var collection: Dictionary = app.game_catalog.find_game("monopoly")
	app._launch_game(collection)
	for size in [Vector2i(1280, 720), Vector2i(844, 390), Vector2i(390, 844)]:
		root.content_scale_size = size; root.size = size; await capture("chooser-%dx%d" % [size.x, size.y])
		for button in app.active_game.choices.get_children():
			check(button.size.x >= (450 if size.x >= 1280 else 250 if size.x < 650 else 140), "Choice remains large after responsive layout settles")
			check(button.get_global_rect().position.x >= 0 and button.get_global_rect().end.x <= size.x + 1, "Choice fits host width")
			check(button.get_global_rect().end.y <= size.y + 1, "Choice fits host height")
	root.content_scale_size = Vector2i(1280, 720); root.size = Vector2i(1280, 720)
	var focused = app.active_game.choices.get_child(0)
	focused.reduced_motion = false; focused.grab_focus()
	var elapsed: float = focused._elapsed
	await create_timer(.25).timeout
	check(focused.has_focus() and focused._elapsed > elapsed, "Focused choices animate a breathing glow")
	check(focused.size.x >= 450, "Returning from portrait restores the large landscape choices")
	await capture("chooser-glow")
	focused.reduced_motion = true; elapsed = focused._elapsed
	await create_timer(.1).timeout
	check(focused._elapsed == elapsed, "Reduced motion freezes the choice highlight")
	app._on_collection_choice("monopoly-classic")
	var host = app.active_game
	host.saved_game.path = folder + "visual-game.json"
	if host.awaiting_resume: host._new_round(false)
	host.options.solo_ai = 5; host._new_round(false); host.set_process(false)
	host.rules.s.turn = 0; host.rules.s.phase = "roll"
	var owners := {1:0, 3:0, 6:1, 8:1, 9:1, 16:2, 18:2, 19:2, 21:3, 23:3, 24:3, 26:4, 27:4, 29:4, 31:5, 32:5, 34:5, 5:0, 15:1, 25:2, 35:3, 12:4, 28:5}
	for id in owners:
		host.rules.s.owners[id] = owners[id]
		if id in [1, 3]: host.rules.s.levels[id] = 2
		if id in [6, 8, 9]: host.rules.s.levels[id] = 1
		if id in [16, 18, 19]: host.rules.s.levels[id] = 3
		if id in [26, 27, 29]: host.rules.s.levels[id] = 4
	host.rules.s.cash = [1320, 860, 410, 1680, 750, 930]
	host.rules.s.positions = [1, 8, 19, 24, 37, 31]
	host.rules.s.last_card = host.rules.definition.chance[0].duplicate(true)
	host._publish()
	var file := FileAccess.open(folder + "controller-state.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(host.view_for(0))); file.close()
	var board_bounds := {}
	for size in [Vector2i(1280,720),Vector2i(1366,768),Vector2i(844,390),Vector2i(390,844),Vector2i(360,640)]:
		root.content_scale_size = size; root.size = size; host.ui._fit(); await capture("board-%dx%d" % [size.x,size.y])
		var bounds: Rect2 = host.ui.board.get_global_rect()
		board_bounds[str(size)] = bounds
		check(bounds.position.x >= -1 and bounds.end.x <= size.x + 1 and bounds.position.y >= -1 and bounds.end.y <= size.y + 1, "Board remains inside the host viewport")
		host.ui.show_property(1); await capture("deed-%dx%d" % [size.x,size.y]); host.ui.reader.close()
		host.ui.settings_toggle.button_pressed = true; await capture("settings-%dx%d" % [size.x,size.y]); host.ui.settings_toggle.button_pressed = false
	root.content_scale_size = Vector2i(1280,720); root.size = Vector2i(1280,720)
	host.ui.show_trade(); await capture("trade")
	check(host.ui.trade_dialog.overlay.visible and not host.ui.trade_dialog.body.find_children("*", "OptionButton", true, false).is_empty(), "Solo host can compose a trade using the shared opponent control")
	host.ui.trade_dialog.overlay.hide()
	for phone in [false, true]:
		var preview := GameThemePreview.new()
		preview.configure(host.skins, host.skin, phone, true, host.skins.presentation)
		preview.theme = host.ui.screen.theme; preview.z_index = 100
		preview.size = Vector2(560, 420); preview.position = (Vector2(1280,720) - preview.size) / 2
		host.add_child(preview); await capture("skin-preview-phone" if phone else "skin-preview-table")
		preview.queue_free(); await process_frame
	var restore: Dictionary = host.rules.export_state()
	host.session.reduced_motion = false
	check(host._act(0, {"action":"roll"}) and host._animating(), "Normal movement animates the authoritative roll")
	check(not host._act(0, {"action":"roll"}), "Repeated input is rejected during movement")
	host._step(host.motion_duration / 2); await capture("moving")
	host._step(host.motion_duration + 1); host.session.reduced_motion = true
	host.rules.import_state(restore); host.ui.board.moves = []; host._publish()
	host.rules.start(6, 0, 47017)
	for pair in [[1,0,3],[3,0,4],[6,0,4],[8,0,4],[9,0,4],[11,1,3],[13,1,3],[14,1,3],[16,1,1],[18,1,1],[19,1,1]]:
		host.rules.s.owners[pair[0]] = pair[1]; host.rules.s.levels[pair[0]] = pair[2]
	host.rules.apply(1, {"action":"build", "property":11, "revision":host.rules.s.revision}); host._publish()
	await capture("building-request")
	check(host.ui.decision_dialog.overlay.visible, "Host's own building request opens the shared decision sheet")
	host.local_action({"action":"claim_building", "property":1})
	host.rules.apply(1, {"action":"bid", "property":11, "amount":10, "revision":host.rules.s.revision}); host._publish()
	await capture("building-auction")
	check(host.ui.decision_dialog.overlay.visible, "Host bidder can choose its building placement")
	var bid_input: SpinBox = host.ui.decision_dialog.body.find_children("*", "SpinBox", true, false)[0]
	bid_input.value = 25; host.ui.decision_dialog.actions.get_child(0).pressed.emit()
	check(host.rules.s.auction.leader == 0 and host.rules.s.auction.amount == 25, "Native bid control submits the chosen amount and eligible placement")
	host.ui.decision_dialog.overlay.hide(); host.rules.import_state(restore); host._publish()
	host.rules.finish("time"); host._record_results(); host._publish(); await capture("results")
	for size in [Vector2i(1280,720),Vector2i(1366,768),Vector2i(844,390),Vector2i(390,844),Vector2i(360,640)]:
		root.content_scale_size = size; root.size = size; host.ui._fit(); await capture("results-%dx%d" % [size.x,size.y])
		check(host.ui.board.get_global_rect().is_equal_approx(board_bounds[str(size)]), "Results preserve board placement at %s" % size)
		check(host.ui.replay.visible and root.get_visible_rect().encloses(host.ui.replay.get_global_rect()) and host.ui.footer.visible, "Play Again remains reachable in the same footer row at %s" % size)
	app._return_from_game(); await capture("return-to-chooser")
	check(app.active_game_id == "monopoly", "Leaving Classic returns to the Monopoly chooser")
	app._on_collection_choice("monopoly-deal"); await capture("existing-deal")
	check(app.active_game_id == "monopoly-deal", "Chooser launches the original Deal module")
	app._return_from_game(); check(app.active_game_id == "monopoly", "Deal exit returns through the shared launcher collection route")
	app._return_from_game(); check(app.current_state == "game_menu", "Chooser Back returns to game selection")
	app.lan_server.stop_server(); app.queue_free(); await process_frame
	await create_timer(.2).timeout
	print("Monopoly Classic visual: %d failures" % failures)
	quit(1 if failures else 0)
