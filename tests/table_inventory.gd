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
	actions.queue_free(); underlying.queue_free()
	var store := ProfileStore.new("res://.test_data/table-inventory/profiles.json"); store.load_data()
	var catalog := GameCatalog.new("res://tests/fixtures/Games"); catalog.scan()
	var server := LanServer.new(); root.add_child(server); server.configure(store,catalog)
	check(server.start_server(),"Synthetic LAN server starts")
	var http := HTTPRequest.new(); root.add_child(http)
	for path in ["table-crown.svg","table-crown-silver.svg"]:
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
