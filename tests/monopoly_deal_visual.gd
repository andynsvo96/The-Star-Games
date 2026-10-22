extends SceneTree
var failures := 0
var folder := "res://.test_data/monopoly-deal-visual/"
var app: Control

func _init() -> void:
	call_deferred("_run")

func capture(name: String) -> void:
	for frame in 15: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + name + ".png")

func tap(point: Vector2) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true; event.position = point; event.global_position = point
	root.push_input(event, true); await process_frame; event.pressed = false; root.push_input(event, true); await process_frame

func _run() -> void:
	seed(470470)
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://Main.tscn").instantiate(); app.profile_store = ProfileStore.new(folder + "profiles.json"); app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new(); root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true; app._enter_lobby(); app._play_from_lobby()
	var module: Dictionary = app.game_catalog.games.filter(func(game: Dictionary) -> bool: return game.id == "monopoly-deal")[0]
	app._launch_game(module); await process_frame
	var host = app.active_game
	# Interaction fixtures explicitly choose a turn; production solo starts randomly.
	host.rules.start(host.seats.size(), 0); host.animating = false; host.motion_timer.stop(); host._publish()
	host.ai_timer.stop()
	for index in 3:
		var candidate: int = host.rules.deck.filter(func(id: int) -> bool: return host.rules.cards[id].kind == "property")[0]
		host.rules.deck.erase(candidate); host.rules._receive_property(0, candidate, host.rules.cards[candidate].colors[0])
	host._publish(); host.ai_timer.stop()
	var discard_card: int = host.rules.deck.filter(func(id: int) -> bool: return host.rules.cards[id].kind == "pass-go")[0]
	host.rules.deck.erase(discard_card); host.rules.discard.append(discard_card); host._publish(); host.ai_timer.stop()
	# Browser interaction fixtures need money, a direct action and a color choice.
	for kind in ["money", "pass-go", "wild"]:
		if host.rules.hands[0].any(func(id: int) -> bool: return host.rules.cards[id].kind == kind and (kind != "wild" or host.rules.cards[id].colors.size() == 2)): continue
		var candidate: int = host.rules.deck.filter(func(id: int) -> bool: return host.rules.cards[id].kind == kind and (kind != "wild" or host.rules.cards[id].colors.size() == 2))[0]
		var replaced: int = host.rules.hands[0].filter(func(id: int) -> bool: return not host.rules.cards[id].kind in ["money", "pass-go", "wild"])[0]
		var index: int = host.rules.deck.find(candidate); host.rules.deck[index] = replaced; host.rules.hands[0][host.rules.hands[0].find(replaced)] = candidate
	host._publish(); host.ai_timer.stop()
	# Keep the browser fixture representative even if a deal contains only properties.
	if not host.rules.legal_actions(0).any(func(choice: Dictionary) -> bool: return choice.payload.action == "bank"):
		var candidate: int = host.rules.deck.filter(func(id: int) -> bool: return not host.rules.cards[id].kind in ["property","wild"])[0]
		var index: int = host.rules.deck.find(candidate); host.rules.deck[index] = host.rules.hands[0][0]; host.rules.hands[0][0] = candidate; host._publish()
	# Exercise native card hit areas after a real clipped-hand browse gesture.
	var saved_hand: Array = host.rules.hands[0].duplicate(); var saved_deck: Array = host.rules.deck.duplicate()
	while host.rules.hands[0].size() < 20: host.rules.hands[0].append(host.rules.deck.pop_back())
	host._publish(); host.ai_timer.stop(); await capture("hand-drag-before")
	var point: Vector2 = host.table.hand_bounds.get_center()
	var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = point; host.table._gui_input(press)
	var movement := InputEventMouseMotion.new(); movement.position = point - Vector2(170, 0); host.table._gui_input(movement)
	var release := InputEventMouseButton.new(); release.button_index = MOUSE_BUTTON_LEFT; release.position = movement.position; host.table._gui_input(release)
	await capture("hand-drag-after")
	if host.table.hand_scroll <= 20 or host.reader.visible: failures += 1; printerr("FAIL: native dragging must browse without opening a card")
	var hit: Dictionary = host.table.hits.filter(func(target: Dictionary) -> bool: return host.table.hand_bounds.has_point(target.rect.get_center()))[-1]
	press.position = hit.rect.get_center(); release.position = press.position; host.table._gui_input(press); host.table._gui_input(release)
	if not host.reader.visible or host.table.selected_card != int(hit.card.id): failures += 1; printerr("FAIL: simple native tap must immediately enlarge without playing")
	host.reader.close(); host.rules.hands[0] = saved_hand; host.rules.deck = saved_deck; host.table.hand_scroll = 0; host._publish(); host.ai_timer.stop()
	for size in [Vector2i(1280,720),Vector2i(1366,768),Vector2i(844,390),Vector2i(390,844),Vector2i(360,640)]:
		root.min_size = Vector2i(1,1); root.content_scale_size = size; root.size = size; host._resize_table(); await capture("solo-%dx%d" % [size.x,size.y])
		if host.turn_strip.get_child_count() != host.seats.size() or host.turn_strip.get_global_rect().intersects(host.settings_button.get_global_rect()): failures += 1; printerr("FAIL: turn names must fit clear of header controls")
		if host.table.get_global_rect().end.x > root.size.x + 1: failures += 1; printerr("FAIL: table exceeds viewport")
		if size == Vector2i(1280,720) and (host.table.hand_card_size.y < 100 or host.table.hand_bounds.size.x < host.table.size.x * .85): failures += 1; printerr("FAIL: solo hand should be enlarged across the table width")
		var go: Dictionary = host.rules.view_for(0).hand.filter(func(card: Dictionary) -> bool: return card.kind == "pass-go")[0]
		host._select_card(go); host._open_selected(); await capture("focus-%dx%d" % [size.x,size.y]); host.reader.close()
		var note: Dictionary = host.rules.view_for(0).hand.filter(func(card: Dictionary) -> bool: return card.kind == "money")[0]
		host._select_card(note); await capture("focus-money-bank-%dx%d" % [size.x,size.y])
		if not host.reader.heading.text.is_empty() or host.reader.actions.get_children().map(func(button: Button) -> String: return button.text) != ["Back", "BANK"]: failures += 1; printerr("FAIL: money reader must have only BANK and no value heading")
		host.reader.close()
		var wild: Dictionary = host.rules.view_for(0).hand.filter(func(card: Dictionary) -> bool: return card.kind == "wild" and card.colors.size() == 2)[0]
		host._select_card(wild); host._open_selected(); await capture("rotate-front-%dx%d" % [size.x,size.y]); host.reader.rotate_button.pressed.emit(); await capture("rotate-back-%dx%d" % [size.x,size.y]); host.reader.close()
		host._help(); await capture("help-front-%dx%d" % [size.x,size.y])
		await tap(host.reader.flip.get_global_rect().get_center())
		if host.reader.page != 1: failures += 1; printerr("FAIL: actual mouse input must flip Help")
		await capture("help-back-%dx%d" % [size.x,size.y]); await tap(Vector2(2, size.y / 2))
		if host.reader.visible: failures += 1; printerr("FAIL: clicking outside Help must dismiss it")
		host.settings_button.button_pressed = true; await capture("settings-%dx%d" % [size.x,size.y]); host.settings_button.button_pressed = false

	root.content_scale_size = Vector2i(1280,720); root.size = Vector2i(1280,720)
	saved_hand = host.rules.hands[0].duplicate(); saved_deck = host.rules.deck.duplicate()
	while host.rules.hands[0].size() < 9: host.rules.hands[0].append(host.rules.deck.pop_back())
	host._publish(); host._local({"action":"end"}); await capture("manual-end-discard")
	if not host.decision.overlay.visible or not host.decision.body.get_children().all(func(button: Button) -> bool: return button.text.begins_with("Discard ") and button.text.contains("$")): failures += 1; printerr("FAIL: manual discard must identify each card and printed value")
	host.rules.hands[0] = saved_hand; host.rules.deck = saved_deck; host.rules.phase = "play"; host.rules.revision += 1; host._publish()
	var gallery := PanelContainer.new(); gallery.theme = host.screen.theme; gallery.z_index = 100; gallery.add_theme_stylebox_override("panel", GameLook.modern_table_sheet()); root.add_child(gallery); gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new(); gallery.add_child(center)
	var grid := GridContainer.new(); grid.columns = 6; grid.add_theme_constant_override("h_separation", 14); grid.add_theme_constant_override("v_separation", 18); center.add_child(grid)
	for key in ["water-works", "boardwalk", "reading-railroad", "birthday", "pass-go", "house", "hotel", "debt-collector", "just-say-no", "forced-deal", "money-3", "money-10"]:
		var card: Dictionary = host.rules.cards.filter(func(item: Dictionary) -> bool: return item.key == key)[0]
		var face := GameCard.new(); face.card = card; face.texture = host.table.art(key); face.accent = Color(host.rules.colors[card.colors[0]].color) if not card.colors.is_empty() else Color("17594d"); face.custom_minimum_size = Vector2(180,270); grid.add_child(face)
	await capture("card-polish-gallery"); gallery.queue_free(); await process_frame
	# Exercise real canvas-items scaling rather than resizing the logical layout.
	root.size = Vector2i(2560,1440); host._resize_table()
	var reading: Dictionary = host.rules.view_for(0).hand.filter(func(card: Dictionary) -> bool: return card.kind == "pass-go")[0]
	host._select_card(reading); host._open_selected(); host.reader.card.texture = RuntimeAssets.texture("res://Games/monopoly-deal/art/pass-go.svg"); await capture("focus-hidpi-before")
	host.reader.card.texture = GameCard.artwork("res://Games/monopoly-deal/art/pass-go.svg"); host.reader.card.queue_redraw(); await capture("focus-hidpi-sharp"); host.reader.close()
	root.size = Vector2i(1280,720); host._resize_table()
	var contrast: Dictionary = host.rules.cards.filter(func(card: Dictionary) -> bool: return card.key == "wild-railroad-utility")[0]
	host.reader.show_card(contrast, GameCard.artwork("res://Games/monopoly-deal/art/wild-railroad-utility.svg"), Color("3b4149")); await capture("wild-contrast"); host.reader.close()
	if host.table.hits.any(func(hit: Dictionary) -> bool: return hit.has("card") and not host.rules.hands[0].has(int(hit.card.id))): failures += 1; printerr("FAIL: hidden opponents cannot expose card hit targets")
	var view: Dictionary = host._snapshot(-1); host.table.state = view; host.table.queue_redraw(); await capture("spectator")
	var file := FileAccess.open(folder + "controller-state.json", FileAccess.WRITE); file.store_string(JSON.stringify(host._snapshot(0))); file.close()
	# Match the solo screenshot: four AI opponents and the complete seven-card hand.
	host.pending_count = 4; host._refresh_options(); host._apply_options(); host.ai_timer.stop()
	# Production randomizes starters; this screenshot specifically needs the host's seven-card opening.
	host.rules.start(host.seats.size(), 0); host._publish(); host.ai_timer.stop()
	await capture("solo-5-large-hand")
	if host.rules.hands[0].size() != 7 or host.table.hand_card_size.y < 100: failures += 1; printerr("FAIL: enlarged solo hand must show all seven starting cards")
	var heading_top: float = host.screen.content.global_position.y
	var hand_bottom: float = host.table.global_position.y + host.table.hand_bounds.end.y
	if heading_top < 48 or absf((heading_top + hand_bottom) / 2 - 360) > 4: failures += 1; printerr("FAIL: heading and hand must be centered together with frame clearance")
	if host.table.deck_bounds.size.y < 72 or host.table.discard_bounds.size != host.table.deck_bounds.size: failures += 1; printerr("FAIL: solo five-player Draw/Discard must remain large and equally sized")
	if host.table.stack_bounds.size() != 4 or not host.table.stack_bounds.values().all(func(bounds: Rect2) -> bool: return bounds.size.y >= 24): failures += 1; printerr("FAIL: solo opponents must have visible hand-count destinations")
	for seat in host.table.stack_bounds:
		if not host.table.seat_bounds[seat].encloses(host.table.stack_bounds[seat]) or host.table._flight_rect({"zone":"hand","seat":seat}) != host.table.stack_bounds[seat]: failures += 1; printerr("FAIL: opponent hand-count animation destinations must fit their player area")
	var playing_bounds: Rect2 = host.table.get_global_rect()
	host.rules.winner = 0; host._publish(); host.ai_timer.stop(); await capture("solo-5-result-centered")
	if not host.table.get_global_rect().is_equal_approx(playing_bounds) or not host.replay.visible or host.replay.get_global_rect().end.y > 704: failures += 1; printerr("FAIL: results must preserve table placement and fit Play Again inside the frame")
	host.rules.winner = -1; host._publish(); host.ai_timer.stop(); await capture("solo-5-large-hand")
	root.size = Vector2i(2560,1440); host._resize_table(); await capture("solo-5-large-hand-hidpi")
	root.size = Vector2i(1280,720); host._resize_table()
	for count in [2,3,4,5]:
		host.host_plays = false; host.seats.clear(); host.wins.resize(count); host.wins.fill(0)
		for index in count: host.seats.append({"id":"sample-%d"%index,"display_name":"Player %d"%(index+1),"color":["#2463eb","#e53935","#08a750","#ae39f2","#f7cf05"][index],"ai":false})
		host.rules.start(count)
		discard_card = host.rules.deck.filter(func(id: int) -> bool: return host.rules.cards[id].kind == "pass-go")[0]
		host.rules.deck.erase(discard_card); host.rules.discard.append(discard_card)
		for index in mini(15,host.rules.cards.size()):
			var card: Dictionary = host.rules.cards[index]
			if card.kind != "property": continue
			for hand in host.rules.hands: hand.erase(int(card.id))
			host.rules.deck.erase(int(card.id))
			var seat: int = (index / 3) % int(count); var destinations: Array = host.rules._destinations(seat,card.colors[0]); host.rules._put_property(seat,int(card.id),card.colors[0],int(destinations[1]) if destinations.size()>1 else -1)
		host._publish(); host._resize_table(); await capture("public-%d-players"%count)
		if host.table.get_global_rect().end.x > root.size.x+1: failures += 1; printerr("FAIL: public table exceeds viewport")
		if count == 5:
			if host.table.seat_bounds.values().any(func(bounds: Rect2) -> bool: return bounds.intersects(host.table.deck_bounds) or bounds.intersects(host.table.discard_bounds)): failures += 1; printerr("FAIL: public piles must have their own grid slot")
			for dimensions in [Vector2i(390,844), Vector2i(844,390)]:
				root.content_scale_size = dimensions; root.size = dimensions; host._resize_table(); await capture("public-5-%dx%d" % [dimensions.x, dimensions.y])
				if not host.table.seat_bounds.values().all(func(bounds: Rect2) -> bool: return bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= host.table.size.x + 1 and bounds.end.y <= host.table.size.y + 1): failures += 1; printerr("FAIL: five-player areas exceed available board")
				if host.table.deck_bounds.position.x < 0 or host.table.discard_bounds.end.x > host.table.size.x: failures += 1; printerr("FAIL: narrow five-player piles must fit the right column")
			root.content_scale_size = Vector2i(1280,720); root.size = Vector2i(1280,720); host._resize_table(); await capture("public-5-players")
			for dimensions in [Vector2i(1280,720), Vector2i(390,844), Vector2i(844,390), Vector2i(360,640)]:
				root.content_scale_size = dimensions; root.size = dimensions; host._resize_table(); host.table.state = host._snapshot(0); host.table.queue_redraw(); await capture("private-5-%dx%d" % [dimensions.x, dimensions.y])
				var end_bounds: Rect2 = host.table.end_button.get_global_rect()
				end_bounds.position -= host.table.global_position
				if dimensions == Vector2i(1280,720) and host.table.hand_card_size.y < 100: failures += 1; printerr("FAIL: five-player solo hand should have taller cards")
				for pile in [host.table.deck_bounds, host.table.discard_bounds]:
					if host.table.seat_bounds.values().any(func(bounds: Rect2) -> bool: return pile.intersects(bounds)): failures += 1; printerr("FAIL: larger piles overlap a player area at %s" % dimensions)
				if host.table.end_button.visible and (end_bounds.intersects(host.table.hand_bounds) or host.table.seat_bounds.values().any(func(bounds: Rect2) -> bool: return end_bounds.intersects(bounds))): failures += 1; printerr("FAIL: five-player End Turn overlaps a hand or player area at %s" % dimensions)
			root.content_scale_size = Vector2i(1280,720); root.size = Vector2i(1280,720); host._publish(); host._resize_table()
	host.host_plays = true; host.rules.start(5)
	var many: Array = host.rules.cards.filter(func(card: Dictionary) -> bool: return card.kind == "property").slice(0,16)
	for card in many:
		for held in host.rules.hands: held.erase(int(card.id))
		host.rules.deck.erase(int(card.id)); host.rules._put_property(0, int(card.id), card.colors[0])
	host._publish(); host.ai_timer.stop(); await capture("many-properties-1280")
	if host.rules.properties[0].size() != 16 or not host.table.hits.filter(func(hit: Dictionary) -> bool: return hit.has("group") and hit.seat == 0).all(func(hit: Dictionary) -> bool: return host.table.seat_bounds[0].encloses(hit.rect)): failures += 1; printerr("FAIL: sixteen property groups must remain bounded")
	host._show_public(0); await capture("many-properties-public")
	if host.inspection.body.get_child_count() < 17: failures += 1; printerr("FAIL: View All must expose every property group")
	host.inspection.overlay.hide()
	_setup_late_table(host)
	root.content_scale_size = Vector2i(1280,720); root.size = Vector2i(1280,720); host._resize_table()
	var rent_card: Dictionary = host.rules.view_for(0).hand.filter(func(card: Dictionary) -> bool: return card.kind == "rent")[0]
	host._select_card(rent_card); await capture("modern-rent-reader-1280"); host.reader.close(); await capture("modern-solo-late-1280")
	var own_stacks: Array = host.table.group_bounds.keys().filter(func(key: String) -> bool: return key.begins_with("0:"))
	if own_stacks.size() != 5 or own_stacks.any(func(key: String) -> bool: return host.table.group_bounds[key].size.y < 80): failures += 1; printerr("FAIL: five mixed-width sets must use the host's available horizontal space")
	host._inspect_group(0, int(host.rules.properties[0][0].id)); await capture("modern-set-sheet-1280"); host.inspection.overlay.hide()
	root.content_scale_size = Vector2i(768,1024); root.size = Vector2i(768,1024); host._resize_table(); await capture("modern-solo-late-tablet")
	if not host.table.find_children("*", "GameTableInspector", true, false).is_empty() or host.table.get_global_rect().end.y > 1024: failures += 1; printerr("FAIL: tablet host must fit without a side inspector")
	root.content_scale_size = Vector2i(1920,1080); root.size = Vector2i(1920,1080); host._resize_table(); await capture("modern-solo-late-1920")
	host.host_plays = false; host._publish(); await capture("modern-public-late-1920")
	if host.table.action_row.get_children().any(func(button: Button) -> bool: return button.visible and button != host.table.end_button and button != host.replay and button.text != "Public Table"): failures += 1; printerr("FAIL: public host cannot expose private-card controls")
	host.host_plays = true; host._publish()
	file = FileAccess.open(folder + "controller-state.json", FileAccess.WRITE); file.store_string(JSON.stringify(host._snapshot(0))); file.close()
	root.content_scale_size = Vector2i(1280,720); root.size = Vector2i(1280,720); host._resize_table()
	host.session.reduced_motion = false; host.rules.start(5); host._start_deal(); host._publish()
	await capture("five-player-shuffle"); await create_timer(0.52).timeout; await capture("five-player-deal")
	await create_timer(host.motion_timer.time_left + 0.1).timeout
	host.ai_timer.stop(); host.session.reduced_motion = true
	for dimensions in [Vector2i(1280,720), Vector2i(390,844), Vector2i(844,390)]:
		root.content_scale_size = dimensions; root.size = dimensions; host._resize_table()
		host.settings_button.button_pressed = true; host.turn_timer_toggle.button_pressed = false; await capture("timer-off-settings-%dx%d" % [dimensions.x, dimensions.y])
		if not host.apply_button.disabled: host._apply_options()
		else: host.settings_button.button_pressed = false
		host.ai_timer.stop()
		await capture("untimed-%dx%d" % [dimensions.x, dimensions.y])
		if host.clock_running or host._status().contains(":"): failures += 1; printerr("FAIL: untimed native view must omit the countdown")
		host.rules.start(host.seats.size()); host.rules.turn = 1
		for seat in host.seats.size():
			host.rules.hands[seat].clear(); host.rules.banks[seat].clear(); host.rules.properties[seat].clear()
		host.rules.deck = range(host.rules.cards.size()); host.rules.discard.clear()
		var debt := _take_ui_card(host, "debt-collector"); host.rules.hands[1].append(debt)
		var cash := _take_ui_card(host, "money-10"); host.rules.banks[0].append(cash)
		host._action(1, {"action":"debt", "card":debt, "target":0, "revision":host.rules.revision}); host.ai_timer.stop()
		await capture("direct-payment-%dx%d" % [dimensions.x, dimensions.y])
		if not host.decision.overlay.visible or host.rules.phase != "pay" or not host.decision.heading.text.contains("Debt Collector") or host.decision.body.find_children("*", "GameCardGrid", true, false).size() != 1: failures += 1; printerr("FAIL: native payment must identify the played card and display selectable cards")
		if host.decision.panel.get_global_rect().end.y > dimensions.y: failures += 1; printerr("FAIL: compact payment must fit the native viewport")
		host.decision.overlay.hide(); host.rules.pending.clear(); host.rules.phase = "play"; host._publish(); host.ai_timer.stop()
	await _polish_visual(host)
	await _debt_options_visual(host)
	await _refinements_visual(host)
	await _rent_face_visual(host)
	app._return_from_game(); await capture("return")
	app._show_asset_editor(); app.asset_editor._open_themes("monopoly-deal"); await capture("theme-editor")
	var editor: Control = app.asset_editor.theme_editor
	if editor.manager.slots.size() != 69 or not editor.save_button.disabled: failures += 1; printerr("FAIL: theme editor default state")
	editor.selected = editor.manager.slots[0]; editor._inspect(); await capture("theme-inspector")
	editor._preview(); await capture("theme-table-preview")
	var dialog: AcceptDialog = editor.find_children("*","AcceptDialog",true,false).filter(func(node: Node) -> bool: return node.visible)[0]
	var tabs: TabContainer = dialog.find_children("*","TabContainer",true,false)[0]; tabs.current_tab = 1; await capture("theme-phone-preview"); dialog.hide(); dialog.queue_free()
	for size in [Vector2i(390,844),Vector2i(844,390)]:
		root.content_scale_size = size; root.size = size; await capture("theme-editor-%dx%d" % [size.x,size.y])
		if editor.inspector.get_global_rect().end.x > size.x+1: failures += 1; printerr("FAIL: theme inspector exceeds viewport")
	app.queue_free(); RuntimeAssets.refresh()
	for frame in 5: await process_frame
	print("Monopoly Deal visual: %d failures" % failures); quit(1 if failures else 0)


