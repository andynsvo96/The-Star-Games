extends SceneTree

# Synthetic shared UI coverage; no playable module dependency.
var checks := 0
var failures := 0
func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: "+message)
func tap(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new(); motion.position = point; Input.parse_input_event(motion)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.position = point; Input.parse_input_event(event)
		await process_frame
func _run() -> void:
	root.min_size = Vector2i.ONE; root.content_scale_size = Vector2i(640,480); root.size = Vector2i(640,480)
	var standings := GameLeaderboard.new()
	standings.theme = GameLook.make_theme("studio-modern")
	root.add_child(standings)
	var standings_entries: Array = []
	for seat in 16:
		standings_entries.append({"seat":seat, "display_name":"Literal <player> [name] %d" % seat, "score":1600 - seat * 100, "color":"#286ac2", "rank":seat + 1, "medal":["gold","silver","bronze"][seat] if seat < 3 else "", "delta":100 if seat == 0 else 0})
	standings.set_entries(standings_entries, 0)
	var standings_first: Button = standings.rows[0].button
	var standings_selected: Array = []
	standings.player_selected.connect(func(seat: int) -> void: standings_selected.append(seat))
	for width in [320, 640]:
		standings.size.x = width
		for frame in 4: await process_frame
		check(standings.rows.size() == 16 and standings.rows[0].player.text == "Literal <player> [name] 0", "Standings preserve all public seats and literal names")
		check(standings.rows[0].rank.text == "1st" and standings.rows[1].rank.text == "2nd" and standings.rows[2].rank.text == "3rd", "Standings supply ordinal medal captions")
		check(standings.rows[0].rank.get_theme_color("font_color") == GameLook.medal_color("gold") and standings.rows[2].rank.get_theme_color("font_color") == GameLook.medal_color("bronze"), "Standings use shared medal colors")
		check(standings.rows[0].delta.visible and not standings.rows[1].delta.visible, "Only positive accepted awards have a delta")
		check(standings.rows[0].button.get_theme_stylebox("normal").shadow_size == 0, "Modern studio omits decorative panel shadows")
		standings_first.grab_focus()
		standings.set_entries(standings_entries, 0)
		check(standings.rows[0].button == standings_first and standings_first.has_focus(), "Identical standings snapshots retain keyboard focus and targets")
	await tap(standings_first.get_global_rect().get_center())
	check(standings_selected == [0], "A real standings name/avatar press opens the selected seat")
	standings_entries.reverse()
	standings.set_entries(standings_entries, 0)
	check(standings.rows[-1].button == standings_first and standings.rows[-1].seat == 0, "Reordering scores keeps each native input target attached to its own identity")
	standings.rows[-1].button.pressed.emit()
	check(standings_selected == [0, 0], "A reordered identity cannot open another player's history")
	var modern_action := Button.new(); standings.add_child(modern_action); modern_action.text = "Play Again"; GameLook.action(modern_action)
	check(modern_action.theme_type_variation == "GamePrimaryButton" and modern_action.get_theme_stylebox("normal") is StyleBoxFlat and modern_action.get_theme_stylebox("normal").shadow_size == 0, "Modern studio actions inherit the flat shared palette")
	var blue_standings := GameLeaderboard.new()
	blue_standings.theme = GameLook.make_theme("studio-blue")
	blue_standings.compact = true
	root.add_child(blue_standings)
	blue_standings.size.x = 320
	blue_standings.set_entries([{"seat":0,"display_name":"Name","color":"#286ac2","score":100,"speech":"a literal guess","quality":"close"}])
	for frame in 6: await process_frame
	var blue_row: Dictionary = blue_standings.rows[0]
	check(blue_row.bubble.panel.visible and blue_row.bubble.label.text == "a literal guess" and blue_row.bubble.panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Blue standings retain input-transparent literal speech bubbles")
	check(GameLook.text_contrast(blue_row.player.get_theme_color("font_color"), blue_row.button.get_theme_stylebox("normal").bg_color) >= 4.5, "Dark blue score rows keep readable names")
	check(GameLook.drawing_sheet(true).bg_color == Color.WHITE and GameLook.modern_studio_sheet(true).bg_color == Color("102b46"), "Blue UI surfaces preserve white drawing paper with stronger panel separation")
	var prompt_board := Control.new()
	prompt_board.theme = blue_standings.theme
	root.add_child(prompt_board)
	prompt_board.size = Vector2(320, 240)
	var prompt := GameCanvasOverlay.new()
	prompt_board.add_child(prompt)
	prompt.set_message("Literal <player> is choosing")
	for frame in 4: await process_frame
	check(prompt.visible and prompt.heading.text == "Literal <player> is choosing" and prompt.get_rect().size.is_equal_approx(prompt_board.size), "Canvas prompts dim the complete board and keep literal text")
	check(prompt_board.get_global_rect().encloses(prompt.panel.get_global_rect()) and prompt.panel.get_global_rect().get_center().distance_to(prompt_board.get_global_rect().get_center()) < 1, "Canvas prompt panels stay centered inside the playfield: %s / %s" % [prompt.panel.get_global_rect(), prompt_board.get_global_rect()])
	prompt.set_message("")
	check(not prompt.visible, "Clearing a phase prompt restores canvas input")
	prompt_board.queue_free()
	var speech_target: Button = blue_row.button
	blue_standings.set_entries([{"seat":0,"display_name":"Name","score":100}])
	check(not blue_row.bubble.panel.visible and blue_standings.rows[0].button == speech_target, "Expiring speech preserves the player's existing input target")
	blue_standings.queue_free()
	standings.queue_free()
	await process_frame
	for sample in [[0,0],[1,1],[10,1],[11,2],[50,2],[51,3],[100,3],[101,4],[999,4],[1000,5],[1000000,5]]:
		check(GameLook.chip_pile_stage(sample[0]) == sample[1], "Chip pile stage respects amount boundary %d" % sample[0])
	root.min_size = Vector2i.ONE; root.content_scale_size = Vector2i(640,480); root.size = Vector2i(640,480)
	var combinations := GameRankedResults.new(); combinations.show_details = false; root.add_child(combinations)
	var example: Dictionary = JSON.parse_string('{"rank":1,"name":"Three of a Kind","category":"Hidden description","dimmed_cards":[3,4],"cards":[{"layout":"standard","rank":"J","suit":"hearts"},{"layout":"standard","rank":"J","suit":"clubs"},{"layout":"standard","rank":"J","suit":"spades"},{"layout":"standard","rank":"4","suit":"spades"},{"layout":"standard","rank":"2","suit":"diamonds"}]}')
	combinations.set_entries(range(10).map(func(_index: int) -> Dictionary: return example.duplicate(true)))
	for bounds in [Vector2(360,420),Vector2(800,240)]:
		combinations.size.x = bounds.x; combinations.maximum_height = bounds.y; combinations._fit()
		check(combinations.fitted_height <= bounds.y and combinations.card_rects().all(func(rect: Rect2) -> bool: return Rect2(Vector2.ZERO, Vector2(bounds.x, combinations.fitted_height)).grow(.01).encloses(rect)), "Compact card guides fit all ten examples and complete faces in %s" % bounds)
	check(combinations.entries[0].dimmed_cards == [3,4] and not combinations.get_child(0).show_details, "JSON dimming indices select the two kickers while the compact guide omits descriptions")
	combinations.queue_free()
	var section := GameSection.new(); section.caption = "Players"; root.add_child(section); section.size = Vector2(300,220)
	var inventory := GameResourceHand.new(); section.content.add_child(inventory)
	var items: Array = []
	for index in 5: items.append({"texture":RuntimeAssets.texture("res://ui/playful/stat-resources.svg"),"label":"Resource %d" % index,"amount":index,"color":Color("27ad68")})
	inventory.set_items(items); var amount := inventory.amounts[0]; items[0].amount = 3; inventory.set_items(items)
	check(inventory.amounts[0] == amount and amount.text == "3","Resource updates preserve the live count target")
	check(inventory.tooltip_text.is_empty() and inventory.accessibility_name.contains("Resource 0: 3"),"Icon-only inventory retains literal accessible quantities without hover text")
	var card_inventory := GameResourceHand.new(); card_inventory.inspect_caption = "Inspect development cards"; root.add_child(card_inventory)
	var card_items: Array = []
	for index in 5: card_items.append({"card":{"layout":"symbol","name":"Public example","detail":"Choose a token."},"texture":items[0].texture,"label":"Example card","amount":2 if index == 0 else 0,"empty":index > 0})
	card_inventory.set_items(card_items)
	for compact in [false,true]:
		inventory.compact = compact; card_inventory.compact = compact; inventory._layout(); card_inventory._layout(); card_inventory.size = inventory.size; card_inventory._layout()
		var aligned := true
		for index in 5:
			if inventory.card_rect(index) != card_inventory.card_rect(index) or inventory.amounts[index].position != card_inventory.amounts[index].position or inventory.amounts[index].size != card_inventory.amounts[index].size: aligned = false
		check(aligned,"Card-face and resource quickviews share exact slot and badge geometry, compact=%s" % compact)
	check(card_inventory.amounts[0].visible and card_inventory.amounts[0].text == "2" and card_inventory.amounts.slice(1).all(func(label: Label) -> bool: return not label.visible),"Card-face inventories show owned counts and omit empty-slot zero badges")
	check(not card_inventory.disabled and card_inventory.accessibility_name.contains("Inspect development cards"),"The whole card-face quickview remains inspectable with a literal accessible caption")
	inventory.compact = false; inventory._layout(); card_inventory.queue_free()
	check(section.heading.text == "Players" and section.get_theme_stylebox("panel").bg_color == GameLook.section_sheet().bg_color,"Sections use shared compact feed chrome")
	var flip := Button.new(); flip.icon = RuntimeAssets.texture("res://ui/playful/control-rotate.svg"); flip.toggle_mode = true; flip.accessibility_name = "Flip inventory"; section.set_header_action(flip)
	for unused in 3: await process_frame
	check(flip.get_parent() == section.metric and flip.size.x >= 44 and flip.size.y >= 44 and flip.tooltip_text.is_empty(),"Section header actions retain a trailing accessible 44px target without hover text")
	var costs := GameCostRow.new(); costs.icon_only = true; section.content.add_child(costs); costs.set_items([{"texture":items[0].texture,"label":"Resource","owned":1,"required":2,"available":false}])
	check(costs.find_children("*","Label",true,false).size() == 1 and costs.get_child(0).accessibility_name.contains("have 1, need 2"),"Icon-only costs omit prose while retaining accessible requirements")
	var compact_cost := GameCostRow.new(); compact_cost.dark = true; compact_cost.icon_only = true; compact_cost.compact = true; root.add_child(compact_cost); compact_cost.position = Vector2(350,100); compact_cost.size = Vector2(250,44)
	compact_cost.set_items([{"texture":items[0].texture,"label":"Material","owned":1,"required":2,"available":false}])
	for unused in 3: await process_frame
	check(compact_cost.get_combined_minimum_size().y <= 44 and compact_cost.find_children("*","Label",true,false)[0].text == "1/2" and compact_cost.get_child(0).accessibility_name.contains("have 1, need 2"),"Compact costs keep owned/required meaning in a short horizontal chip")
	compact_cost.queue_free()
	var row := GamePlayerRow.new(); section.content.add_child(row); row.leader = "silver"; row.set_player({"display_name":"Name <literal>","color":"#2463eb"},[],false)
	check(row.name_label.text == "Name <literal>" and row.accessibility_name.contains("Joint leader"),"Leader feedback is explicit and names remain literal")
	var balance := Rect2(20,30,20,24); var gain := GameMoneyEffect.amount_rect(balance,1,0,18,"right"); var loss := GameMoneyEffect.amount_rect(balance,-1,0,18,"right")
	check(gain.position.x > balance.end.x and gain == loss,"Right placement keeps both signed changes beside their own counter")
	check(GameMoneyEffect.amount_rect(balance,1,0).end.y < balance.position.y,"Existing vertical feedback keeps its default placement")
	section.center_heading = true; section.set_summary_metric(RuntimeAssets.texture("res://ui/playful/stat-victory.svg"),12,"Points to win: 12")
	for unused in 3: await process_frame
	check(section.summary.text == "12" and section.summary_icon.visible and absf(section.heading.get_global_rect().get_center().x-section.get_global_rect().get_center().x)<2,"Centered section headings keep a separate icon-only target")
	items[0].amount = 0; inventory.set_items(items)
	check(inventory.amounts[0].modulate.a < .5 and inventory.amounts[1].modulate.a == 1 and inventory.amounts[0].size.x == 24,"Empty resource counts dim and badges stay compact")
	var bitmap := Image.create(256,128,false,Image.FORMAT_RGBA8); bitmap.fill(Color.WHITE); var source := ImageTexture.create_from_image(bitmap); var bounded := GameLook.choice_item_icon(source)
	check(bounded.get_width() == 28 and bounded.get_height() == 14 and source.get_width() == 256,"Menu symbols are bounded without changing source art or its proportions")
	var exchange := GameExchangeButton.new(); section.content.add_child(exchange); var held_button := exchange
	var term := {"give_texture":source,"take_texture":source,"owned":3,"rate":3,"port":true,"label":"Have 3 cards. Trade 3 for 1 token using a port"}; exchange.set_exchanges([term])
	check(exchange.accessibility_name.contains("Have 3") and exchange.content.get_child(0).get_child(0).get_parsed_text() == "3 / 4 3","Exchange buttons combine held quantities with the discounted requirement")
	term.rate = 4; term.port = false; exchange.set_exchanges([term])
	check(exchange == held_button and not exchange.find_children("*","Label",true,false).any(func(label: Label) -> bool: return label.text == "⚓"),"Supply exchange updates keep the same confirmation target and omit port anchors")
	var unfunded: StyleBoxFlat = exchange.get_theme_stylebox("disabled")
	check(unfunded.bg_color.a == 0 and unfunded.border_color == Color("7c8d99"),"Unfunded exchanges keep transparent surfaces and a grey outline")
	exchange.confirmation_text = "BUILD"; exchange.set_exchanges([term,term])
	check(exchange.find_children("*","Label",true,false).filter(func(label: Label) -> bool: return label.text == "BUILD").size() == 1 and not exchange.find_children("*","Label",true,false).any(func(label: Label) -> bool: return label.text == "✓"),"Exchange plans can use one explicit action caption instead of checkmarks")
	var underlying := Button.new(); underlying.position = Vector2(20,420); underlying.size = Vector2(44,44); root.add_child(underlying); var clicked := [false]; underlying.pressed.connect(func() -> void: clicked[0] = true)
	var actions := GameActionRow.new(); actions.position = Vector2(0,420); actions.size = Vector2(640,44); root.add_child(actions); var action := Button.new(); action.text = "Action"; actions.add_child(action)
	for unused in 3: await process_frame
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; event.position = Vector2(42,442); Input.parse_input_event(event); await process_frame
	check(clicked[0],"Empty toolbar space passes clicks to visible controls underneath")
	var left_action := Button.new(); left_action.text = "Long history label"; actions.add_child(left_action); actions.move_child(left_action,0)
	var right_action := Button.new(); right_action.text = "Help"; actions.add_child(right_action); actions.centered_button = action
	for width in [320,640]:
		actions.size.x = width
		for unused in 4: await process_frame
		check(absf(action.get_global_rect().get_center().x-actions.get_global_rect().get_center().x)<1 and actions.get_children().all(func(control: Button) -> bool: return actions.get_global_rect().encloses(control.get_global_rect()) and control.size.y >= 44),"A chosen action stays exactly centered with unequal flanks at %d pixels" % width)
	actions.queue_free(); underlying.queue_free()
	var choice_grid := GameCardGrid.new(); choice_grid.selectable = true; choice_grid.selection_limit = 1; choice_grid.dim_selected = true; root.add_child(choice_grid); choice_grid.size = Vector2(300,180)
	choice_grid.set_items([{"card":{"id":1,"name":"First","value":1},"texture":source},{"card":{"id":2,"name":"Second","value":2},"texture":source}])
	choice_grid.get_child(0).pressed.emit(); choice_grid.get_child(1).pressed.emit()
	check(choice_grid.selected == [1] and choice_grid.get_child(0).get_child(0).modulate.r < .5 and choice_grid.get_child(1).get_child(0).modulate == Color.WHITE,"Limited card selection dims only the accepted choice and rejects excess selections")
	choice_grid.get_child(0).pressed.emit()
	check(choice_grid.selected.is_empty() and choice_grid.get_child(0).get_child(0).modulate == Color.WHITE,"Deselecting a dimmed card restores its full face")
	choice_grid.queue_free()
	var preview := GameActionPreview.new(); root.add_child(preview); preview.size = Vector2(340,220)
	preview.set_options([{"label":"Player", "players":[{"display_name":"Name <literal>", "bank_total":0, "property_total":7}], "items":[]}], -1, "players")
	for unused in 4: await process_frame
	check(preview.player_buttons.size() == 1 and preview.player_buttons[0].accessibility_name.contains("Cash: $0, payable properties and buildings: $7"),"A property-only payment target retains separate public values and a literal name")
	var total: RichTextLabel = preview.find_children("*","RichTextLabel",true,false)[0]
	check(total.get_parsed_text().contains("$0 + $7") and total.size.x > 90 and total.get_parent().get_global_rect().encloses(total.get_global_rect()),"Cash and property icons fit a real native payment-choice target")
	preview.queue_free()
	var activity := GameActivityLog.new(); root.add_child(activity); activity.size = Vector2(300,150)
	activity.set_entries([{"id":1,"text":"Name <literal> paid $5 → Other","parts":[{"text":"Name <literal>","color":"#80c8ff"},{"text":" paid $5 "},{"icon":"bank"},{"text":" → Other"}]}],true)
	var entry: RichTextLabel = activity.entries.get_child(0)
	check(not entry.bbcode_enabled and entry.accessibility_name == "Name <literal> paid $5 → Other" and entry.get_parsed_text().contains("Name <literal>"),"JSON-safe activity icons preserve literal names and complete accessible transfers")
	activity.queue_free()
	for presentation in ["admiral", "studio-blue", "studio-modern"]:
		var overlay := GameCanvasOverlay.new(); overlay.theme = GameLook.make_theme(presentation); overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT); root.add_child(overlay); overlay.size = Vector2(320,240); overlay.set_message("Disconnected")
		for frame in 4: await process_frame
		var overlay_surface: StyleBoxFlat = overlay.panel.get_theme_stylebox("panel")
		check(GameLook.text_contrast(overlay.heading.get_theme_color("font_color"), overlay_surface.bg_color) >= 4.5, "Canvas overlay captions stay readable on their actual surface in " + presentation)
		check(overlay.heading.text == "Disconnected" and overlay.get_global_rect().encloses(overlay.panel.get_global_rect()), "Canvas overlay fits its existing playfield in " + presentation)
		overlay.queue_free(); await process_frame
	var form_holder := Control.new(); root.add_child(form_holder); form_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var form_screen := GameScreen.new(); form_holder.add_child(form_screen); form_screen.configure("Shared settings"); form_screen.use_playful_style("", "modern-table")
	var settings_body: VBoxContainer = form_screen.add_corner_details(["SETTINGS"],Callable(),true,false,false,true,true)[0]
	var settings_form := form_screen.add_settings_form(settings_body)
	settings_form.compact = true
	var appearance := settings_form.add_section("Appearance"); var setting_theme := settings_form.add_choice(appearance,"Theme",["Default","A long custom theme label that must fit"])
	var existing_control := OptionButton.new(); existing_control.add_item("Original control")
	check(settings_form.add_control(appearance,"Existing selector",existing_control) == existing_control and settings_form.is_ancestor_of(existing_control), "Grouped settings mount an existing shared control without replacing it")
	var opponents := settings_form.add_section("Opponents"); var setting_difficulty := settings_form.add_choice(opponents,"Difficulty",["Easy","Medium","Hard"])
	var timing := settings_form.add_section("Timing"); var setting_timer := settings_form.add_toggle(timing,"Turn timer",true); var setting_time := settings_form.add_number(timing,"Turn time",.1,60,.1,5," min")
	check(settings_form.get_theme_constant("separation") == 8 and timing.get_theme_constant("separation") == 4, "Compact settings use closer shared spacing after mounting")
	var applied := [0]; var apply_settings := settings_form.add_action("Apply & New Game",func() -> void: applied[0]+=1)
	var edited := [0]; setting_theme.item_selected.connect(func(_index: int) -> void: edited[0]+=1); setting_timer.toggled.connect(func(_on: bool) -> void: edited[0]+=1); setting_time.value_changed.connect(func(_value: float) -> void: edited[0]+=1)
	setting_theme.select(1); setting_timer.set_pressed_no_signal(false); GameLook.settings_toggle(setting_timer,false); setting_time.set_value_no_signal(7.5)
	check(edited[0] == 0 and applied[0] == 0,"Restoring grouped preferences never emits edits or applies a new game")
	var settings_trigger: Button = settings_body.get_meta("toggle_button"); settings_trigger.button_pressed = true
	for dimensions in [Vector2i(1280,720),Vector2i(390,844),Vector2i(844,390)]:
		root.content_scale_size = dimensions; root.size = dimensions
		for unused in 15: await process_frame
		var sheet: PanelContainer = settings_body.get_meta("settings_panel"); var close_settings: Button = settings_body.get_meta("settings_close")
		var settings_heading: Label = settings_body.get_meta("settings_heading")
		check(settings_heading.text == "Game settings" and settings_heading.size.x>100 and settings_heading.size.y>=26 and settings_heading.is_visible_in_tree(),"Settings keep a visible, readable dialog title: %s %s" % [settings_heading.get_global_rect(),settings_heading.text])
		check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(sheet.get_global_rect()) and sheet.get_global_rect().encloses(apply_settings.get_global_rect()) and sheet.get_global_rect().encloses(close_settings.get_global_rect()),"Settings keep heading, Close and Apply inside the viewport at %s" % dimensions)
		check(absf(setting_theme.global_position.x-setting_difficulty.global_position.x)<1 and absf(setting_theme.size.x-setting_difficulty.size.x)<1 and absf(setting_time.global_position.x-setting_theme.global_position.x)<1,"Dropdowns and numeric fields share one aligned column")
		check(close_settings.size.y>=44 and apply_settings.size.y>=44 and setting_timer.size.y>=44,"Settings retain accessible control sizes")
		check(existing_control.size.y>=44 and absf(existing_control.size.x-setting_theme.size.x)<1 and absf(existing_control.global_position.x-setting_theme.global_position.x)<1 and existing_control.accessibility_name == "Existing selector", "Custom settings controls share field geometry and accessible labels at %s" % dimensions)
		if DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute("res://.test_data/table-inventory/"); await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://.test_data/table-inventory/settings-%dx%d.png" % [dimensions.x,dimensions.y])
		close_settings.grab_focus(); setting_time.get_line_edit().grab_focus(); for unused in 4: await process_frame
		var settings_scroll: ScrollContainer = settings_body.get_meta("settings_scroll")
		check(settings_scroll.get_global_rect().encloses(setting_time.get_global_rect()),"Keyboard focus scrolls the final field into view at %s" % dimensions)
	check(setting_time.get_line_edit().get_theme_stylebox("normal").bg_color == setting_theme.get_theme_stylebox("normal").bg_color,"Time inputs share the same matte surface as selectors")
	settings_body.get_meta("settings_close").pressed.emit(); check(not settings_body.get_meta("settings_panel").visible and setting_time.value == 7.5,"Closing settings keeps staged values without applying them")
	settings_trigger.button_pressed = true; for unused in 4: await process_frame
	apply_settings.pressed.emit(); check(applied[0] == 1,"Only explicit Apply invokes the supplied callback")
	form_holder.queue_free(); for unused in 4: await process_frame
	root.content_scale_size = Vector2i(640,480); root.size = Vector2i(640,480)
	var store := ProfileStore.new("res://.test_data/table-inventory/profiles.json"); store.load_data()
	var catalog := GameCatalog.new("res://tests/fixtures/Games"); catalog.scan()
	var server := LanServer.new(); root.add_child(server); server.configure(store,catalog)
	check(server.start_server(),"Synthetic LAN server starts")
	var http := HTTPRequest.new(); root.add_child(http)
	for path in ["table-crown.svg","table-crown-silver.svg","table-cash.svg","table-cards.svg","table-property.svg","table-house.svg"]:
		http.request("http://127.0.0.1:%d/ui/playful/%s" % [server.http_port,path]); var response: Array = await http.request_completed
		check(int(response[1]) == 200 and response[3].get_string_from_utf8().contains("<svg"),"Actual LAN route serves "+path)
	server.stop_server(); http.queue_free(); server.queue_free(); section.queue_free(); for unused in 3: await process_frame
	# A content-fitted dialog must reserve scrollbar width before a responsive
	# grid measures its height; otherwise its gutter can trigger a sizing loop.
	root.content_scale_size = Vector2i(1280,720); root.size = Vector2i(1280,720)
	var holder := Control.new(); root.add_child(holder); holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen := GameScreen.new(); holder.add_child(screen); screen.configure("Shared cards")
	var dialog := screen.add_phase_dialog(true,false,false,true,540); dialog.heading.text = "Symbol cards"
	var cards := GameCardGrid.new(); cards.fixed_columns = 5; cards.left_aligned = true; cards.preferred_width = 108; dialog.body.add_child(cards)
	var symbol := {"id":"symbol","layout":"symbol","name":"Choose <one>","detail":"Pick any two tokens.","foot":"Public reference","accent":"#397c91"}
	var entries: Array = []
	for index in 5: entries.append({"card":symbol.duplicate(),"texture":RuntimeAssets.scalable_texture("res://ui/playful/stat-resources.svg")})
	cards.set_items(entries); dialog.overlay.show()
	for unused in 20: await process_frame
	check(screen.content_scroll.get_v_scroll_bar().modulate.a == 0,"Modal dialogs hide board scroll chrome without changing its layout gutter")
	check(dialog.scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_RESERVE,"Fitted dialogs reserve their scroll gutter before card wrapping")
	check(cards.get_child(0).accessibility_name.contains("Pick any two tokens") and not cards.get_child(0).accessibility_name.contains("$0"),"Symbol cards expose literal instructions without monetary fields")
	var fitted: Rect2 = dialog.panel.get_global_rect()
	for unused in 8: await process_frame
	check(dialog.panel.get_global_rect() == fitted and cards.size.x <= dialog.scroll.size.x,"A narrow fitted dialog settles without a scrollbar/grid resize loop")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("res://.test_data/table-inventory")
		await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://.test_data/table-inventory/symbol-dialog.png")
	var hidden_symbol: Dictionary = symbol.duplicate(); hidden_symbol.back = true
	cards.set_items([{"card":hidden_symbol,"texture":entries[0].texture}]); check(cards.get_child(0).accessibility_name == "Card back","Symbol backs omit private names and rules from their accessible label")
	var chosen := {"id":"","index":-1,"toggled":false}
	cards.selectable = true
	cards.choice_selected.connect(func(id: String, index: int) -> void: chosen.id = id; chosen.index = index)
	cards.selection_changed.connect(func(_ids: Array) -> void: chosen.toggled = true)
	cards.set_items([{"card":symbol,"texture":entries[0].texture,"inline_choice":{"options":["First","Second"],"label":"Scenario choice"}}])
	for unused in 4: await process_frame
	var inline_choice: OptionButton = cards.get_child(0).get_node("InlineChoice")
	inline_choice.select(1); inline_choice.item_selected.emit(1)
	check(chosen.id == "symbol" and chosen.index == 1 and not chosen.toggled,"Changing an embedded option emits its card ID without toggling its card")
	check(inline_choice.size.y >= 43.9 and inline_choice.accessibility_name == "Scenario choice" and inline_choice.tooltip_text.is_empty(),"Embedded options retain a named 44px touch target")
	dialog.overlay.hide()
	check(screen.content_scroll.get_v_scroll_bar().modulate.a == 1,"Closing the last modal restores board scroll chrome")
	var track := GameProgressTrack.new(); holder.add_child(track); track.theme = screen.theme
	track.set_progress(20,7,4,6,"Public attack 4; public defense 6")
	check(track.progress == 7 and track.accessibility_name == "Public attack 4; public defense 6","Public progress is bounded and has explicit non-color meaning")
	var reference := GameCardReader.new(); reference.theme = screen.theme; holder.add_child(reference)
	var tall := Image.create(120,180,false,Image.FORMAT_RGBA8); tall.fill(Color("e8d6a7")); var front := ImageTexture.create_from_image(tall)
	var wide := Image.create(240,120,false,Image.FORMAT_RGBA8); wide.fill(Color("b8d6d7")); var back := ImageTexture.create_from_image(wide)
	reference.show_reference_library([{"label":"Collection <literal>","pages":[{"label":"First topic","front":front,"back":back,"description":"Accessible rules"},{"label":"Second topic","front":back,"back":front}]}],0,1)
	for viewport: Vector2i in [Vector2i(390,844),Vector2i(844,390)]:
		root.content_scale_size = viewport; root.size = viewport
		for unused in 12: await process_frame
		check(reference.reference_menu.visible and reference.reference_topic.selected == 1 and reference.reference_group.get_item_text(0) == "Collection <literal>","Reference library restores a literal collection and selected topic")
		check(reference.reference_group.size.y >= 43.9 and reference.stage.get_global_rect().encloses(reference.card.get_global_rect()),"Fitted reference selectors and card fit "+str(viewport))
		reference._flip()
		for unused in 6: await process_frame
		check(reference.stage.get_global_rect().encloses(reference.card.get_global_rect()),"Flipping between portrait and landscape references preserves fitting")
	var blocker := Control.new(); holder.add_child(blocker); blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	var gallery: Array = [{"id":"example","label":"Collection <literal>","pages":[{"id":"overview","label":"Overview","front":front,"back":back},{"id":"other","label":"Second topic","front":back,"back":front}]}]
	reference.show_reference_gallery(gallery,"Rules <literal>")
	for unused in 12: await process_frame
	check(reference.get_index() > blocker.get_index() and reference.gallery_showing and not reference.reference_menu.visible,"Gallery rises above a previously opened blocking overlay without reference dropdowns")
	check(reference.heading.text == "Rules <literal>" and reference.gallery_grid.get_child_count() == 2,"Gallery shows supplied reference cards and literal labels")
	await tap(reference.gallery_grid.get_child(1).get_global_rect().get_center())
	check(not reference.gallery_showing and reference.pages[0] == back,"Actual pointer input selects a card through the raised reader")
	await tap(reference.flip.get_global_rect().get_center())
	check(reference.page == 1,"Actual pointer input flips the enlarged reference")
	await tap(Vector2(4,4)); check(reference.visible and not reference.gallery_showing,"Back-only references ignore outside taps")
	var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true; Input.parse_input_event(escape); await process_frame
	check(reference.visible and not reference.gallery_showing,"Back-only references consume Escape without dismissing")
	await tap(reference.top_back.get_global_rect().get_center()); check(reference.visible and reference.gallery_showing,"Back returns from the enlarged card to all supplied cards")
	await tap(reference.top_back.get_global_rect().get_center()); check(not reference.visible,"Only the gallery Back button exits help")
	check(gallery.size() == 1,"Gallery navigation preserves the caller's reference collection")
	reference.show_reference_gallery(gallery+[{"label":"Other collection","pages":[{"label":"Another card","front":front,"back":back}]}],"Setup help",true,1)
	for unused in 12: await process_frame
	check(reference.gallery_tabs.visible and reference.gallery_grid.get_child_count() == 1,"Setup galleries restore a selected collection using compact buttons")
	await tap(reference.gallery_tabs.get_child(0).get_global_rect().get_center()); check(reference.gallery_grid.get_child_count() == 2,"Actual collection-button input shows all cards in that collection")
	await tap(Vector2(4,4)); check(reference.visible and reference.gallery_showing,"Background taps leave the gallery open too")
	# Readable inline galleries retain independent faces through layout changes.
	reference.show_reference_gallery(gallery,"Large rules",false,0,true)
	for unused in 12: await process_frame
	var inline_gallery: GameReferenceGallery = reference.reference_gallery
	var first: Control = inline_gallery.get_child(0)
	var second: Control = inline_gallery.get_child(1)
	check(inline_gallery.visible and not reference.gallery_grid.visible,"Inline help uses readable faces instead of selectable thumbnails")
	await tap(first.get_node("Flip").get_global_rect().get_center())
	check(first.get_meta("side") == "back" and second.get_meta("side") == "front","Each reference flips independently through actual pointer input")
	await tap(first.get_node("Face").get_global_rect().get_center())
	check(reference.gallery_showing and reference.pages.is_empty(),"Artwork taps never open an enlarged card in inline mode")
	for viewport: Vector2i in [Vector2i(390,844),Vector2i(844,390),Vector2i(1280,720)]:
		root.content_scale_size = viewport; root.size = viewport
		for unused in 12: await process_frame
		check(first.get_meta("side") == "back" and first.get_node("Face").texture == back,"Rotation preserves the flipped side")
		check(first.size.x >= minf(350,reference.stage.size.x-24),"Large reference faces retain readable widths")
		for tile: Control in inline_gallery.get_children():
			var button: Button = tile.get_node("Flip")
			check(button.size.y >= 44 and button.tooltip_text.is_empty(),"Independent flip controls retain named 44px targets without tooltips")
		reference.stage.scroll_vertical = int(second.position.y)
		for unused in 4: await process_frame
		check(reference.stage.get_global_rect().encloses(second.get_node("Flip").get_global_rect()),"Scrolling reaches later card actions on small screens %s stage=%s flip=%s scroll=%s" % [viewport,reference.stage.get_global_rect(),second.get_node("Flip").get_global_rect(),reference.stage.scroll_vertical])
	await tap(reference.top_back.get_global_rect().get_center()); check(not reference.visible,"Inline Back exits Help directly")
	reference.show_card(symbol,front,Color.WHITE)
	check(not reference.reference_menu.visible and reference.reference_library.is_empty(),"Ordinary card inspection clears the optional reference menu")
	check(not reference.reference_back_only and reference.gallery_groups.is_empty(),"Ordinary card inspection retains its original dismissal behavior")
	holder.queue_free(); for unused in 4: await process_frame
	print("Shared table inventory: %d checks, %d failures" % [checks,failures]); quit(0 if failures == 0 else 1)
