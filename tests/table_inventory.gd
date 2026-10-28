extends SceneTree

# Synthetic shared UI coverage; no playable module dependency.
var checks := 0
var failures := 0
func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: "+message)
func _run() -> void:
	root.min_size = Vector2i.ONE; root.content_scale_size = Vector2i(640,480); root.size = Vector2i(640,480)
	var section := GameSection.new(); section.caption = "Players"; root.add_child(section); section.size = Vector2(300,220)
	var inventory := GameResourceHand.new(); section.content.add_child(inventory)
	var items: Array = []
	for index in 5: items.append({"texture":RuntimeAssets.texture("res://ui/playful/stat-resources.svg"),"label":"Resource %d" % index,"amount":index,"color":Color("27ad68")})
	inventory.set_items(items); var amount := inventory.amounts[0]; items[0].amount = 3; inventory.set_items(items)
	check(inventory.amounts[0] == amount and amount.text == "3","Resource updates preserve the live count target")
	check(inventory.tooltip_text.is_empty() and inventory.accessibility_name.contains("Resource 0: 3"),"Icon-only inventory retains literal accessible quantities without hover text")
	check(section.heading.text == "Players" and section.get_theme_stylebox("panel").bg_color == GameLook.section_sheet().bg_color,"Sections use shared compact feed chrome")
	var costs := GameCostRow.new(); costs.icon_only = true; section.content.add_child(costs); costs.set_items([{"texture":items[0].texture,"label":"Resource","owned":1,"required":2,"available":false}])
	check(costs.find_children("*","Label",true,false).size() == 1 and costs.get_child(0).accessibility_name.contains("have 1, need 2"),"Icon-only costs omit prose while retaining accessible requirements")
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
	print("Shared table inventory: %d checks, %d failures" % [checks,failures]); quit(0 if failures == 0 else 1)