func _rent_face_visual(host: Node) -> void:
	var viewport := SubViewport.new(); viewport.size = Vector2i(1400, 460); viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var background := ColorRect.new(); background.color = Color("17374b"); background.size = viewport.size; viewport.add_child(background)
	var samples := [["connecticut-avenue", "light-blue", 2, 2], ["mediterranean-avenue", "brown", 2, 5], ["b-and-o-railroad", "railroad", 3, 3], ["wild-pink-orange", "orange", 2, 3], ["wild-any", "yellow", 2, 4]]
	for index in samples.size():
		var sample: Array = samples[index]
		var face: Dictionary = host.rules.cards.filter(func(card: Dictionary) -> bool: return card.key == sample[0])[0].duplicate(true)
		var group := {"color":sample[1], "cards":range(int(sample[2])), "rent":sample[3]}
		face.face_side = int(face.kind == "wild" and face.colors.size() == 2 and face.colors[1] == sample[1]); face.face_schedule = host.table.face_schedule(group, face)
		var card := GameCard.new(); card.card = face; card.texture = host.table.art(face.key); card.accent = Color(host.rules.colors[sample[1]].color)
		card.position = Vector2(32 + index * 274, 60); card.size = Vector2(240, 360); viewport.add_child(card)
		var label := Label.new(); label.text = "%d/%d · Rent $%d" % [sample[2], host.rules.colors[sample[1]].size, sample[3]]; label.position = card.position - Vector2(0, 32); viewport.add_child(label)
	for frame in 5: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(folder + "live-rent-faces.png")
	viewport.queue_free(); await process_frame


