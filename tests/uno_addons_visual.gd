extends SceneTree

var output := "res://.test_data/uno-addons-visual/"
var failures := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func capture(name: String) -> void:
	for frame in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + name + ".png")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.min_size = Vector2i(1,1)
	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new(output + "profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	app._play_from_lobby()
	var module: Dictionary = app.game_catalog.games.filter(func(game: Dictionary) -> bool: return game.id == "uno")[0]
	app._launch_game(module)
	var host = app.active_game
	for timer in [host.ai_timer, host.auto_timer, host.jump_timer]: timer.process_mode = Node.PROCESS_MODE_DISABLED
	var settings: Button = host.find_children("*", "Button", true, false).filter(func(button: Button) -> bool: return button.accessibility_name == "SETTINGS")[0]
	for dimensions in [Vector2i(1280,720), Vector2i(390,844), Vector2i(844,390), Vector2i(568,320)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		settings.button_pressed = true
		host.addons_body.hide()
		host.settings_body.show()
		await capture("settings-%dx%d" % [dimensions.x,dimensions.y])
		var addons_rect: Rect2 = host.addons_button.get_global_rect()
		var apply_rect: Rect2 = host.apply_options.get_global_rect()
		var rule_size: Vector2 = host.rule_choices.force_play.size
		check(addons_rect.end.y < apply_rect.position.y, "Add-Ons sits above Apply")
		check(addons_rect.size.is_equal_approx(rule_size), "Add-Ons matches the house rule button size")
		var entry_surface: StyleBoxFlat = host.addons_button.get_theme_stylebox("normal")
		check(entry_surface.bg_color.r > entry_surface.bg_color.g and entry_surface.bg_color.g > entry_surface.bg_color.b, "The Add-Ons settings entry uses the shared gold surface")
		check(apply_rect.end.x <= dimensions.x and apply_rect.end.y <= dimensions.y, "Apply remains inside the viewport")
		host.addons_button.pressed.emit()
		await capture("addons-%dx%d" % [dimensions.x,dimensions.y])
		check(host.addon_choices.values().all(func(button: Button) -> bool: return button.is_visible_in_tree() and button.get_global_rect().position.x >= 0 and button.get_global_rect().end.x <= dimensions.x and button.get_global_rect().end.y <= dimensions.y), "All nine add-ons fit the viewport")
		check(host.addon_choices.values().all(func(button: Button) -> bool: return button.size.is_equal_approx(rule_size)), "Add-on choices match the house rule button size")
		for key in host.addon_choices: host._set_addon(key, true)
		await capture("addons-enabled-%dx%d" % [dimensions.x,dimensions.y])
		check(host.addon_choices.values().all(func(button: Button) -> bool: return button.button_pressed and button.get_theme_stylebox("normal").bg_color.g > button.get_theme_stylebox("normal").bg_color.r), "All staged add-ons inherit shared ON styling")
		settings.button_pressed = false
	host.addons_body.hide()
	host.settings_body.show()
	host._apply_options()
	check(host.rules.cards.size() == 249, "All packs together add 141 playable cards to the classic 108")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	host.rules.turn = 0
	host.rules.phase = "play"
	host.rules.pending_draw = 0
	host.rules.addons.reset()
	host.rules.color = "red"
	var kinds := ["reverse_draw2","stack1","swap1","1","reveal_hands","nemesis","block"]
	var hand: Array = []
	for kind in kinds:
		hand.append(host.rules.cards.filter(func(card: Dictionary) -> bool: return card.has("addon") and card.kind == kind)[0].id)
	host.rules.hands[0] = hand
	host.rules.discard = [9]
	host.rules.revision += 1
	host._publish()
	await capture("classic-all-packs")
	host.active_rules.heading.pressed.emit()
	await capture("grouped-rules")
	var first_rule: HBoxContainer = host.active_rules.rows.get_children().filter(func(row: Node) -> bool: return row is HBoxContainer)[0]
	check(host.active_rules.body.get_global_rect().encloses(first_rule.get_global_rect()), "Section headings leave the first illustrated rule fully visible")
	check(host.active_rules.rows.get_children().filter(func(row: Node) -> bool: return row is Label).map(func(row: Label) -> String: return row.text) == ["GAME MODE", "ADD-ONS"], "The host groups the mode and nine add-ons without an empty house rules section")
	host.rules_dialog.scroll.scroll_vertical = 100000
	await capture("grouped-rules-scrolled")
	var last_rule: Control = host.active_rules.rows.get_child(host.active_rules.rows.get_child_count() - 1)
	check(host.rules_dialog.scroll.get_global_rect().encloses(last_rule.get_global_rect()), "The last add-on scrolls fully into view through one shared dialog scrollbar")
	for dimensions in [Vector2i(390,844),Vector2i(844,390),Vector2i(568,320)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await capture("grouped-rules-%dx%d" % [dimensions.x,dimensions.y])
		host.rules_dialog.scroll.scroll_vertical = 100000
		await capture("grouped-rules-scrolled-%dx%d" % [dimensions.x,dimensions.y])
		check(root.get_visible_rect().encloses(host.rules_dialog.panel.get_global_rect()) and host.rules_dialog.scroll.get_global_rect().encloses(last_rule.get_global_rect()), "Grouped rules and their final add-on remain reachable on short and narrow hosts")
	host.active_rules.heading.pressed.emit()
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	# A real add-on penalty keeps legal response cards in the hand and uses Draw.
	var attack: int = host.rules.cards.filter(func(card: Dictionary) -> bool: return card.color == "red" and card.kind == "draw2")[0].id
	var block: int = host.rules.cards.filter(func(card: Dictionary) -> bool: return card.kind == "block")[0].id
	host.rules.addons.reset()
	host.rules.hands = [[block,13,79],[7,29,85],[3,27,81],[attack,5,55]]
	host.rules.discard = [9]
	host.rules.deck = range(host.rules.cards.size()).filter(func(id: int) -> bool: return not host.rules.discard.has(id) and not host.rules.hands.any(func(cards: Array) -> bool: return cards.has(id)))
	host.rules.turn = 3
	host.rules.direction = 1
	host.rules.drawn = -1
	host.rules.armed.fill(false)
	host.rules.declared.fill(false)
	check(host.rules.play(3,attack), "A real Draw Two creates a response for the solo host")
	host._publish()
	for dimensions in [Vector2i(1280,720),Vector2i(390,844),Vector2i(844,390),Vector2i(568,320)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await capture("penalty-draw-%dx%d" % [dimensions.x,dimensions.y])
		check(host.actions.draw.visible and not host.actions.draw.disabled and host.actions.draw.text == ("+2" if dimensions.y < 560 else "DRAW 2") and host.actions.draw.accessibility_name == "Draw 2 cards", "The normal Draw button accepts a penalty at %s: %s, disabled=%s" % [dimensions,host.actions.draw.text,host.actions.draw.disabled])
		check(host.controls.get_child_count() == 0 and not host.addon_dialog.overlay.visible and host.rules.legal_cards(0).has(block), "The response hand stays playable without a second penalty action or dialog")
	var before_draw: int = host.rules.hands[0].size()
	host.actions.draw.pressed.emit()
	check(host.rules.hands[0].size() == before_draw + 2 and host.rules.pending_draw == 0, "The regular host Draw button pays the full authoritative penalty")
	for dimensions in [Vector2i(1280,720),Vector2i(390,844),Vector2i(844,390),Vector2i(568,320)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		host.rules.addons.reveal_owner = -1
		host.rules.revision += 1
		host._publish()
		for frame in 10: await process_frame
		var before_reveal: Rect2 = host.table.get_global_rect()
		host.rules.addons.reveal_owner = 0
		host.rules.revision += 1
		host._publish()
		await capture("revealed-seats-%dx%d" % [dimensions.x,dimensions.y])
		check(host.controls.get_child_count() == 0 and not host.addon_dialog.overlay.visible, "Revealed hands create no host footer, dialog or reopen control at %s" % dimensions)
		check(host.table.get_global_rect().is_equal_approx(before_reveal), "Revealed hands reserve no extra bottom space at %s" % dimensions)
		check(host.table._visual_backs() == host.rules.hands.map(func(cards: Array) -> Array: return cards.map(func(id: int) -> Dictionary: return host.rules.cards[id])), "Revealed faces use the existing host seat fans")
	host.rules.addons.reveal_owner = -1
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	host.rules.addons.context = {"actor":0,"origin":0,"after":1,"uno_pending":false}
	host.rules.addons._ask(host.rules,"text","I've Got a Text — choose a rule.")
	host.rules.revision += 1
	host._publish()
	await capture("text-choice")
	for dimensions in [Vector2i(390,844),Vector2i(844,390),Vector2i(568,320)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await capture("text-choice-%dx%d" % [dimensions.x,dimensions.y])
		var decision: Rect2 = host.addon_dialog.scroll.get_global_rect()
		check(decision.position.x >= 0 and decision.end.x <= dimensions.x and decision.position.y >= 0 and decision.end.y <= dimensions.y, "Add-on decision scrolling area remains reachable")
		if dimensions.y < 560: check(not decision.intersects(settings.get_global_rect()) and not decision.intersects(host.screen.back_button.get_global_rect()), "Short decision views leave shared top navigation reachable")
	var pending_revision: int = host.rules.revision
	host.addon_close.pressed.emit()
	await capture("choice-dismissed-short")
	check(not host.addon_dialog.overlay.visible and host.table.discard_button.visible and host.rules.revision == pending_revision, "Closing a choice leaves the discard card available to reopen it without accepting it")
	host.table.discard_button.pressed.emit()
	await capture("choice-reopened-short")
	check(host.addon_dialog.overlay.visible and host.rules.revision == pending_revision, "A dismissed private choice reopens without changing its ticket")
	host._local_action({"action":"addon_choose", "value":"draw"})
	await capture("choice-resolved-short")
	check(host.rules.revision > pending_revision and host.rules.addons.choice.get("kind", "") != "text" and not host.addon_dialog.overlay.visible, "An accepted choice advances to the next authoritative decision without keeping the old choice")
	# Every other add-on surface leaves the action row and table size unchanged.
	host.rules.addons.reset()
	host.rules.phase = "play"
	host.rules.turn = 0
	host.rules.drawn = -1
	host.rules.pending_draw = 0
	host.rules.pending_color = ""
	host.rules.color = "red"
	var letters: Array = ["U","N","O"].map(func(letter: String) -> int: return host.rules.cards.filter(func(card: Dictionary) -> bool: return card.get("letter", "") == letter)[0].id)
	host.rules.hands = [letters + [9],[7,29,85],[3,27,81],[5,31,55]]
	host.rules.discard = [17]
	host.rules.deck = range(host.rules.cards.size()).filter(func(id: int) -> bool: return not host.rules.discard.has(id) and not host.rules.hands.any(func(cards: Array) -> bool: return cards.has(id)))
	for kind in ["give","double","combo_keep"]:
		host.rules.addons.context = {"actor":0,"origin":0,"after":1,"uno_pending":false}
		host.rules.addons._ask(host.rules,kind,"Choose a card.")
		host.rules.revision += 1
		host._publish()
		await capture("own-card-" + kind)
		var offered: Array = host._snapshot(0).addon_choice.cards.map(func(card: Dictionary) -> int: return card.id)
		check(not host.addon_dialog.overlay.visible and host.table.hand_hits.filter(func(hit: Dictionary) -> bool: return hit.legal).map(func(hit: Dictionary) -> int: return hit.id).all(func(id: int) -> bool: return offered.has(id)), "Own-card choices stay in the existing hand: " + kind)
		check(not offered.is_empty() and host.player_focus.visible and host.controls.get_child_count() == 0, "Own-card instructions float without extra bottom controls: " + kind)
	host.rules.addons._ask(host.rules,"chat_take","Choose an exchange card.")
	host.rules.addons.choice.target = 1
	host.rules.revision += 1
	host._publish()
	await capture("private-chat")
	check(host.addon_dialog.overlay.visible and host._snapshot(-1).addon_choice.is_empty() and host._snapshot(1).addon_choice.is_empty(), "Private Chat cards remain private in the temporary viewer")
	host.addon_close.pressed.emit()
	await capture("private-chat-dismissed")
	check(host.table.swap_buttons[1].visible and host.table.swap_buttons.filter(func(button: Button) -> bool: return button.visible).size() == 1, "Only the relevant badge reopens a dismissed Chat choice")
	host.table.swap_buttons[1].pressed.emit()
	var exchange_grid: GameCardGrid = host.addon_dialog.body.get_children().filter(func(child: Node) -> bool: return child is GameCardGrid)[0]
	exchange_grid.card_pressed.emit(host.rules.cards[host.rules.hands[1][0]])
	await capture("chat-give")
	check(host.rules.addons.choice.kind == "give" and not host.addon_dialog.overlay.visible, "Chat continues by choosing a replacement from the existing hand")
	var exchange_revision: int = host.rules.revision
	host._select_card(9)
	await process_frame
	check(host.rules.revision > exchange_revision and host.rules.addons.choice.is_empty(), "An own-hand tap completes the authoritative exchange")
	host.rules.addons.reset()
	host.rules.phase = "play"
	host.rules.turn = 0
	host.rules.addons.private_reveals[0] = {1:[host.rules.cards[host.rules.hands[1][0]].duplicate()]}
	host.rules.revision += 1
	host._publish()
	await capture("private-color-proof")
	check(host.addon_dialog.overlay.visible and host._snapshot(-1).revealed_cards.is_empty() and host._snapshot(1).revealed_cards.is_empty() and host._snapshot(-1).revealed_hands.is_empty(), "Color Challenge proof is never copied to public snapshots or seat fans")
	host.addon_close.pressed.emit()
	await capture("private-proof-dismissed")
	host.table.swap_buttons[1].pressed.emit()
	check(host.addon_dialog.overlay.visible, "The highlighted badge reopens private Color Challenge results")
	host.rules.addons.private_reveals.clear()
	host.rules.hands[0] = letters + [9]
	host.rules.addons.enemies = {0:1}
	host.rules.addons.couple = [0,2]
	host.rules.addons.basket = [0,3]
	host.rules.revision += 1
	host._publish()
	for dimensions in [Vector2i(1280,720),Vector2i(390,844),Vector2i(844,390),Vector2i(568,320)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await capture("context-actions-%dx%d" % [dimensions.x,dimensions.y])
		var context_rect: Rect2 = host.player_focus.prompt.get_global_rect()
		check(host.player_focus.visible and host.player_focus.commands.get_child_count() == 2 and not context_rect.intersects(host.actions.draw.get_global_rect()) and not context_rect.intersects(host.table.uno_button.get_global_rect()) and not context_rect.intersects(host.table.sort_button.get_global_rect()), "Special actions stay on the right and leave the bottom row clear at %s" % dimensions)
		check(host.controls.get_child_count() == 0 and host._snapshot(0).active_rule_items.any(func(item: Dictionary) -> bool: return item.section == "Active Effects"), "Relationships use existing badges and the rules dialog without a footer")
	host._context_action("end_enemy")
	check(not host.rules.addons.enemies.has(0), "The floating Nemesis action still validates through the host")
	app.active_game.return_to_lobby()
	await process_frame
	check(app.current_state == "game_menu" and app.active_game == null and app.lan_server.running, "Returning exits all add-on choices through shared navigation")
	app.lan_server.stop_server()
	app.queue_free()
	await process_frame
	print("UNO add-ons visual: %d failures; captures in .test_data/uno-addons-visual" % failures)
	quit(1 if failures else 0)
