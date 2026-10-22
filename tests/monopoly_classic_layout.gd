extends SceneTree

var folder := "res://.test_data/monopoly-classic-layout/"
var app: Control
var host
var failures := 0
var checks := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)


func settle(label := "") -> void:
	for frame in 16: await process_frame
	if not label.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + label + ".png")


func tap(button: Button) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	event.position = button.get_global_rect().get_center(); event.global_position = event.position
	root.push_input(event, true); await process_frame
	event = event.duplicate(); event.pressed = false; root.push_input(event, true)
	await settle()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.min_size = Vector2i.ONE; root.size = Vector2i(1280, 720); root.content_scale_size = root.size
	app = load("res://Main.tscn").instantiate(); app.profile_store = ProfileStore.new(folder + "profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new(); root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true; app._enter_lobby(); app._play_from_lobby()
	app._launch_game(app.game_catalog.find_game("monopoly-classic")); host = app.active_game
	host.saved_game.path = folder + "session.json"
	if host.awaiting_resume: host._new_round(false)
	host.set_process(false); host.options.solo_ai = 5; host._new_round(false)
	host.rules.s.turn = 0
	var ids: Array = host.rules.properties.keys()
	for index in ids.size(): host.rules.s.owners[ids[index]] = index % 6
	check(host.rules.apply(0, {"action":"mortgage", "property":ids[0], "revision":host.rules.s.revision}), "Fixture records an accepted property action for History")
	host.rules.s.last_card = host.rules.definition.chance[0].duplicate(true); host._publish()
	for size in [Vector2i(1920,1080), Vector2i(1280,720), Vector2i(1024,768), Vector2i(844,390), Vector2i(390,844)]:
		root.size = size; root.content_scale_size = size; host.ui._fit(); await settle("six-%dx%d" % [size.x, size.y])
		var buttons: Array = host.ui.actions.get_children().filter(func(button: Button) -> bool: return button.visible)
		var first_y: float = buttons[0].global_position.y
		for button: Button in buttons:
			check(is_equal_approx(button.global_position.y, first_y), "Host actions stay in a single row at %s" % size)
			check(button.get_global_rect().position.x >= 0 and button.get_global_rect().end.x <= size.x, "Action remains inside the viewport at %s" % size)
		check(host.ui.turn_strip.get_child_count() == 6 and host.ui.turn_strip.get_children().all(func(label: Label) -> bool: return label.text == str(host.seats[label.get_index()].display_name)), "Header retains every player's literal name at %s" % size)
		check(not host.ui.turn_strip.get_global_rect().intersects(host.ui.settings_toggle.get_global_rect()) and not host.ui.turn_strip.get_global_rect().intersects(host.ui.screen.back_button.get_global_rect()), "Turn names stay clear of header navigation at %s" % size)
		if size.x >= 800:
			for index in 6:
				var panel: Control = host.ui.player_cards[index].panel
				check(root.get_visible_rect().encloses(panel.get_global_rect()), "All six player panels are visible at %s, seat %d: %s" % [size, index, panel.get_global_rect()])
			var scroll: VScrollBar = host.ui.screen.content_scroll.get_v_scroll_bar()
			check(scroll.max_value <= scroll.page + 1, "Gameplay requires no page scrolling at %s (max %.1f, page %.1f)" % [size, scroll.max_value, scroll.page])
			check(host.ui.player_cards.all(func(card: Dictionary) -> bool: return card.portfolio.get_global_rect().end.y <= card.panel.get_global_rect().end.y), "Property previews stay inside their stats panels at %s" % size)
		check(host.ui.player_cards.slice(0, 3).all(func(card: Dictionary) -> bool: return card.panel.get_parent() == host.ui.ledger) and host.ui.player_cards.slice(3).all(func(card: Dictionary) -> bool: return card.panel.get_parent() == host.ui.right_ledger), "Six seats split three per side")
	root.size = Vector2i(1280,720); root.content_scale_size = root.size; await settle()
	check(host.ui.actions.get_children().all(func(button: Button) -> bool: return button.text != "HELP"), "Help is removed from the host toolbar")
	check(host.ui.history_button.visible and not host.ui.history_panel.visible and host.ui.activity.get_parent() == host.ui.history_dialog.body, "Larger rosters replace the sidebar log with History")
	await tap(host.ui.history_button); await settle("history-expanded")
	check(host.ui.history_dialog.overlay.visible and host.ui.history_button.button_pressed and host.ui.activity.entry_font_size == 17, "History opens a larger readable feed")
	check(host.ui.activity.entries.get_child(0).text.contains("Star Host") and host.ui.activity.entries.get_child(0).get_theme_font("font") is FontVariation, "Expanded History retains its newest action in bold")
	await tap(host.ui.history_dialog.actions.get_child(0))
	check(not host.ui.history_dialog.overlay.visible and not host.ui.history_button.button_pressed, "Closing History restores its toggle state")
	var board: Rect2 = host.ui.board.get_global_rect()
	host.rules.s.last_card = {}; host.rules.s.phase = "manage"; host._publish(); await settle()
	check(host.ui.board.get_global_rect().is_equal_approx(board), "Changing toolbar actions never resizes or moves the board")
	host.rules.s.turn = 4; host._publish(); await settle()
	for index in 6:
		var name: Label = host.ui.turn_strip.get_child(index)
		check(name.get_theme_color("font_color").is_equal_approx(Color(host.seats[index].color) if index == 4 else Color.WHITE), "Only the turn owner's header name uses their identity color")
	check(host.event_text({"kind":"turn", "seat":4}).is_empty() and host.event_text({"kind":"start", "seat":0}).is_empty(), "Turn announcements are omitted from history")
	check(host.view_for(-1).activity.all(func(entry: Dictionary) -> bool: return not entry.text.is_empty() and not str(entry.text).ends_with("'s turn")), "Published history contains actions, without turn-only rows")
	# A larger late-game portfolio must stay inside its panel without a roster scroll.
	for index in ids.size(): host.rules.s.owners[ids[index]] = 0 if index < 14 else index % 6
	host._publish(); await settle("many-deeds")
	check(host.ui.player_cards[0].portfolio.entries.size() >= 14 and host.ui.player_cards[0].portfolio.get_global_rect().end.y <= host.ui.player_cards[0].panel.get_global_rect().end.y, "Large portfolios fit the same visible stats panel")
	for count in [3, 2, 4]:
		host.options.solo_ai = count - 1; host._new_round(false); host.rules.s.turn = 0; host._publish(); await settle("players-%d" % count)
		var labels: Array = host.ui.actions.get_children().map(func(button: Button) -> String: return button.text)
		if count <= 3:
			check(not labels.has("HISTORY") and not labels.has("HELP") and host.ui.history_panel.visible and not host.ui.right_ledger.visible, "Up to three players retain the permanent right-hand history with no Help/History button")
			check(host.ui.activity.get_parent() == host.ui.history_body and host.ui.player_cards.all(func(card: Dictionary) -> bool: return card.panel.get_parent() == host.ui.ledger), "Small rosters keep all players on the left and the live log on the right")
		else: check(labels.has("HISTORY") and host.ui.right_ledger.get_child_count() == 1 and not host.ui.history_panel.visible, "Adding a fourth player restores the split roster and History toggle")
	board = host.ui.board.get_global_rect(); host.rules.finish("time"); host._publish(); await settle("results-history")
	check(host.ui.replay.visible and host.ui.history_button.visible and is_equal_approx(host.ui.replay.global_position.y, host.ui.history_button.global_position.y), "Play Again and History remain available together in one result row")
	check(host.ui.board.get_global_rect().is_equal_approx(board), "The result row preserves board placement")
	await tap(host.ui.history_button); check(host.ui.history_dialog.overlay.visible, "Completed games still allow history inspection")
	await tap(host.ui.history_dialog.actions.get_child(0)); await tap(host.ui.replay)
	check(host.rules.s.phase != "finished" and not host.ui.replay.visible and host.ui.actions.get_children().count(host.ui.replay) == 1, "Play Again starts one new board and restores the same toolbar")
	app.lan_server.stop_server(); app.queue_free(); await process_frame; await create_timer(.2).timeout
	print("Monopoly Classic layout: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