func _refinements_visual(host: Node) -> void:
	_setup_late_table(host); host.session.reduced_motion = true
	for seat in range(1, host.seats.size()):
		host.rules.deck.append_array(host.rules.hands[seat]); host.rules.hands[seat].clear()
	var forced := _take_ui_card(host, "forced-deal"); host.rules.hands[0].append(forced)
	var double := _take_ui_card(host, "double-rent"); host.rules.hands[0].append(double)
	var any_wild := _take_ui_card(host, "wild-any"); host.rules.hands[0].append(any_wild)
	# Populate the bounded feed through accepted commands, without invented outcomes.
	for index in 10:
		host.rules.plays = 0
		var money: int = host.rules.deck.filter(func(id: int) -> bool: return host.rules.cards[id].kind == "money")[0]
		host.rules.deck.erase(money); host.rules.hands[0].append(money)
		host._action(0, {"action":"bank", "card":money, "revision":host.rules.revision}); host.ai_timer.stop()
	host.rules.plays = 0; host._publish(); host.ai_timer.stop()
	for dimensions in [Vector2i(1280,720), Vector2i(390,844), Vector2i(844,390)]:
		root.content_scale_size = dimensions; root.size = dimensions; host._resize_table(); await capture("activity-table-%dx%d" % [dimensions.x, dimensions.y])
		host.history_button.pressed.emit(); await capture("activity-dialog-%dx%d" % [dimensions.x, dimensions.y])
		if not host.history_dialog.overlay.visible or host.table.history_bounds.has_area() or host.table.activity_log.get_parent() != host.history_dialog.body: failures += 1; printerr("FAIL: History must open from its button without occupying board space")
		host.history_dialog.overlay.hide()
		host._select_card(host.rules.cards[forced]); await capture("forced-categories-%dx%d" % [dimensions.x, dimensions.y]); host.reader.close()
		host._select_card(host.rules.cards[double]); await capture("double-rent-%dx%d" % [dimensions.x, dimensions.y]); host.reader.close()
		host._select_card(host.rules.cards[any_wild]); await capture("wild-color-cards-%dx%d" % [dimensions.x, dimensions.y]); host.reader.close()
	root.content_scale_size = Vector2i(1280,720); root.size = Vector2i(1280,720); host._resize_table()


