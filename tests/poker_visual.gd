extends SceneTree

const Settings = preload("res://tests/game_settings_fixture.gd")
var folder := "res://.test_data/poker-visual/"
var failures := 0
var checks := 0


func _init() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)


func capture(name: String) -> void:
	root.content_scale_size = root.size
	for frame in 18: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png(folder + name + ".png")


func lineup(count: int) -> Array:
	var result: Array = []
	for index in count: result.append({"id": "visual-%d" % index, "display_name": ["MoonWalker", "LuckyCat", "AcePilot", "Blaze", "NeonTiger", "TheDoc", "ZenMaster", "RiverRat", "Sundance", "CardShark"][index], "color": Color.from_hsv(index / 10.0, .8, .85).to_html(), "pose": index % 6})
	return result


func host_for(mode: String, count: int, reduced := true):
	var id := "poker-omaha" if mode == "omaha" else "poker-texas-holdem"
	var host = load("res://Games/%s/host/main.tscn" % id).instantiate(); host.settings_store = Settings.new(); host.saved_game.path = folder + "saves/%s-%d-%d.json" % [mode, count, Time.get_ticks_usec()]
	root.add_child(host)
	var context := GameSessionContext.new(id, lineup(count), {"id": "host", "display_name": "MoonWalker", "color": "#2463eb", "pose": 0}, count > 0); context.reduced_motion = reduced
	host.initialize_session(context); host.start_game(); host.set_process(false); return host


func finish(host) -> void:
	for step in 1500:
		if host.rules.phase == "finished": return
		if host.rules.phase in ["hand_over", "runout"]: host._process(6)
		else:
			var legal: Dictionary = host.rules.legal(host.rules.turn)
			host._action(host.rules.turn, {"action": "raise" if legal.can_raise else "check" if legal.check else "call", "amount": legal.max_raise_to, "revision": host.rules.revision})


func tap(point: Vector2) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true; event.position = point; event.global_position = point
	root.push_input(event, true); await process_frame; event.pressed = false; root.push_input(event, true); await process_frame


