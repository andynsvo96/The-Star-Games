extends SceneTree

var output := "res://.test_data/uno-ui-refresh/"
var checks := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func capture(name: String) -> void:
	for frame in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + name + ".png")


func resize_view(dimensions: Vector2i) -> void:
	root.min_size = Vector2i.ONE
	root.content_scale_size = dimensions
	root.size = dimensions
	for frame in 8: await process_frame


func click_button(button: Button) -> void:
	await click_point(button.get_global_rect().get_center())


func click_point(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		if pressed: await create_timer(.12).timeout
		else:
			for frame in 3: await process_frame


func orbit_is_clear(table: Control) -> bool:
	var obstacles: Array[Rect2] = []
	for rect: Rect2 in table.seat_rects: obstacles.append(rect)
	var font := GameLook.party_font(table.get_theme_default_font())
	var short: bool = table.size.y < 300 and table.size.x > table.size.y * 1.8
	var font_size: int = 10 if short else 12 if table.size.x < 500 else int(15 * table._ui_scale())
	for index in 2:
		var caption: Rect2 = table.pile_caption_rects[index]
		var width := font.get_string_size("DRAW" if index == 0 else "DISCARD", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		obstacles.append(Rect2(Vector2(caption.get_center().x - width / 2, caption.position.y), Vector2(width, caption.size.y)))
	for phase in 24:
		for ribbon: PackedVector2Array in table._direction_ribbons(table.size.x / 1000.0, phase * TAU / 24):
			for index in obstacles.size():
				var rect := obstacles[index]
				var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
				if not Geometry2D.intersect_polygons(ribbon, corners).is_empty():
					print("Orbit collision: phase ", phase, " obstacle ", index, " ", rect, " table ", table.size)
					return false
	return true


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	for identity in LanServer.PLAYER_COLORS:
		check(GameLook.text_contrast(Color.WHITE, GameLook.party_identity_fill(Color(identity))) >= 5.5, "Party avatar backgrounds keep the shared white silhouette visible for %s" % identity)
		for active in [false, true]:
			var plaque := GameLook.party_player_sheet(Color(identity), active)
			check(GameLook.text_contrast(Color.WHITE, plaque.bg_color.lerp(Color.WHITE, .08)) >= 4.5, "Party names remain readable for identity %s, active %s" % [identity, active])
	await resize_view(Vector2i(1280, 720))
	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new(output + "profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	app._play_from_lobby()
	var entries: Array = app.game_catalog.games.filter(func(game: Dictionary) -> bool: return game.id == "uno")
	check(entries.size() == 1 and entries[0].background == "art/sunset-lounge", "UNO discovers once with its extensionless new background")
	app._launch_game(entries[0])
	var host = app.active_game
	for timer in [host.ai_timer, host.auto_timer, host.jump_timer, host.catch_timer]: timer.process_mode = Node.PROCESS_MODE_DISABLED
	host.rules.pending_draw = 0
	host.rules.turn = 0
	host.rules.phase = "play"
	host.rules.drawn = -1
	host.rules.hands[0] = [0, 3, 9, 30, 59, 79, 100]
	host.rules.color = "red"
	host._publish()
	await capture("solo-desktop")
	check(not host.screen.title_label.visible and not host.screen.scores.visible and not host.screen.status.visible, "Ordinary title, scores and round status stay omitted")
	check(host.table.seat_rects[0].position.y > host.table.top_rect.end.y, "The host status sits below the central piles")
	check(host.table.hand_rect.position.y > host.table.seat_rects[0].end.y, "The private hand sits below the host status")
	check(host.table.fan_angles[1] < 0 and host.table.fan_angles[3] > 0 and is_zero_approx(host.table.fan_angles[2]), "Side hands angle diagonally while the top hand stays in a gentle arc")
	check(host.table.orbit_rect.size.x > host.table.deck_rect.merge(host.table.top_rect).size.x * 1.6, "Broad direction arrows surround both piles")
	check(orbit_is_clear(host.table), "Both rotating arrows stay clear of captions and badges for a full turn")
	check(host.table.hand_hits[0].rect.size.x >= 60, "Desktop solo hand uses larger readable cards")
	check(host.table.hand_hits.front().angle < 0 and host.table.hand_hits.back().angle > 0, "The private hand curves in both directions")
	check(host.table.uno_button.visible and host.table.uno_button.disabled, "UNO remains visible and disabled for an ordinary hand")
	check(host.table.uno_button.icon_alignment == HORIZONTAL_ALIGNMENT_CENTER, "The solo UNO artwork centers inside its button")
	check(host.actions.draw.visible and not host.actions.draw.disabled, "The host's ordinary turn enables the persistent Draw action")
	check(host.actions.draw.alignment == HORIZONTAL_ALIGNMENT_LEFT and host.actions.draw.get_theme_stylebox("normal").content_margin_left > 10, "The Draw icon and label form one centered group")
	check(host.table.seat_rects.all(func(rect: Rect2) -> bool: return rect.size.is_equal_approx(host.table.seat_rects[0].size)), "Every wide solo player uses the same stat badge dimensions")
	check(host.table.fan_rects[2].size.x >= host.table.fan_rects[1].size.x * .8, "The top computer has a full-sized fan")
	check(is_equal_approx(host.table.orbit_top_radius, host.table.orbit_radii.y), "Both halves of the rotation arrows share one projected circle")
	check(host.table.fan_rects[2].end.y < host.table.orbit_rect.position.y, "The lowered top hand clears the complete arrow orbit")
	check(host.active_rules.visible and host.active_rules.compact and not host.active_rules.body.visible, "Solo rules start collapsed at desktop size")
	check(is_equal_approx(host.active_rules.global_position.x, 24), "Solo rules stay collapsed in the left corner outside the table fitter")
	await click_button(host.active_rules.heading)
	check(host.active_rules.body.visible and host.rules_dialog.overlay.visible, "Solo desktop rules open in the shared centered help dialog")
	check(host.table.get_global_rect().is_equal_approx(host.screen.board_anchor.get_global_rect()), "Opening rules keeps the table in its shared fitted position")
	await click_button(host.active_rules.heading)
	check(host.table.seat_rects[0].size.x <= host.table.size.x * .40 and host.table.seat_rects[3].position.x > host.table.top_rect.end.x, "Wide solo view keeps its owner badge centered and opponents along the rim")
	var center: Vector2 = host.table.orbit_center
	check(host.table.seat_rects[1].get_center().x < center.x and host.table.seat_rects[3].get_center().x > center.x, "A positive turn sequence follows the clockwise arrows from the host's bottom seat")
	for dimensions in [Vector2i(1920,1080), Vector2i(2370,1347)]:
		await resize_view(dimensions)
		await capture("solo-%dx%d" % [dimensions.x,dimensions.y])
		check(host.table.hand_hits.all(func(hit: Dictionary) -> bool: return not host.table.seat_rects.any(func(rect: Rect2) -> bool: return rect.intersects(hit.rect))), "Large solo layouts keep every opponent clear of the private fan at %s" % dimensions)
		check(host.table.seat_rects[0].size.is_equal_approx(host.table.seat_rects[2].size), "Host and computer stat sizes still match at %s" % dimensions)
		for seat in range(1, host.seats.size()):
			var badge: Rect2 = host.table.seat_rects[seat]
			var fan: Rect2 = host.table.fan_rects[seat]
			check((host.table.global_position + badge.position).y >= host.screen.content_scroll.global_position.y, "The complete computer stats stay below the clipping edge at %s" % dimensions)
			check(fan.position.y > badge.end.y and fan.position.y - badge.end.y <= 6 * host.table.size.x / 1000.0 + 1, "Opponent cards sit directly beneath their stats at %s" % dimensions)
			check(absf(fan.get_center().x - badge.get_center().x) < 1, "Opponent card artwork centers beneath its stats at %s" % dimensions)
	await resize_view(Vector2i(1280,720))
	var settings: Button = host.settings_body.get_parent().get_meta("toggle_button")
	check(settings.get_global_rect().position.x > 1000 and settings.get_global_rect().position.y < 50, "Settings docks beside the music controls")
	var table_before: Rect2 = host.table.get_global_rect()
	settings.button_pressed = true
	await capture("settings-desktop")
	check(host.settings_open and host.table.state.paused and host.motion_timer.paused, "Settings pauses authoritative input and movement")
	var revision: int = host.rules.revision
	host._local_action({"action":"draw"})
	check(host.rules.revision == revision, "Commands during Settings are discarded")
	settings.button_pressed = false
	await capture("settings-closed")
	check(host.table.get_global_rect().is_equal_approx(table_before) and not host.table.state.paused, "Closing Settings restores the same centered table")
	var authoritative: Array = host.rules.hands[0].duplicate()
	await click_button(host.table.sort_button)
	var legal: Array = host.rules.legal_cards(0)
	check(host.table.state.hand.slice(0, legal.size()).all(func(card: Dictionary) -> bool: return legal.has(card.id)), "Native playable mode puts legal cards first")
	check(host.rules.hands[0] == authoritative, "Sorting changes presentation only")
	await click_button(host.table.sort_button)
	check(host.table.state.hand == host.Rules.sorted_hand(host.table.state.hand), "Native color mode restores the established number/action/Wild order")
	host.rules.hands[0] = [3, 9]
	host.rules.revision += 1
	host._publish()
	await capture("uno-ready")
	check(host.table.uno_button.visible and not host.table.uno_button.disabled, "UNO enables before the eligible penultimate play")
	await click_button(host.table.uno_button)
	await capture("uno-called")
	check(host.rules.armed[0] and host.table.uno_button.visible and host.table.uno_button.disabled, "UNO declares separately and greys out after acceptance")
	host.session.reduced_motion = false
	var play_hit: Dictionary = host.table.hand_hits.filter(func(hit: Dictionary) -> bool: return hit.id == 3)[0]
	var play_point: Vector2 = play_hit.rect.get_center() + Vector2(-play_hit.rect.size.x * .35, 0).rotated(play_hit.angle)
	await click_point(host.table.get_global_transform() * play_point)
	await capture("card-play-flight")
	check(not host.table.flights.is_empty() and host.animating, "Native played card flies to the discard and locks input")
	host._publish()
	check(host.table.get_global_rect().is_equal_approx(table_before), "Playing a card does not shift the centered table")
	var moving_revision: int = host.rules.revision
	host._local_action({"action":"draw"})
	check(host.rules.revision == moving_revision, "Taps during a native card flight are discarded")
	await create_timer(.65).timeout
	host.rules.turn = 0
	host.rules.phase = "play"
	host.rules.drawn = -1
	host.rules.pending_draw = 0
	host.rules.hands[0] = range(18)
	host.rules.color = "red"
	host.rules.revision += 1
	host.rules.motion.clear()
	host._publish()
	await capture("large-hand-start")
	check(host.table.hand_right.accessibility_name.contains("11 stacked") and host.table.hand_right.size.x >= 44, "The visible end-stack cue names the hidden cards and retains a full touch target")
	var browse_revision: int = host.rules.revision
	var press := InputEventMouseButton.new()
	press.position = host.table.hand_right.get_global_rect().get_center()
	press.global_position = press.position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press)
	await create_timer(.65).timeout
	press.pressed = false
	root.push_input(press)
	await create_timer(.3).timeout
	check(host.table.hand_start >= 6 and host.rules.revision == browse_revision, "Holding a native end stack browses repeatedly without playing")
	while host.table.hand_start < host.rules.hands[0].size() - 7:
		host.table._shift_hand(3)
		await create_timer(.3).timeout
	await capture("large-hand-end")
	var last: int = host.table.state.hand.back().id
	check(host.table.hand_hits.any(func(hit: Dictionary) -> bool: return hit.id == last) and host.table.hand_left.visible and not host.table.hand_right.visible, "Sorted hand remains fully reachable through its end stacks")
	host.rules.drawn = last
	host.rules.revision += 1
	host._publish()
	await capture("drawn-card-decision")
	check(host.table.drawn_rect.has_area() and host.table.drawn_play.visible and host.table.drawn_keep.visible, "Native drawn card and explicit Play/Keep choices remain visible")
	await click_button(host.table.drawn_keep)
	check(host.rules.drawn == -1 and host.rules.hands[0].has(last) and host.rules.turn != 0, "A held mouse click keeps the focused drawn card")
	host.rules.turn = 0
	host.rules.drawn = last
	host.rules.revision += 1
	host._publish()
	await capture("drawn-play-ready")
	await click_button(host.table.drawn_play)
	check(host.rules.drawn == -1 and not host.rules.hands[0].has(last), "A held mouse click plays the focused drawn card")
	await create_timer(.65).timeout
	host.session.reduced_motion = true
	host.rules.turn = 0
	host.rules.motion.clear()
	host._publish()
	for dimensions in [Vector2i(390,844), Vector2i(844,390), Vector2i(568,320)]:
		await resize_view(dimensions)
		await capture("solo-%dx%d" % [dimensions.x,dimensions.y])
		check(host.table.get_global_rect().position.x >= 0 and host.table.get_global_rect().end.x <= dimensions.x and host.table.get_global_rect().end.y <= dimensions.y, "Solo table fits %s" % dimensions)
		check(host.table.seat_rects.all(func(rect: Rect2) -> bool: return rect.position.x >= 0 and rect.end.x <= host.table.size.x), "Solo badges stay inside %s" % dimensions)
		check(host.table.fan_centers.size() == host.seats.size(), "Every seat restores its card-fan origin at %s" % dimensions)
		check(host.table.hand_hits.all(func(hit: Dictionary) -> bool: return not host.table.seat_rects.any(func(rect: Rect2) -> bool: return rect.intersects(hit.rect))), "Private cards stay below the compact roster at %s" % dimensions)
		check(host.active_rules.get_global_rect().end.x <= dimensions.x and is_equal_approx(host.active_rules.global_position.x, 24), "Rules remain reachable in the left corner on narrow hosts at %s" % dimensions)
		await click_button(host.active_rules.heading)
		await capture("compact-rules-%dx%d" % [dimensions.x,dimensions.y])
		check(host.active_rules.body.visible and host.rules_dialog.overlay.visible and root.get_visible_rect().encloses(host.rules_dialog.panel.get_global_rect()), "Compact rules open in a fitted scrollable dialog at %s" % dimensions)
		await click_button(host.active_rules.heading)
		if dimensions.y < 420:
			var full_hand: Array = host.rules.hands[0].duplicate()
			host.rules.hands[0] = [3, 9]
			host.rules.revision += 1
			host._publish()
			await capture("solo-uno-%dx%d" % [dimensions.x,dimensions.y])
			check(host.table.uno_button.visible and host.actions.draw.visible, "Short layouts keep both Draw and eligible UNO reachable at %s" % dimensions)
			check(not host.table.uno_button.get_global_rect().intersects(host.table.sort_button.get_global_rect()) and not host.table.uno_button.get_global_rect().intersects(host.actions.draw.get_global_rect()), "All three short-layout actions have separate targets at %s" % dimensions)
			var draw_font: Font = host.actions.draw.get_theme_font("font")
			var draw_style: StyleBox = host.actions.draw.get_theme_stylebox("normal")
			var draw_text_width := draw_font.get_string_size(host.actions.draw.text, HORIZONTAL_ALIGNMENT_LEFT, -1, host.actions.draw.get_theme_font_size("font_size")).x
			check(draw_text_width + draw_style.get_minimum_size().x + host.actions.draw.get_theme_constant("icon_max_width") + host.actions.draw.get_theme_constant("h_separation") <= host.actions.draw.size.x + 1, "The whole DRAW label fits beside its icon at %s" % dimensions)
			host.rules.hands[0] = full_hand
			host.rules.revision += 1
			host._publish()
		settings.button_pressed = true
		await capture("settings-%dx%d" % [dimensions.x,dimensions.y])
		check(settings.icon != null and settings.accessibility_name == "SETTINGS", "Settings keeps a visible shared gear and accessible name")
		check(host.apply_options.get_global_rect().end.y <= dimensions.y, "Settings Apply is reachable at %s" % dimensions)
		settings.button_pressed = false
	await resize_view(Vector2i(1280,720))
	host.session.reduced_motion = false
	settings.button_pressed = true
	host._set_rule("force_play", true)
	host._apply_options()
	var remaining: float = host.motion_timer.time_left
	await create_timer(.2).timeout
	check(host.dealing and host.motion_timer.paused and is_equal_approx(remaining, host.motion_timer.time_left), "Applying settings keeps the new deal frozen until Close")
	settings.button_pressed = false
	check(not host.motion_timer.paused, "Closing resumes an opening deal")
	host.session.reduced_motion = true
	host.motion_timer.stop()
	host.dealing = false
	host.animating = false
	host.rules._finish(0)
	host._publish()
	await capture("winner")
	check(not host.table.notice_rect.intersects(host.table.seat_rects[0]), "The solo win banner leaves the host stats and crown visible")
	var win_rect: Rect2 = host.table.get_global_rect()
	var wins: Array = host.rules.session_wins.duplicate()
	var dealer: int = host.rules.dealer
	check(host.replay.visible and host.replay.get_global_rect().end.y <= root.size.y, "A completed hand has one reachable replay")
	await click_button(host.replay)
	await capture("replay")
	check(host.rules.phase != "finished" and host.rules.session_wins == wins and host.rules.dealer != dealer, "Replay retains session wins and rotates the dealer")
	check(host.table.get_global_rect().is_equal_approx(win_rect), "Replay does not shift the centered table")
	host.return_to_lobby()
	await process_frame
	check(app.active_game == null and app.current_state == "game_menu", "UNO returns cleanly to game selection")
	app.queue_free()
	await process_frame
	var colors := ["#ed202e", "#0869db", "#08a750", "#f7cf05", "#ae39f2", "#f52191"]
	for count in [4,5,6]:
		var players: Array = []
		for index in count: players.append({"id":"refresh-%d" % index, "display_name":"Player %d" % (index + 1), "color":colors[index], "pose":index})
		host = load("res://Games/uno/host/main.tscn").instantiate()
		root.add_child(host)
		host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
		var context := GameSessionContext.new("uno", players, {}, true)
		context.reduced_motion = true
		host.initialize_session(context)
		host.auto_timer.process_mode = Node.PROCESS_MODE_DISABLED
		host.start_game()
		for dimensions in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(390,844), Vector2i(844,390)]:
			await resize_view(dimensions)
			await capture("public-%d-%dx%d" % [count,dimensions.x,dimensions.y])
			check(host.table.state.viewer == -1 and host.table.state.hand.is_empty(), "Host with phones remains public")
			check(not host.active_rules.visible and not host.table.uno_button.visible, "Public hosts omit private UNO controls and the rules panel")
			check(host.table.seat_rects.size() == count and host.table.seat_rects.all(func(rect: Rect2) -> bool: return not rect.intersects(host.table.deck_rect) and not rect.intersects(host.table.top_rect)), "All public badges clear both piles at %d seats, %s" % [count,dimensions])
			check(host.table.fan_centers.size() == count, "Public hands retain every fan origin at %d seats, %s" % [count,dimensions])
			check(orbit_is_clear(host.table), "The full rotating orbit clears captions and badges at %d seats, %s" % [count,dimensions])
			host.rules.direction = -1
			host._publish()
			await capture("reverse-%d-%dx%d" % [count,dimensions.x,dimensions.y])
		var viewer: Dictionary = host._snapshot(0)
		check(viewer.hand.map(func(card: Dictionary) -> int: return card.id) == host.rules.hands[0] and not viewer.has("hands"), "Private snapshot contains the recipient's exact authoritative hand")
		var reverse_id: int = host.rules.cards.filter(func(card: Dictionary) -> bool: return card.color == "red" and card.kind == "reverse")[0].id
		host.rules.hands[0] = [reverse_id, 9, 79]
		for seat in range(1, count):
			for id in [reverse_id, 0, 9, 79]: host.rules.hands[seat].erase(id)
		host.rules.discard = [0]
		host.rules.deck = range(108).filter(func(id: int) -> bool: return not host.rules.discard.has(id) and not host.rules.hands.any(func(hand: Array) -> bool: return hand.has(id)))
		host.rules.turn = 0
		host.rules.phase = "play"
		host.rules.drawn = -1
		host.rules.pending_draw = 0
		host.rules.pending_color = ""
		host.rules.color = "red"
		host.rules.revision += 1
		host._action(0, {"action":"play", "card":reverse_id, "revision":host.rules.revision})
		await resize_view(Vector2i(1280,720))
		await capture("public-feedback-%d" % count)
		check(host.table.state.top.id == reverse_id and not host.active_rules.visible, "The discard shows the accepted Reverse without a public rules panel at %d seats" % count)
		host.rules.allow_jump_ins = true
		host.rules.allow_seven_zero = true
		host.rules.allow_stacking = true
		host.rules.enabled_addons.speed = true
		host._publish()
		check(host.active_rules.text.contains("Jump-In") and host.active_rules.text.contains("Stacking On") and host.active_rules.text.contains("Speed"), "Applied rules and packs appear in the bottom panel")
		check(host.active_rules.items.all(func(item: Dictionary) -> bool: return FileAccess.file_exists(item.icon)) and host.active_rules.rows.get_children().filter(func(row: Node) -> bool: return row is HBoxContainer).size() == host.active_rules.items.size(), "Every active rule has an offline icon and its own illustrated row")
		await capture("rules-panel-%d" % count)
		check(not host.active_rules.visible, "Enabled rules and add-ons stay off the public host at %d seats" % count)
		if count == 6:
			await resize_view(Vector2i(1280,720))
			var options: Button = host.settings_body.get_parent().get_meta("toggle_button")
			options.button_pressed = true
			host.history_text.get_parent().get_meta("toggle_button").button_pressed = true
			for index in 40: host.rules.plays.append({"number":index + 1, "seat":index % count, "card":{"color":"red", "kind":"5"}, "color":"red"})
			host._publish()
			await capture("history-long")
			host.history_text.scroll_to_line(15)
			await capture("history-scrolled")
			host._publish()
			check(host.history_text.get_v_scroll_bar().value > 0, "Unchanged snapshots preserve history browsing inside Settings")
			host.rules.plays.append({"number":41, "seat":0, "card":{"color":"blue", "kind":"7"}, "color":"blue"})
			host._publish()
			await capture("history-newest")
			check(host.history_text.get_v_scroll_bar().value == 0 and host.history_text.text.begins_with("41."), "A new accepted play returns the inner history log to the newest entry")
			options.button_pressed = false
		host.rules._finish(count - 1)
		host._publish()
		await capture("public-winner-%d" % count)
		check(host.replay.is_visible_in_tree() and root.get_visible_rect().encloses(host.replay.get_global_rect()), "Public hosts retain one reachable replay at %d seats" % count)
		await click_button(host.replay)
		check(host.rules.phase != "finished", "Public replay starts another hand through the shared footer at %d seats" % count)
		host.shutdown_game()
		host.queue_free()
		await process_frame
		await resize_view(Vector2i(1280,720))
	print("UNO UI refresh: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