func _debt_options_visual(host: Node) -> void:
	host.animating = false; host.motion_timer.stop(); host.rules.start(5, 0)
	for seat in 5:
		host.rules.hands[seat].clear(); host.rules.banks[seat].clear(); host.rules.properties[seat].clear()
	host.rules.deck = range(host.rules.cards.size()); host.rules.discard.clear()
	var debt := _take_ui_card(host, "debt-collector"); host.rules.hands[0].append(debt)
	var property := _take_ui_card(host, "boardwalk"); host.rules._receive_property(2, property, "dark-blue")
	for seat in [1, 3, 4]:
		for index in 9:
			var id: int = host.rules.deck.filter(func(value: int) -> bool: return host.rules.cards[value].kind not in ["property", "wild"])[0]
			host.rules.deck.erase(id); host.rules.banks[seat].append(id)
	host.session.reduced_motion = true; host._publish(); host.ai_timer.stop()
	for dimensions in [Vector2i(1280,720), Vector2i(390,844), Vector2i(844,390)]:
		root.content_scale_size = dimensions; root.size = dimensions; host._resize_table(); host._select_card(host.rules.cards[debt])
		await capture("debt-options-%dx%d" % [dimensions.x, dimensions.y])
		if host.reader.preview.selector.visible or host.reader.preview.player_buttons.size() != 4: failures += 1; printerr("FAIL: every debt target must be visible without a dropdown")
		if host.reader.preview.get_global_rect().end.x > dimensions.x: failures += 1; printerr("FAIL: debt options must fit the native viewport")
		host.reader.close()
	root.content_scale_size = Vector2i(1280,720); root.size = Vector2i(1280,720)


