extends SceneTree

var checks := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var folder := "res://.test_data/pictionary-visual/"
	DirAccess.make_dir_recursive_absolute(folder)
	var players := [{"id": "p0", "display_name": "Jane", "color": "#e43c45"}, {"id": "p1", "display_name": "Alex", "color": "#398552"}, {"id": "p2", "display_name": "Sam", "color": "#efbd23"}, {"id": "p3", "display_name": "Riley", "color": "#286ac2"}]
	for view in [["desktop", 1280, 720, false], ["portrait", 390, 844, false], ["landscape", 844, 390, false], ["reduced", 1280, 720, true], ["sixteen", 1280, 720, false]]:
		root.min_size = Vector2i(1, 1)
		root.content_scale_size = Vector2i(view[1], view[2])
		root.size = Vector2i(view[1], view[2])
		var roster := players.duplicate(true)
		if view[0] == "sixteen":
			for seat in range(4, 16):
				roster.append({"id": "p%d" % seat, "display_name": "Artist %d" % (seat + 1), "color": "#286ac2"})
		var host = load("res://Games/pictionary/host/main.tscn").instantiate()
		root.add_child(host)
		host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
		var context := GameSessionContext.new("pictionary", roster, {}, true)
		context.reduced_motion = view[3]
		host.initialize_session(context)
		host.start_game()
		host.rules.choose(0, 0)
		host.rules.chosen = {"word": "sailboat", "aliases": ["sail boat"]}
		host.rules.remaining = 42
		host.rules.scores = [275, 350, 200, 150] + ([] if roster.size() == 4 else [100, 90, 80, 70, 60, 50, 40, 30, 20, 10, 0, 0])
		host.rules.guessed = [1]
		host.rules.feed = [{"seat": 1, "correct": true, "quality": "correct", "text": "sailboat", "seconds": 8.4, "rank": 1, "points": 100, "turn": 1, "word": "sailboat"}, {"seat": 2, "correct": false, "quality": "close", "text": "sailbaot", "seconds": 12.5, "rank": 0, "points": 0, "turn": 1, "word": "sailboat"}, {"seat": 3, "correct": false, "quality": "wrong", "text": "ship", "seconds": 15.3, "rank": 0, "points": 0, "turn": 1, "word": "sailboat"}]
		for entry in host.rules.feed:
			host.rules.turn_guesses[entry.seat] = entry.duplicate(true)
			host.rules.match_guesses[entry.seat] = entry.duplicate(true)
			if not entry.correct:
				host.rules.guess_times[entry.seat] = host.rules.clock
		var paths := [[[200, 470], [810, 470], [710, 590], [300, 590], [200, 470]], [[490, 90], [490, 470]], [[460, 130], [230, 420], [460, 420], [460, 130]], [[530, 150], [750, 420], [530, 420], [530, 150]], [[100, 660], [170, 635], [240, 660], [310, 635], [380, 660], [450, 635], [520, 660], [590, 635], [660, 660], [730, 635], [800, 660], [870, 635]]]
		for index in paths.size():
			host.rules.ink(0, {"turn_id": host.rules.turn_id, "epoch": host.rules.drawing_epoch, "stroke_id": str(index), "sequence": 0, "points": paths[index], "color": 0, "width": 1, "end": true})
		host._publish(true)
		for frame in 30:
			await process_frame
		var board: Rect2 = host.canvas.get_global_rect()
		check(not host.guess_scroll.is_visible_in_tree() and host.guess_rows.all(func(row: Dictionary) -> bool: return row.guess.text.is_empty()), "%s hides last guesses during play" % view[0])
		check(host.guess_notice.text.contains("Alex guessed it! ✓") and not host.guess_notice.text.contains("sailbaot") and not host.guess_notice.text.contains("sailboat"), "%s turn table keeps success indications without guess words" % view[0])
		var wrong_row: Dictionary = host.score_rows.filter(func(row: Dictionary) -> bool: return row.get("seat") == 3)[0]
		check(wrong_row.bubble.panel.is_visible_in_tree() and wrong_row.bubble.label.text == "ship" and wrong_row.bubble.panel.get_global_rect().position.x > wrong_row.player.global_position.x and wrong_row.bubble.panel.get_global_rect().end.x <= wrong_row.score.global_position.x, "%s wrong guesses appear as a bubble between player name and score" % view[0])
		var speech_gap: float = wrong_row.bubble.panel.global_position.x - wrong_row.player.get_global_rect().end.x
		check(speech_gap >= 6 and speech_gap <= 12 and wrong_row.bubble.panel.size.x < 120, "%s short speech hugs the player's name and its own text" % view[0])
		var speech_style: StyleBoxFlat = wrong_row.bubble.panel.get_theme_stylebox("panel")
		check(speech_style.bg_color == Color.WHITE and speech_style.border_color == Color("9ccff0"), "%s speech bubbles have a white fill and light blue outline" % view[0])
		check(host.score_rows[0].player.text.begins_with("Alex") and host.score_rows[1].player.text.begins_with("Jane"), "%s scores descend by points" % view[0])
		check(board.position.x >= 0 and board.end.x <= host.size.x + 1, "%s canvas fits horizontally" % view[0])
		check(absf(board.get_center().x - host.size.x / 2.0) < 3, "%s board inherits shared centering" % view[0])
		check(board.end.y <= host.size.y + 1, "%s drawing remains visible" % view[0])
		check(host.canvas.paper_rect().size.x >= board.size.x - 12, "%s thin border leaves the full canvas width for drawing" % view[0])
		for button in host.find_children("*", "Button", true, false):
			check(button.tooltip_text.is_empty(), "%s has no hover text" % view[0])
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder + str(view[0]) + "-drawing.png")
		var old_name: String = host.rules.players[3].display_name
		host.rules.players[3].display_name = "A Longer Player Name"
		host.rules.turn_guesses[3].text = "wrong guess ".repeat(5).strip_edges()
		host._render()
		for frame in 6:
			await process_frame
		check(wrong_row.bubble.panel.get_global_rect().end.x <= wrong_row.score.global_position.x and wrong_row.player.get_global_rect().end.x < wrong_row.bubble.panel.global_position.x, "%s long names and guesses wrap before the score" % view[0])
		if view[0] == "desktop" and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder + "desktop-long-bubble.png")
		host.rules.players[3].display_name = "Bo"
		host.rules.turn_guesses[3].text = "ship"
		host._render()
		for frame in 6:
			await process_frame
		check(wrong_row.bubble.panel.global_position.x - wrong_row.player.get_global_rect().end.x <= 12 and wrong_row.player.size.x < 50, "%s a shorter name moves its bubble back beside the text" % view[0])
		host.rules.players[3].display_name = old_name
		host._render()
		host.rules.remaining = 9.75
		host._update_countdown()
		var dim: float = host.clock_alpha
		host.rules.remaining = 9.25
		host._update_countdown()
		host._render_clock()
		check((dim == host.clock_alpha and dim == 1.0) if view[3] else dim != host.clock_alpha, "%s timer changes brightness only with motion enabled" % view[0])
		for frame in 2:
			await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder + str(view[0]) + "-countdown.png")
		host.rules.remaining = 42
		host._update_countdown()
		host.rules.set_disconnected(3)
		host._render()
		check(not wrong_row.bubble.panel.is_visible_in_tree(), "%s pause hides live speech" % view[0])
		host.rules.reconnect(3)
		host._render()
		check(wrong_row.bubble.panel.is_visible_in_tree(), "%s reconnect restores the unexpired speech" % view[0])
		host.rules.clock += 4
		host._render_bubbles()
		check(not wrong_row.bubble.panel.is_visible_in_tree(), "%s live speech expires without rerendering the board" % view[0])
		if view[0] == "desktop":
			var before := board
			host._toggle_settings()
			for frame in 15:
				await process_frame
			check(root.get_visible_rect().encloses(host.settings_dialog.panel.get_global_rect()) and host.settings_dialog.panel.size.x > host.size.x * 0.9, "Settings is a full-screen modal within the viewport")
			check(host.save_words_button.get_global_rect().end.y <= host.settings_dialog.actions.global_position.y, "Word Save stays inside the settings view")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(folder + "desktop-settings.png")
			host._close_settings()
			check(host.settings_button.get_theme_color("font_focus_color") == host.settings_button.get_theme_color("font_color"), "Focused studio controls keep readable ink")
			# Regression: a long revealed word must not push the timer off its plaque.
			host.rules.chosen = {"word": "skateboarding", "aliases": []}
			host.rules.tick(100)
			host._publish(true)
			for frame in 15:
				await process_frame
			check(before.is_equal_approx(host.canvas.get_global_rect()), "Reveal keeps the canvas fixed")
			check(host.canvas.hint == "SKATEBOARDING", "The full revealed word remains on the canvas")
			check(not host.guess_scroll.is_visible_in_tree() and host.guess_rows.all(func(row: Dictionary) -> bool: return row.guess.text.is_empty()), "Turn reveal hides last guesses until match completion")
			check(host.screen.status.get_parsed_text().begins_with("Turn complete") and host.screen.status.get_content_height() <= host.screen.status.size.y - 14, "Long answers do not clip the reveal status or timer")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(folder + "desktop-reveal.png")
		# Results fixture: preserve a varied final guessing turn for visual QA.
		if host.rules.phase == "drawing":
			host.rules.tick(180)
		host.rules.match_guesses[0] = {"seat": 0, "correct": false, "quality": "wrong", "text": "", "seconds": 60.0, "rank": 0, "points": 0, "turn": 1, "word": "book"}
		host.rules._finish()
		host.active = false
		host._publish(true)
		for frame in 15:
			await process_frame
		check(host.guess_scroll.is_visible_in_tree() and host.guess_rows[0].player.text == "Alex" and host.guess_rows[0].guess.text == "sailboat ✓" and host.guess_rows[0].duration.text == "8.4s", "%s results use name, last guess and duration columns" % view[0])
		check(host.guess_rows[1].duration.text == "60.0s" and host.guess_rows[2].duration.text == "60.0s", "%s unsuccessful rows show the full turn duration" % view[0])
		if view[0] == "desktop":
			host._publish(true)
			for frame in 15:
				await process_frame
			check(board.is_equal_approx(host.canvas.get_global_rect()) and host.replay.is_visible_in_tree() and host.replay.get_global_rect().end.y <= host.size.y, "Results preserve board geometry and reachable Play Again")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(folder + "desktop-finished.png")
		elif DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder + str(view[0]) + "-finished.png")
		host.shutdown_game()
		host.queue_free()
		await process_frame
	print("Pictionary host visual: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
