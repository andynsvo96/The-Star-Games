extends SceneTree

# Synthetic shared UI coverage; no playable module dependency.
var checks := 0
var failures := 0
func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: "+message)
func _run() -> void:
	root.size = Vector2i(640,480)
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