func _take_ui_card(host: Node, key: String) -> int:
	var id: int = host.rules.deck.filter(func(candidate: int) -> bool: return host.rules.cards[candidate].key == key)[0]
	host.rules.deck.erase(id); return id


func _polish_visual(host: Node) -> void:
	root.content_scale_size = Vector2i(1280,720); root.size = Vector2i(1280,720); host._resize_table()
	_setup_late_table(host); host._inspect_group(0, host.rules.properties[0][0].id); await capture("polish-fixed-inspector"); host.inspection.overlay.hide()
	for seat in host.seats.size():
		host.rules.hands[seat].clear(); host.rules.banks[seat].clear(); host.rules.properties[seat].clear()
	host.rules.deck = range(host.rules.cards.size()); host.rules.discard.clear(); host.rules.turn = 1; host.rules.plays = 0
	var debt := _take_ui_card(host, "debt-collector"); host.rules.hands[1].append(debt)
	var refusal := _take_ui_card(host, "just-say-no"); host.rules.hands[0].append(refusal)
	for key in ["money-10", "money-1", "money-2", "money-3", "money-4"]: host.rules.banks[0].append(_take_ui_card(host, key))
	var property := _take_ui_card(host, "boardwalk"); host.rules._receive_property(0, property, "dark-blue")
	host.session.reduced_motion = false; host._publish(); host.ai_timer.stop()
	host._action(1, {"action":"debt", "card":debt, "target":0, "revision":host.rules.revision}); host.ai_timer.stop(); await create_timer(0.25).timeout; await capture("polish-debt-effect")
	await create_timer(host.motion_timer.time_left + 0.1).timeout; host.ai_timer.stop()
	host._action(0, {"action":"no", "card":refusal, "revision":host.rules.revision}); await create_timer(0.25).timeout; await capture("polish-stop-effect")
	var frozen: float = host._snapshot(0).motion.elapsed; host.settings_button.button_pressed = true; await create_timer(0.1).timeout
	if absf(float(host._snapshot(0).motion.elapsed) - frozen) > 0.05: failures += 1; printerr("FAIL: action effect must pause with Settings")
	host.settings_button.button_pressed = false; host.ai_timer.stop(); await create_timer(host.motion_timer.time_left + 0.1).timeout; host.ai_timer.stop()
	host.session.reduced_motion = true; debt = _take_ui_card(host, "debt-collector"); host.rules.hands[1].append(debt)
	host._action(1, {"action":"debt", "card":debt, "target":0, "revision":host.rules.revision}); host.ai_timer.stop(); await create_timer(0.9).timeout
	for dimensions in [Vector2i(1280,720), Vector2i(390,844), Vector2i(844,390)]:
		root.content_scale_size = dimensions; root.size = dimensions; host._resize_table(); await capture("polish-payment-grid-%dx%d" % [dimensions.x,dimensions.y])
		if host.decision.panel.get_global_rect().end.x > dimensions.x - 8 or host.decision.panel.global_position.x < 8: failures += 1; printerr("FAIL: responsive payment grid must fit the native viewport width")
	host._action(0, {"action":"pay", "cards":[host.rules.banks[0][0]], "revision":host.rules.revision}); host.ai_timer.stop()
	root.content_scale_size = Vector2i(1280,720); root.size = Vector2i(1280,720); host._resize_table(); host._show_public(0); await capture("polish-public-cards"); host.inspection.overlay.hide()
	host._inspect_group(0, host.rules.properties[0][0].id); await capture("polish-missing-slot"); host.inspection.overlay.hide()
	host.rules.start(host.seats.size()); host.rules.deck = range(host.rules.cards.size()); host.rules.discard.clear()
	for seat in host.seats.size(): host.rules.hands[seat].clear(); host.rules.banks[seat].clear(); host.rules.properties[seat].clear()
	for key in ["mediterranean-avenue","baltic-avenue","st-charles-place","states-avenue","virginia-avenue","atlantic-avenue","ventnor-avenue","marvin-gardens","boardwalk","pacific-avenue","reading-railroad"]:
		property = _take_ui_card(host, key); host.rules._receive_property(0, property, host.rules.cards[property].colors[0])
	host.rules.winner = 0; host.rules.phase = "finished"; host.rules.revision += 1; host.session.reduced_motion = false; host._publish(); host.ai_timer.stop()
	await create_timer(0.2).timeout; await capture("polish-winner-burst"); await create_timer(2.9).timeout; await capture("polish-winner-properties")
	var visible_groups: int = host.table.group_bounds.keys().filter(func(key: String) -> bool: return key.begins_with("0:")).size()
	if visible_groups != host.rules.properties[0].size(): failures += 1; printerr("FAIL: winning player must show every property group")
	var bar: VScrollBar = host.screen.content_scroll.get_v_scroll_bar()
	if bar.max_value - bar.page > 1: failures += 1; printerr("FAIL: fitting solo table must not have empty vertical scrolling")
	host.rules.properties[4] = host.rules.properties[0]; host.rules.properties[0] = []; host.rules.winner = 4
	for dimensions in [Vector2i(390,844), Vector2i(844,390)]:
		root.content_scale_size = dimensions; root.size = dimensions; host._publish(); host._resize_table(); await capture("polish-winning-opponent-%dx%d" % [dimensions.x, dimensions.y])
		visible_groups = host.table.group_bounds.keys().filter(func(key: String) -> bool: return key.begins_with("4:")).size()
		if visible_groups != host.rules.properties[4].size(): failures += 1; printerr("FAIL: winning opponent must show every group in portrait and landscape")
	root.content_scale_size = Vector2i(1280,720); root.size = Vector2i(1280,720); host._resize_table()


