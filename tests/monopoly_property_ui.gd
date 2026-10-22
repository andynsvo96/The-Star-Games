extends SceneTree

var folder := "res://.test_data/monopoly-property-ui/"
var app: Control
var host
var checks := 0
var failures := 0

func _init() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)

func settle(name := "") -> void:
	for frame in 12: await process_frame
	if not name.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + name + ".png")

func tap(point: Vector2) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true; event.position = point; event.global_position = point
	root.push_input(event, true); await process_frame; event = event.duplicate(); event.pressed = false; root.push_input(event, true); await settle()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.min_size = Vector2i.ONE; root.size = Vector2i(1280,720); root.content_scale_size = root.size
	app = load("res://Main.tscn").instantiate(); app.profile_store = ProfileStore.new(folder + "profiles.json"); app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new(); root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true; app._enter_lobby(); app._play_from_lobby(); app._launch_game(app.game_catalog.find_game("monopoly-classic")); host = app.active_game
	host.saved_game.path = folder + "session.json"; host.options.solo_ai = 1; host.options.turn_timer = false; host._new_round(false); host.set_process(false); host.rules.s.turn = 0
	for id in [1,3]: host.rules.s.owners[id] = 0; host.rules.s.levels[id] = 3
	for id in [16,18,19]: host.rules.s.owners[id] = 1; host.rules.s.levels[id] = 5
	host.rules.s.owners[6] = 1; host.rules.s.mortgaged[6] = true; host.rules.s.owners[8] = 0; host._publish(); await settle("classic-states")
	check(host.ui.actions.get_children().all(func(button: Button) -> bool: return not button.text in ["PROPERTIES", "LAST CARD"]), "Classic omits both redundant toolbar buttons")
	await tap(host.ui.player_cards[0].score.get_global_rect().get_center())
	check(host.ui.assets_dialog.overlay.visible and host.ui.assets_dialog.heading.text.contains(str(host.seats[0].display_name)), "Clicking the local player's cash opens their complete properties")
	host.ui.assets_dialog.overlay.hide()
	await tap(host.ui.board.global_position + host.ui.board.cell_rect(1).get_center() * host.ui.board.size / 1000); await settle("classic-houses")
	check(host.ui.reader.visible and host.ui.reader.subtitle.text == "Owned by " + str(host.seats[0].display_name), "A board property identifies its current owner")
	check(host.ui.reader.card.card.deed_state.badge == "3 HOUSES" and host.ui.reader.card.card.deed_state.rows.filter(func(row: Dictionary) -> bool: return row.active).size() == 1 and host.ui.reader.card.card.deed_state.rows[3].active, "Only the current three-house rent is emphasized")
	host.ui.reader.close(); host.ui.show_property(16); await settle("classic-hotel")
	check(host.ui.reader.card.card.deed_state.badge == "HOTEL" and host.ui.reader.card.card.deed_state.rows[5].active, "The hotel card marks its hotel rent and upgrade")
	host.ui.reader.close(); host.ui.show_property(6); await settle("classic-mortgaged")
	check(host.ui.reader.card.card.mortgaged and host.ui.reader.card.card.deed_state.rows.all(func(row: Dictionary) -> bool: return not row.active), "A mortgaged deed is dimmed/stamped without an active rent row")
	host.ui.reader.close(); host.ui.show_property(39)
	check(host.ui.reader.subtitle.text == "Available from the Bank", "Unowned board properties identify the Bank")
	host.ui.reader.close()
	check(host._act(1, {"action":"offer_trade", "to":0, "give_cash":200, "take_cash":50, "give_properties":[6], "take_properties":[8], "give_jail":[], "take_jail":[]}, true), "The other player can submit a legal trade")
	await settle("classic-trade-offer")
	check(host.ui.decision_dialog.overlay.visible and host.ui.clock.text.contains(str(host.seats[0].display_name)) and host.ui.clock.text.contains(str(host.seats[1].display_name)), "The pending trade names both participants")
	var previews: Array = host.ui.decision_dialog.body.find_children("*", "GameCardGrid", true, false)
	check(previews.size() == 2 and previews[0].entries[0].card.mortgaged and previews[1].entries[0].card.id == 8, "The recipient sees both actual offered deeds with mortgage state")
	host.session.reduced_motion = false
	var accept: Button = host.ui.decision_dialog.actions.get_children().filter(func(button: Button) -> bool: return button.text.to_lower().contains("accept"))[0]
	await tap(accept.get_global_rect().get_center())
	check(host.rules.s.owners[6] == 0 and host.rules.s.owners[8] == 1 and host.motion.cards.flights.size() == 2 and host._animating(), "Accepting a trade moves exactly the accepted deeds through two public flights")
	check(host.motion.money.size() == 2 and host.motion.money.any(func(event: Dictionary) -> bool: return event.seat == 1 and event.target == 0) and host.motion.money.any(func(event: Dictionary) -> bool: return event.seat == 0 and event.target == 1), "Both directions of traded cash animate independently")
	check(not host.ui.decision_dialog.overlay.visible and not host._act(0, {"action":"roll"}), "Trade flights remain visible and block duplicate gameplay until settled")
	host._step(.45); host.ui.effects.update(true); await settle("classic-trade-transfer")
	host._step(host.motion_duration + 1)
	check(host.ui.decision_dialog.overlay.visible and host.rules.s.phase == "transfer", "Mortgage decisions open after the transfer animation")
	# One click on Roll again must create a new dice timeline, without a roll phase confirmation.
	host.session.reduced_motion = true; host._new_round(false); host.rules.s.turn = 0; host.rules.s.phase = "manage"; host.rules.s.extra_roll = true; host.rules.s.doubles = 1; host._publish(); await settle()
	var again: Button = host.ui.actions.get_children().filter(func(button: Button) -> bool: return button.text == "Roll again")[0]
	host.session.reduced_motion = false; await tap(again.get_global_rect().get_center())
	check(host.motion.rolls.size() == 1 and host._animating() and host.rules.events.any(func(event: Dictionary) -> bool: return event.kind == "roll"), "Roll again rolls immediately with a single press")
	host._step(host.motion_duration + 1); app._return_from_game(); app._launch_game(app.game_catalog.find_game("monopoly-deal")); host = app.active_game
	host.rules.start(host.seats.size(),0); host.animating = false; host.motion_timer.stop(); host._publish(); host.ai_timer.stop(); host.set_process(false)
	var prop: int = host.rules.deck.filter(func(id: int) -> bool: return host.rules.cards[id].kind == "property")[0]
	host.rules.deck.erase(prop); host.rules._receive_property(0,prop,host.rules.cards[prop].colors[0]); host._publish(); host.ai_timer.stop(); await settle("deal-table")
	check(host.turn_strip.tracked and host.turn_strip.get_child_count() == host.seats.size() and host.turn_strip.get_child(0).get_theme_color("font_color").is_equal_approx(Color("ffe18b")), "Deal uses a readable gold step in the shared turn-name header")
	check(not host.table.history_bounds.has_area() and host.history_button.get_global_rect().position.x > root.size.x / 2 and host.history_button.get_global_rect().end.y > root.size.y - 100, "Deal moves History from the board to the bottom-right control")
	var group: Dictionary = host.table.state.table[0].groups[0]
	await tap(host.table.global_position + host.table.group_bounds["0:%d" % group.id].get_center()); await settle("deal-player-public")
	check(host.inspection.overlay.visible and host.inspected_seat == 0 and host.inspected_group == -1 and not host.inspection.body.find_children("*", "GameCardGrid", true, false).is_empty(), "A placed card opens the same full public panel as clicking player stats")
	host.inspection.overlay.hide(); await tap(host.table.global_position + host.table.seat_bounds[1].end - Vector2(12,12))
	check(host.inspection.overlay.visible and host.inspected_seat == 1, "Empty space inside another player's stats also opens their public cards")
	host.inspection.overlay.hide(); await tap(host.history_button.get_global_rect().get_center()); await settle("deal-history")
	check(host.history_dialog.overlay.visible and host.history_button.button_pressed, "The bottom-right History button opens its enlarged live feed")
	await tap(host.history_dialog.actions.get_child(0).get_global_rect().get_center()); check(not host.history_dialog.overlay.visible and not host.history_button.button_pressed, "Closing History resets the toggle")
	app.lan_server.stop_server(); app.queue_free(); await process_frame; await create_timer(.2).timeout
	print("Monopoly property UI: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
