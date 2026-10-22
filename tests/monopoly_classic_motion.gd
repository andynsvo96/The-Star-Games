extends SceneTree

var app: Control
var host
var checks := 0
var failures := 0
var folder := "res://.test_data/monopoly-classic-motion/"
var cues: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)


func capture(label: String) -> void:
	host.ui.effects.update(true)
	for frame in 8: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + label + ".png")


func tap(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true; event.position = point; event.global_position = point
	root.push_input(event, true); await process_frame
	event = event.duplicate(); event.pressed = false; root.push_input(event, true)
	for frame in 4: await process_frame


func reset() -> void:
	host.motion.clear(); host.motion_duration = 0; host.motion_elapsed = 0; host.ui.clear_round()
	host.rules.start(2, 0, 47017); host._sync_clocks(); host._publish(); cues.clear()


func begin_rules(before: Array) -> void:
	host._begin_motion(before); host._publish()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.min_size = Vector2i.ONE; root.size = Vector2i(1280, 720); root.content_scale_size = root.size
	app = load("res://Main.tscn").instantiate(); app.profile_store = ProfileStore.new(folder + "profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new(); root.add_child(app)
	app.profile_store.data.settings.reduced_motion = false; app._enter_lobby(); app._play_from_lobby()
	app._launch_game(app.game_catalog.find_game("monopoly-classic"))
	host = app.active_game; host.saved_game.path = folder + "session.json"
	if host.awaiting_resume: host._new_round(false)
	host.set_process(false); host.options.turn_timer = false
	for cue in host.sounds:
		host.sounds[cue].stream_paused = false
		check(host.sounds[cue].stream != null and host.sounds[cue].stream.get_length() > 0, "Local %s sound loads" % cue)
	reset()
	for index in 40:
		var areas: Dictionary = host.ui.board.space_content(index)
		for region in areas.values():
			if region.has_area(): check(host.ui.board.cell_rect(index).encloses(region), "Space %d keeps its content within its border" % index)
		var fitted: Dictionary = host.ui.board.fit_text(str(host.rules.definition.board[index].name).to_upper(), areas.name, 17, 3)
		var font: Font = host.ui.board.get_theme_font("font")
		check(fitted.lines.size() * float(fitted.font_size) * 1.12 <= areas.name.size.y + .1 and fitted.lines.all(func(line: String) -> bool: return font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fitted.font_size)).x <= areas.name.size.x), "Space %d fits upright text horizontally and vertically" % index)
	check(host.ui.board.fit_text("COMMUNITY\nCHEST", host.ui.board.space_content(2).name, 17, 3).lines == ["COMMUNITY", "CHEST"], "Community Chest preserves the explicit line break")
	check(host.ui.board.illustrations.size() == 11 and host.ui.board.illustrations.values().all(func(texture: Texture2D) -> bool: return texture != null), "Every special-space illustration loads offline")
	var before: Array = host.rules.s.cash.duplicate()
	host.rules.events.clear(); host.rules._roll_values(0, 3, 3); begin_rules(before)
	var revision: int = host.rules.s.revision; var dice: Array = host.rules.s.dice.duplicate()
	check(host._animating() and host.motion.rolls.size() == 1 and host.motion.moves[0].start >= 1, "Dice tumble before token movement begins")
	check(host.motion.moves[0].duration >= 1.6, "A six-space move remains readable rather than racing around the board")
	check(not host._act(0, {"action":"buy"}) and host.rules.s.revision == revision and host.rules.s.dice == dice, "Commands during dice and token motion are discarded without changing rules or dice")
	host._step(.38); await capture("dice-tumble")
	var paused_time: float = host.motion_elapsed
	host.ui.settings_toggle.button_pressed = true; host._step(2)
	check(host.motion_elapsed == paused_time and host.sounds.roll.stream_paused, "Settings freezes the complete timeline and current sound")
	host.ui.settings_toggle.button_pressed = false
	var doubles: Dictionary = host.motion.specials.filter(func(effect: Dictionary) -> bool: return effect.kind == "doubles")[0]
	host._step(float(doubles.start) + .35 - host.motion_elapsed); await capture("doubles")
	check(host.rules.s.extra_roll and host.motion.moves[0].start >= doubles.start + doubles.duration, "Doubles feedback precedes movement and retains the standard extra roll")
	host._step(float(host.motion.moves[0].start) + .4 - host.motion_elapsed); await capture("token-hop")
	check(host.motion_elapsed > paused_time and not host.sounds.roll.stream_paused, "Closing Settings resumes the same timeline")
	host._step(host.motion_duration + 1)
	check(not host._animating(), "Input unlocks only after the final movement settles")
	reset(); host.rules.s.positions[0] = 39; before = host.rules.s.cash.duplicate(); host.rules.events.clear(); host.rules._roll_values(0, 1, 2); begin_rules(before)
	var gain: Dictionary = host.motion.money[0]
	check(gain.changes == [{"seat":0,"amount":200}] and gain.start >= host.motion.moves[0].start, "Passing GO displays the actual $200 gain at the crossing")
	var chest: Dictionary = host.motion.specials.filter(func(effect: Dictionary) -> bool: return effect.kind == "chest")[0]
	host._step(float(chest.start) + .35); await capture("chest-open")
	check(host.motion.cards.flights.size() >= 2 and host.motion.cards.effects[0].start > chest.start, "Community Chest opens before a shared card flight and reveal")
	host._step(float(host.motion.cards.effects[0].start) + .65 - host.motion_elapsed); await capture("community-card")
	var snapshot: Dictionary = host.view_for(0)
	check(snapshot.motion.active and snapshot.motion.elapsed > 0 and not JSON.stringify(snapshot.motion).contains("rng_state"), "Refresh can restore the current public effect from elapsed time without private random/deck state")
	var file := FileAccess.open(folder + "controller-motion.json", FileAccess.WRITE); file.store_string(JSON.stringify(snapshot)); file.close()
	host.player_disconnected(str(host.seats[0].id)); var frozen: float = host.motion_elapsed; host._step(5)
	check(host.motion_elapsed == frozen, "Disconnect cannot advance an in-progress card reveal")
	host.player_reconnected({"id":host.seats[0].id})
	reset(); host.rules.s.positions[0] = 24; before = host.rules.s.cash.duplicate(); host.rules.events.clear(); host.rules._roll_values(0, 2, 4); begin_rules(before)
	var jail: Dictionary = host.motion.specials.filter(func(effect: Dictionary) -> bool: return effect.kind == "jail")[0]
	check(host.motion.moves[-1].teleport and jail.start >= host.motion.moves[-1].start + host.motion.moves[-1].duration, "Jail gates close after the player's token arrives")
	check(host.motion.cues.any(func(cue: Dictionary) -> bool: return cue.cue == "jail" and cue.start >= jail.start), "Metal jail-cell sound is timed to the gates")
	host._step(float(jail.start) + .7); await capture("jail-closed")
	reset(); host.rules.s.owners[1] = 1; host.rules.s.owners[3] = 1; host.rules.s.positions[0] = 38; before = host.rules.s.cash.duplicate(); host.rules.events.clear(); host.rules._roll_values(0, 1, 2); begin_rules(before)
	var payment: Dictionary = host.motion.money.filter(func(event: Dictionary) -> bool: return event.target == 1)[0]
	check(payment.changes == [{"seat":0,"amount":-4},{"seat":1,"amount":4}], "Rent produces a red loss and matching green gain with the exact payment")
	check(host.ui.player_cards[1].portfolio.entries.size() == 2 and host.ui.player_cards[0].portfolio.entries.is_empty(), "Host keeps each deed under its authoritative owner's name")
	check(host.ui.player_cards.all(func(card: Dictionary) -> bool: return card.panel is PanelContainer and host.ui.ledger.is_ancestor_of(card.panel)), "Every player has a separate panel in the left roster")
	var balance: Rect2 = host.ui.effects.money_rect(1)
	var above := GameMoneyEffect.amount_rect(balance, 4, .5); var below := GameMoneyEffect.amount_rect(balance, -4, .5)
	check(above.end.y < balance.position.y and below.position.y > balance.end.y and is_equal_approx(above.get_center().x, balance.get_center().x) and is_equal_approx(below.get_center().x, balance.get_center().x), "Signed money feedback stays centered above gains and below losses at the exact balance")
	host._step(float(payment.start) + .45); await capture("cash-transfer")
	reset(); before = host.rules.s.cash.duplicate(); host.rules.events.clear(); host.rules._draw_card("chance", 0); host.rules._drain(); begin_rules(before)
	check(host.motion.cards.effects.size() > 0 and host.motion.specials.all(func(effect: Dictionary) -> bool: return effect.kind != "chest"), "Chance uses card motion without opening a Community Chest")
	host.session.reduced_motion = true; reset(); host.rules.s.owners[1] = 0; before = host.rules.s.cash.duplicate()
	check(host._act(0, {"action":"mortgage","property":1}) and not host._animating() and host.ui.board.moves.is_empty(), "Reduced motion settles money changes immediately without a movement lock")
	check(host.ui.effects.cash.static_left > 0 and host.ui.effects.cash.events[0].changes[0].amount == 30, "Reduced motion keeps compact static green cash feedback")
	await capture("reduced-money")
	check(not host.ui.clock.text.contains("PRACTICE") and host.ui.activity.bold_latest and not host.ui.activity.heading.visible, "Footer omits practice and Activity has one heading with bold newest feedback")
	reset(); host.rules.s.owners[1] = 0; host.rules.s.owners[3] = 1; host._publish(); host.ui.show_trade()
	for frame in 8: await process_frame
	var giving = host.ui.trade_dialog.body.find_child("GiveProperties", true, false)
	var taking = host.ui.trade_dialog.body.find_child("TakeProperties", true, false)
	check(giving is GameCardGrid and taking is GameCardGrid and host.ui.trade_dialog.body.find_children("*", "CheckButton", true, false).is_empty(), "Trade presents real selectable property faces without text toggles")
	await tap(giving.get_child(0)); await tap(taking.get_child(0)); await capture("trade-cards-selected")
	check(giving.selected == [1] and taking.selected == [3], "Tapping property faces highlights the exact offered and requested deeds")
	await tap(host.ui.trade_dialog.actions.get_child(0))
	check(host.rules.s.phase == "trade" and host.rules.s.trade.give_properties == [1] and host.rules.s.trade.take_properties == [3], "Trade submits the selected card IDs only on Send Offer")
	# Hit the actual header, not the signal: the old header swallowed this click.
	app._return_from_game(); app._launch_game(app.game_catalog.find_game("monopoly")); app._on_collection_choice("monopoly-deal")
	for frame in 10: await process_frame
	var deal = app.active_game
	deal.ai_timer.stop(); await tap(deal.screen.back_button)
	check(app.active_game_id == "monopoly", "Deal's actual Back hit target returns to the chooser")
	await tap(app.active_game.screen.back_button)
	check(app.current_state == "game_menu", "Chooser Back returns to game selection")
	# Exercise the same fixed header while a modal is open, and without a parent collection.
	app._launch_game(app.game_catalog.find_game("monopoly-deal")); deal = app.active_game
	deal.settings_button.button_pressed = true
	for frame in 8: await process_frame
	await tap(deal.screen.back_button)
	check(app.current_state == "game_menu", "Deal Back remains reachable from Settings and direct launches")
	app._launch_game(app.game_catalog.find_game("monopoly-deal")); deal = app.active_game
	deal.settings_button.button_pressed = true
	for frame in 8: await process_frame
	deal.settings_button.button_pressed = false
	deal.reader.show_card({"id":1,"name":"Read a card","value":1}, null, Color("17594d"), [])
	for frame in 8: await process_frame
	await tap(deal.screen.back_button)
	check(app.active_game_id == "monopoly-deal", "After closing Settings, enlarged readers cannot expose an invisible game-exit target")
	deal.reader.close(); app._return_from_game()
	var template = load("res://Games/_Template/host/main.tscn").instantiate()
	root.add_child(template)
	var context := GameSessionContext.new("template", [], {"id":"test-host", "display_name":"Template Host", "color":"#2463eb"}, false)
	context.reduced_motion = true; template.initialize_session(context); template.start_game()
	for size in [Vector2i(390,844), Vector2i(844,390)]:
		root.size = size; root.content_scale_size = size
		for frame in 8: await process_frame
		check(template.screen.back_button.get_global_rect().position.x >= 0, "Template retains shared navigation at %s" % size)
		check(template.get_children().any(func(child: Node) -> bool: return child is GameMoneyEffect), "Template includes the shared cash-feedback hook")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder + "template-%dx%d.png" % [size.x,size.y])
	template.shutdown_game(); template.queue_free()
	app.lan_server.stop_server(); app.queue_free(); await process_frame
	await create_timer(.2).timeout
	print("Monopoly Classic motion/navigation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