func _setup_late_table(host: Node) -> void:
	host.host_plays = true; host.ai_timer.stop(); host.motion_timer.stop(); host.animating = false; host.rules.start(5)
	host.notice_text = ""; host.notice_until = 0
	for seat in 5:
		host.rules.hands[seat].clear(); host.rules.banks[seat].clear(); host.rules.properties[seat].clear()
	host.rules.deck = range(host.rules.cards.size()); host.rules.discard.clear()
	var properties := [
		["mediterranean-avenue","baltic-avenue","oriental-avenue","vermont-avenue","boardwalk","kentucky-avenue","north-carolina-avenue"],
		["indiana-avenue","illinois-avenue","st-charles-place","states-avenue","reading-railroad"],
		["st-james-place","tennessee-avenue","new-york-avenue","atlantic-avenue","ventnor-avenue","electric-company"],
		["park-place","pennsylvania-avenue","pacific-avenue","pennsylvania-railroad","b-and-o-railroad"],
		["marvin-gardens","connecticut-avenue","virginia-avenue","short-line"]]
	for seat in 5:
		for key in properties[seat]:
			var id := _take_ui_card(host, key); host.rules._receive_property(seat, id, host.rules.cards[id].colors[0])
	for key in ["wild-light-blue-brown","rent-light-blue-brown","pass-go","sly-deal","house","money-2","just-say-no"]: host.rules.hands[0].append(_take_ui_card(host,key))
	host.rules.properties[0][0].buildings.append(_take_ui_card(host,"house"))
	for seat in 5:
		for key in (["money-10","money-2"] if seat == 0 else ["money-1"]): host.rules.banks[seat].append(_take_ui_card(host,key))
	for seat in 5:
		if seat > 0:
			for index in 5: host.rules.hands[seat].append(host.rules.deck.pop_back())
	host.rules.discard.append(_take_ui_card(host,"debt-collector")); host.rules.turn = 0; host.rules.revision += 1; host._publish(); host.ai_timer.stop()
