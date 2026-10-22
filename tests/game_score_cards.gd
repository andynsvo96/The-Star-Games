extends SceneTree

var failures := 0
var checks := 0
const PLAYERS := [{"id": "one", "display_name": "Star Host", "color": "#2463eb"}, {"id": "two", "display_name": "A longer player name", "color": "#00ffff"}]


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func inside(inner: Rect2, outer: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 1 and inner.position.y >= outer.position.y - 1 and inner.end.x <= outer.end.x + 1 and inner.end.y <= outer.end.y + 1


func no_tooltips(node: Node) -> bool:
	if node is Control and not node.tooltip_text.is_empty():
		return false
	for child in node.get_children():
		if not no_tooltips(child):
			return false
	return true


func content_inside(node: Node, bounds: Rect2) -> bool:
	if node is Control:
		if not node.is_visible_in_tree():
			return true
		if not inside(node.get_global_rect(), bounds):
			return false
	for child in node.get_children():
		if not content_inside(child, bounds):
			return false
	return true


func check_scroll(body: VBoxContainer, caption: String) -> void:
	# Framed paper cards own their inset; the shared disclosure still owns visibility.
	if body.get_parent() is PanelContainer:
		var panel := body.get_parent() as PanelContainer
		var disclosure: VBoxContainer = panel.get_parent()
		var button: Button = disclosure.get_meta("toggle_button")
		button.button_pressed = true
		for frame in 12:
			await process_frame
		check(body.is_visible_in_tree() and content_inside(body, panel.get_global_rect()), "%s controls fit inside the shared paper card" % caption)
		button.button_pressed = false
		return
	var group: VBoxContainer = body.get_parent()
	var sheet: PanelContainer = group.get_parent()
	var toggle: Button = group.get_child(0)
	toggle.button_pressed = true
	for frame in 12:
		await process_frame
	# Reserve the paper border, rolls, and at least 14px of breathing room.
	var interior := sheet.get_global_rect().grow_individual(-50, -50, -50, -50)
	check(body.visible and content_inside(group, interior), "%s controls and text fit safely inside the parchment" % caption)
	var ancestor: Node = sheet.get_parent()
	while ancestor != null and not ancestor is GameScreen:
		ancestor = ancestor.get_parent()
	var screen := ancestor as GameScreen
	if screen != null and screen.board_anchor != null:
		check(absf(screen.board_anchor.get_global_rect().get_center().x - screen.content.get_global_rect().get_center().x) < 2, "%s keeps the board centered within the scroll area" % caption)
	toggle.button_pressed = false
	for frame in 12:
		await process_frame
	check(not body.visible, "%s scroll closes cleanly" % caption)


func _run() -> void:
	for id in ["checkers", "four-in-a-row", "tic-tac-toe", "chess"]:
		for viewport_size in [Vector2(1920, 1080), Vector2(1684, 1144), Vector2(1280, 720), Vector2(480, 800), Vector2(900, 540)]:
			var view := Control.new()
			view.size = viewport_size
			root.add_child(view)
			var host = load("res://Games/%s/host/main.tscn" % id).instantiate()
			view.add_child(host)
			var context := GameSessionContext.new(id, PLAYERS.duplicate(true), {}, true)
			context.reduced_motion = true
			host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
			host.initialize_session(context)
			host.start_game()
			for frame in 12:
				await process_frame
			check(no_tooltips(host), "%s controls have no hover tooltips" % id)
			check(not host.screen.instruction_label.visible and host.screen.instruction_label.text.is_empty(), "%s omits the instruction subtitle" % id)
			check(host.screen.size.x <= viewport_size.x + 1, "%s layout stays inside the host width (%s / %s / %s)" % [id, host.size, host.screen.size, viewport_size])
			var board_before: Rect2 = host.screen.board_anchor.get_global_rect()
			if id == "chess":
				check(inside(board_before, host.get_global_rect()), "Chess board fits the host viewport at %s" % viewport_size)
			check(absf(board_before.get_center().y - host.get_global_rect().get_center().y) < 2, "%s board is vertically centered at %s (%s)" % [id, viewport_size, board_before])
			check(host.score_cards[0].underline.active and not host.score_cards[1].underline.active, "%s underlines the first player's turn" % id)
			for card in host.score_cards:
				check(inside(card.name_panel.get_global_rect(), card.content.get_global_rect()), "%s name panel stays inside its card content" % id)
				check(inside(card.score_panel.get_global_rect(), card.content.get_global_rect()), "%s score panel stays inside its card content" % id)
				check(inside(card.player.get_global_rect(), card.name_panel.get_global_rect()), "%s name text stays inside its panel" % id)
				check(inside(card.score.get_global_rect(), card.score_panel.get_global_rect()), "%s score text stays inside its panel" % id)
				if id == "chess":
					var interior: Rect2 = card.panel.get_global_rect().grow(-24)
					check(inside(card.content.get_global_rect(), interior), "Chess stats reserve the shared framed-paper insets")
					var counts: GridContainer = card.content.get_child(card.content.get_child_count() - 1)
					check(counts.get_children().all(func(item: Control) -> bool: return inside(item.get_global_rect(), card.content.get_global_rect())), "Chess piece icons and counts stay within the wood slab")
				if id == "checkers":
					var parchment: Rect2 = card.panel.get_global_rect().grow(-24)
					check(inside(card.content.get_global_rect(), parchment), "Checkers content stays within the shared framed-paper insets")
					var material: GridContainer = card.content.get_child(card.content.get_child_count() - 1)
					check(is_equal_approx(material.get_child(0).global_position.x, material.get_child(2).global_position.x), "Piece and king icons share a left column")
					check(is_equal_approx(material.get_child(1).global_position.x, material.get_child(3).global_position.x), "Piece and king counts share a left column")
			if id == "chess":
				host.rules.session_wins = [1234, 5678]
				host._configure_clock(86400.0)
				for frame in 12:
					await process_frame
				check(host.score_cards.all(func(card: Dictionary) -> bool: return inside(card.score.get_global_rect(), card.score_panel.get_global_rect())), "Large Chess win totals fit within their inset panels")
				check(host.clock_labels.all(func(clock: Label) -> bool: return inside(clock.get_global_rect(), clock.get_parent().get_global_rect())), "Long custom clocks fit the slab")
				await check_scroll(host.difficulty_choice.get_parent().get_parent(), "Chess options at %s" % viewport_size)
				await check_scroll(host.session_scores.get_parent(), "Chess history at %s" % viewport_size)
				check(host.find_children("*", "Button", true, false).all(func(button: Button) -> bool: return not "DRAW" in button.text and not "RESIGN" in button.text), "Chess omits draw and resignation buttons")
			if id == "chess":
				host.rules.position.turn = 2
			else:
				host.rules.turn = 2
			host._publish()
			check(not host.score_cards[0].underline.active and host.score_cards[1].underline.active, "%s underline follows the next turn" % id)
			host.player_disconnected("two")
			check(host.score_cards.all(func(card: Dictionary) -> bool: return not card.underline.active), "%s paused game hides the active underline" % id)
			host.player_reconnected(PLAYERS[1])
			check(host.score_cards[1].underline.active, "%s reconnect restores the active underline" % id)
			host.rules.outcome = 3
			host._publish()
			for frame in 8:
				await process_frame
			check(host.score_cards.all(func(card: Dictionary) -> bool: return not card.underline.active), "%s completed game hides the active underline" % id)
			check(host.replay_button.visible and inside(host.replay_button.get_global_rect(), host.get_global_rect()), "%s Play Again fits without scrolling at %s" % [id, viewport_size])
			check(host.screen.board_anchor.get_global_rect().is_equal_approx(board_before), "%s replay does not shift or resize the board at %s (%s -> %s)" % [id, viewport_size, board_before, host.screen.board_anchor.get_global_rect()])
			host.shutdown_game()
			view.queue_free()
			await process_frame
	for viewport_size in [Vector2(1920, 1080), Vector2(1280, 720), Vector2(480, 800), Vector2(900, 540)]:
		for players in [[], [PLAYERS[1]]]:
			var view := Control.new()
			view.size = viewport_size
			root.add_child(view)
			var host = load("res://Games/chess/host/main.tscn").instantiate()
			view.add_child(host)
			host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
			host.initialize_session(GameSessionContext.new("chess", players, PLAYERS[0], not players.is_empty()))
			host.set_process(false)
			host.start_game()
			await check_scroll(host.difficulty_choice.get_parent().get_parent(), "Chess %s settings at %s" % ["solo" if players.is_empty() else "one-phone", viewport_size])
			await check_scroll(host.session_scores.get_parent(), "Chess %s history at %s" % ["solo" if players.is_empty() else "one-phone", viewport_size])
			host.shutdown_game()
			view.queue_free()
			await process_frame
	var template = load("res://Games/_Template/host/main.tscn").instantiate()
	root.add_child(template)
	check(no_tooltips(template), "Template controls omit hover tooltips")
	var template_history: RichTextLabel = template.find_children("*", "RichTextLabel", true, false).filter(func(label: RichTextLabel) -> bool: return label.text == "No completed rounds yet.")[0]
	await check_scroll(template_history.get_parent(), "Template history")
	template.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("Shared score cards: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