func check_table_space(host, layout: String) -> void:
	var table = host.ui.table
	var board: Rect2 = table.resolve({"zone":"board","index":0}).merge(table.resolve({"zone":"board","index":4}))
	check(table.felt_rect().encloses(board), layout + " keeps every community card inside the felt")
	check(not board.intersects(table.counter_rect()) and not board.intersects(table.counter_rect(true)), layout + " separates community cards from the pot and current bet")
	for seat in host.seats.size():
		var badge: Rect2 = table.seat_rect(seat)
		check(badge.encloses(table.bet_rect(seat)), layout + " keeps chip bets inside player boxes")
		for other in range(seat + 1, host.seats.size()): check(not badge.intersects(table.seat_rect(other)), layout + " keeps every player's badge separate")
		check(not badge.intersects(board), layout + " separates every player badge from community cards")
		check(not badge.intersects(table.counter_rect()) and not badge.intersects(table.counter_rect(true)), layout + " separates every player badge from betting counters")
		check(not Rect2(table.global_position + badge.position, badge.size).intersects(host.ui.summary_panel.get_global_rect()), layout + " keeps the corner summary clear of player badges")
	if host.host_plays:
		var panel: Rect2 = host.ui.solo_panel.get_global_rect()
		var badge := Rect2(table.global_position + table.seat_rect(0).position, table.seat_rect(0).size)
		check(panel.end.y <= root.size.y - 14 and panel.end.y >= root.size.y - 18, layout + " anchors the solo panel at the bottom inset")
		check(panel.encloses(host.ui.local_row.get_global_rect()) and panel.encloses(host.ui.raise_panel.get_global_rect()) and panel.encloses(host.ui.private_hand.get_global_rect()), layout + " contains all solo controls and hole cards within the themed panel")
		check(panel.encloses(host.ui.summary_panel.get_global_rect()), layout + " keeps hand and blind information inside the solo panel")
		check(badge.end.y + 12 <= panel.position.y and not badge.intersects(panel), layout + " keeps the host badge below the table and outside the panel")
		check(table.global_position.y + table.table_height() * 1.3 + 12 <= panel.position.y, layout + " leaves a visible gap between table artwork and the bottom panel")
		check(not host.ui.summary_panel.get_global_rect().intersects(host.ui.private_hand.get_global_rect()) and not host.ui.summary_panel.get_global_rect().intersects(host.ui.local_row.get_global_rect()), layout + " separates the panel's stats from cards and actions")
		check(host.ui.private_hand.get_global_rect().is_equal_approx(Rect2(table.global_position + table.private_layout().hand.position, table.private_layout().hand.size)), layout + " shares exact card geometry between the dock and deal animations")
	else: check(not host.ui.solo_panel.visible, layout + " omits the solo panel on the public phone-host display")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(folder); root.size = Vector2i(1280, 720)
	var catalog := GameCatalog.new(); catalog.scan()
	check(catalog.find_game("poker").get("game_choices", []).size() == 2 and catalog.menu_games().filter(func(item: Dictionary) -> bool: return item.id.begins_with("poker")).size() == 1, "Only the Poker collection appears in the catalog menu")
	var chooser = load("res://Games/poker/host/main.tscn").instantiate(); root.add_child(chooser)
	var context := GameSessionContext.new("poker", [], {"display_name": "Host"}); context.reduced_motion = true
	for id in ["poker-texas-holdem", "poker-omaha"]:
		var choice: Dictionary = catalog.find_game(id).duplicate(true); choice.can_launch = true; context.game_choices.append(choice)
	chooser.initialize_session(context); chooser.start_game(); await capture("chooser-landscape")
	check(chooser.choices.get_child_count() == 2 and chooser.choices.columns == 2, "Chooser has both illustrated modes")
	root.size = Vector2i(600, 900); await capture("chooser-portrait")
	check(chooser.choices.columns == 1, "Chooser wraps vertically on a portrait host")
	chooser.shutdown_game(); chooser.queue_free(); await process_frame
	root.size = Vector2i(1280, 720)
	for mode: String in ["texas", "omaha"]:
		var host = host_for(mode, 10); await capture(mode + "-ten-host")
		check_table_space(host, "Wide ten-seat table")
		check(host.ui.table.get_global_rect().position.x >= 0 and host.ui.table.get_global_rect().end.x <= root.size.x + 2, "Ten-seat host table fits horizontally")
		check(host.ui.toolbar.get_global_rect().end.y <= root.size.y + 2, "Host actions remain reachable without scrolling")
		check(host.ui.table.size.x >= 960 and host.ui.table.size.x <= 1100 and host.ui.table.resolve({"zone":"board"}).size.x >= 70, "Public table uses a modest enlargement with readable community cards")
		check(absf(host.ui.table.seat_rect(0).get_center().x - host.ui.table.size.x / 2) < 1 and absf(host.ui.table.seat_rect(5).get_center().x - host.ui.table.size.x / 2) < 1 and host.ui.table.seat_rect(0).position.y > host.ui.table.seat_rect(5).end.y, "Full rosters sit around the oval with seats at the top and bottom")
		check(range(10).all(func(seat: int) -> bool: return host.ui.table.seat_rect(seat).size.x <= 210), "Player badges stay compact around the table")
		check(host.ui.phase_track.get_global_rect().end.y <= 60, "Stage map fits in the compact header")
		check(host.ui.screen.title_label.get_global_rect().position.x >= 60 and host.ui.screen.title_label.get_global_rect().end.x < 310, "Poker title sits beside Back at the left")
		check(host.ui.settings_button.get_global_rect().position.x > root.size.x - 130, "Settings sits beside the music controls")
		check(host.motion.view(-1, 0, true).flights.filter(func(flight: Dictionary) -> bool: return flight.to.zone == "hand").all(func(flight: Dictionary) -> bool: return flight.card.get("back", false)), "Public dealing flights expose only neutral backs")
		for first in 10:
			for second in range(first + 1, 10): check(not host.ui.table.seat_rect(first).intersects(host.ui.table.seat_rect(second)), "Wide ten-seat identities remain separate")
		root.size = Vector2i(600, 900); await capture(mode + "-ten-portrait")
		check_table_space(host, "Portrait ten-seat table")
		for first in 10:
			for second in range(first + 1, 10): check(not host.ui.table.seat_rect(first).intersects(host.ui.table.seat_rect(second)), "Portrait ten-seat identities remain separate")
		root.size = Vector2i(1280, 540); await capture(mode + "-ten-short"); check(host.ui.toolbar.get_global_rect().end.y <= root.size.y + 2, "Short host retains reachable actions")
		check_table_space(host, "Short ten-seat table")
		root.size = Vector2i(1280, 720); root.content_scale_size = root.size
		host.ui.open_settings(); await capture(mode + "-settings")
		check(host.ui.settings_dialog.panel.size.x <= 700 and host.ui.settings_dialog.panel.size.y < 560, "Settings fits its grouped contents without a full-screen empty sheet")
		check(host.ui.controls.starting_chips.size.x > 100, "Settings fields use the available section width")
		root.size = Vector2i(600, 900); await capture(mode + "-settings-portrait")
		check(root.get_visible_rect().encloses(host.ui.apply.get_global_rect()), "Portrait settings retains reachable Apply")
		root.size = Vector2i(1280, 540); await capture(mode + "-settings-short")
		check(root.get_visible_rect().encloses(host.ui.apply.get_global_rect()), "Short settings retains reachable Apply")
		root.size = Vector2i(1280, 720); host.ui.close_settings()
		finish(host); await capture(mode + "-ten-results")
		check(not host.ui.public_cards_dialog.scroll.get_v_scroll_bar().visible, "Ten-player host results fit without a scrollbar")
		check(host.ui.ranked_results.entries.size() == host._snapshot(0).hand_results.filter(func(entry: Dictionary) -> bool: return int(entry.rank) > 0).size(), "Results retain revealed contenders and hide folded or previously eliminated seats")
		check(host.ui.public_cards_dialog.heading.text.begins_with(host.seats[host.rules.winner].display_name + " with "), "Results heading names the winner and the winning hand")
		for entry in host.ui.ranked_results.entries:
			var source: Array = host.rules.players[int(entry.seat)].hand
			check(entry.marked_cards == range(entry.cards.size()).filter(func(index: int) -> bool: return source.has(entry.cards[index].id)), "Result highlights identify each player's actual hole cards in the best five")
			if mode == "omaha": check(entry.marked_cards.size() == 2, "Every Omaha result highlights exactly two hole cards")
		check(host.ui.ranked_results.entries.any(func(entry: Dictionary) -> bool: return entry.amount < 0), "Ranked results retain negative net hand changes")
		var results_file := FileAccess.open(folder + mode + "-results-controller.json", FileAccess.WRITE); results_file.store_string(JSON.stringify(host._snapshot(0))); results_file.close()
		root.size = Vector2i(600, 900); await capture(mode + "-results-portrait")
		check(root.get_visible_rect().encloses(host.ui.review_close.get_global_rect()), "Portrait results keep actions outside the scrolling rankings")
		root.min_size = Vector2i(1, 1); root.size = Vector2i(390, 844); await capture(mode + "-results-small")
		check(root.get_visible_rect().encloses(host.ui.review_close.get_global_rect()), "Small host results keep the review action reachable")
		check(host.ui.ranked_results.card_rects().all(func(rect: Rect2) -> bool: return rect.end.x <= host.ui.ranked_results.size.x), "Resizing existing results fits every best-five card without horizontal cropping")
		check(host.ui.ranked_results.card_rects().all(func(rect: Rect2) -> bool: return absf(rect.size.x / rect.size.y - 2.0 / 3.0) < .02), "Native ranked cards preserve their portrait proportions")
		root.size = Vector2i(1280, 540); await capture(mode + "-results-short")
		check(not host.ui.public_cards_dialog.scroll.get_v_scroll_bar().visible, "Compact columns fit the full results on a short host")
		check(root.get_visible_rect().encloses(host.ui.review_close.get_global_rect()), "Short results keep actions outside the scrolling rankings")
		root.size = Vector2i(1280, 720); host._process(12); host._publish(); host.ui.public_cards_dialog.overlay.hide(); await capture(mode + "-eliminated-table")
		host.shutdown_game(); host.queue_free(); await process_frame
		host = host_for(mode, 2)
		host._action(0, {"action": "call", "revision": host.rules.revision}); host._action(1, {"action": "check", "revision": host.rules.revision}); host._action(1, {"action": "raise", "amount": 20, "revision": host.rules.revision})
		var snapshot: Dictionary = host._snapshot(0); snapshot.reduced_motion = false
		var file := FileAccess.open(folder + mode + "-controller.json", FileAccess.WRITE); file.store_string(JSON.stringify(snapshot)); file.close()
		await capture(mode + "-flop-host")
		root.size = Vector2i(600, 900); await capture(mode + "-portrait-host"); root.size = Vector2i(1280, 720)
		host.shutdown_game(); host.queue_free(); await process_frame
		host = host_for(mode, 3); host._action(host.rules.turn, {"action":"fold","revision":host.rules.revision}); await capture(mode + "-folded-host")
		host.shutdown_game(); host.queue_free(); await process_frame
		host = host_for(mode, 0); await capture(mode + "-solo-host")
		check_table_space(host, "Solo table")
		var hand_rect: Rect2 = host.ui.table.resolve({"zone":"hand","seat":0})
		check(host.ui.table.seat_rect(0).size.y >= host.ui.table.seat_rect(1).size.y and host.ui.table.seat_rect(0).size.x >= host.ui.table.seat_rect(1).size.x, "The local host badge has at least the same room as the other player's badge")
		check(host.ui.local_row.get_global_rect().end.x < host.ui.table.global_position.x + hand_rect.position.x and host.ui.raise_panel.get_global_rect().position.x > host.ui.table.global_position.x + host.ui.table.private_layout().hand.end.x, "Solo actions flank the host's private cards")
		var before_revision: int = host.rules.revision
		check(host.ui.local_row.get_child_count() == 2 and absf(host.ui.raise_panel.size.x - host.ui.fold.size.x) < 1, "Fold and Call flank a compact betting editor of matching width")
		check(absf(host.ui.table.private_layout().hand.get_center().x - host.ui.table.size.x / 2) < 1, "Host hole cards stay centered independently of control widths")
		check(host.ui.table.seat_rect(0).end.y + 14 <= host.ui.table.private_layout().hand.position.y, "Host identity sits above the hole cards outside the bottom panel")
		root.size = Vector2i(600, 900); await capture(mode + "-solo-portrait")
		check_table_space(host, "Portrait solo panel")
		root.size = Vector2i(390, 844); await capture(mode + "-solo-small")
		check_table_space(host, "Portrait solo table")
		check(absf(host.ui.local_row.size.x - host.ui.raise_panel.size.x) < 1 and root.get_visible_rect().encloses(host.ui.bet_button.get_global_rect()), "Portrait solo betting controls keep equal widths and remain reachable")
		root.size = Vector2i(1280, 720); await capture(mode + "-solo-restored")
		host.ui.raise_slider.value = host.rules.legal(0).max_raise_to
		check(host.ui.raise_amount.value == host.ui.raise_slider.value and host.ui.bet_button.text == ("ALL IN" if mode == "texas" else "BET"), "Slider and typed amount synchronize and the button respects all-in eligibility")
		var maximum: int = host.rules.legal(0).max_raise_to
		host.ui.raise_amount.get_line_edit().text = str(maximum); host._publish()
		check(host.ui.raise_amount.get_line_edit().text == str(maximum), "Clock snapshots preserve the custom raise input")
		await tap(host.ui.bet_button.get_global_rect().get_center())
		check(host.rules.revision == before_revision + 1 and host.rules.current_bet == maximum, "BET commits the explicit slider or custom total once")
		root.size = Vector2i(1280, 540); await capture(mode + "-solo-short")
		check_table_space(host, "Short solo table")
		check(root.get_visible_rect().encloses(host.ui.bet_button.get_global_rect()), "Short solo hosts retain the explicit bet button")
		root.size = Vector2i(1280, 720); await capture(mode + "-solo-restored")
		var center: Vector2 = host.ui.table.get_global_rect().get_center(); finish(host); await capture(mode + "-finished-host")
		check(host.ui.replay.visible and root.get_visible_rect().encloses(host.ui.replay.get_global_rect()) and host.ui.public_cards_dialog.panel.get_global_rect().encloses(host.ui.replay.get_global_rect()), "Finished results expose the single replay in the shared dialog action area")
		check(host.ui.table.get_global_rect().get_center().distance_to(center) < 1, "Round completion retains the shared board center")
		check(host.ui.public_cards_dialog.overlay.visible and host.ui.replay.disabled, "Ranked results open automatically and prevent an early replay")
		check(host.ui.review_close.text.contains("12") and not host.ui.review_close.disabled and not host.ui.review_countdown.visible, "Results combine an enabled host Continue button with the countdown")
		await tap(host.ui.review_close.get_global_rect().get_center())
		check(not host.ui.public_cards_dialog.overlay.visible and host.phase_remaining == 0 and not host.ui.replay.disabled, "A real host Continue press skips the final countdown and enables Play Again")
		host.ui.show_results(); await capture(mode + "-pots"); check(host.paused(), "Public pot reader pauses the table"); host.ui.public_cards_dialog.overlay.hide()
		await tap(host.ui.replay.get_global_rect().get_center()); check(host.rules.hand_number == 1 and host.rules.phase != "finished", "A real mouse press on Play Again starts a fresh tournament")
		host.options.solo_ai = 9; host.new_tournament(); await capture(mode + "-solo-ten")
		check_table_space(host, "Ten-seat solo table")
		root.size = Vector2i(1280, 540); await capture(mode + "-solo-ten-short")
		check_table_space(host, "Short ten-seat solo table")
		check(host.ui.table.resolve({"zone":"board"}).size.x >= 28, "Short full tables reserve readable space for community cards")
		for seat in range(1, 10):
			var badge: Rect2 = host.ui.table.seat_rect(seat)
			check(badge.size.y >= 42, "Short solo rosters keep room for three status lines")
			check(not badge.intersects(host.ui.table.private_layout().hand), "Solo oval seating leaves the private cards clear")
			var global_badge := Rect2(host.ui.table.global_position + badge.position, badge.size)
			check(not global_badge.intersects(host.ui.local_row.get_global_rect()) and not global_badge.intersects(host.ui.raise_panel.get_global_rect()), "Solo oval seating leaves betting controls clear")
		root.size = Vector2i(1280, 720)
		host.shutdown_game(); host.queue_free(); await process_frame
		host = host_for(mode, 10)
		var folded: int = host.rules.turn; host._action(folded, {"action": "fold", "revision": host.rules.revision})
		for step in 1000:
			if host.rules.phase != "betting": break
			var legal: Dictionary = host.rules.legal(host.rules.turn)
			host._action(host.rules.turn, {"action": "raise" if legal.can_raise else "check" if legal.check else "call", "amount": legal.max_raise_to, "revision": host.rules.revision})
		await capture(mode + "-all-in-runout")
		check(host.rules.phase == "runout" and host.rules.board.is_empty(), "Anticipation reveals begin before any community cards are dealt")
		for seat in 10:
			var faces: Array = host.ui.table.revealed_hand(seat)
			check(faces.size() == (0 if seat == folded else 4 if mode == "omaha" else 2), "Runout fans reveal eligible hands and omit the folded player")
			if faces.is_empty(): continue
			check(faces[0].angle < 0 and faces[-1].angle > 0 and faces.all(func(face: Dictionary) -> bool: return face.pivot.y > host.ui.table.seat_rect(seat).position.y), "Public hole cards fan diagonally with their lower halves behind player badges")
		root.size = Vector2i(600, 900); await capture(mode + "-all-in-portrait")
		root.size = Vector2i(1280, 540); await capture(mode + "-all-in-short")
		root.size = Vector2i(1280, 720); host.shutdown_game(); host.queue_free(); await process_frame
	var moving = host_for("omaha", 10, false); moving._process(.9); moving._publish(); await capture("omaha-dealing"); moving.shutdown_game(); moving.queue_free(); await process_frame
	moving = host_for("texas", 0, false); moving._process(.45); moving._publish(); await capture("texas-solo-dealing")
	check(moving.animating() and moving.ui.fold.disabled and moving.ui.private_hand.is_visible_in_tree(), "The solo dock keeps its card-dealing layer visible while betting input is locked")
	check_table_space(moving, "Moving solo panel")
	moving._process(moving.motion_duration); moving._publish(); await capture("texas-solo-dealt")
	check(not moving.animating() and not moving.ui.fold.disabled, "The same dock controls unlock after the opening cards land")
	moving.shutdown_game(); moving.queue_free(); await process_frame
	print("Poker visual: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
