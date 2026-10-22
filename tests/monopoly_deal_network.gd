extends SceneTree
var app: Control
var failures := 0
var checks := 0

func _init() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)

func packet(socket: WebSocketPeer, type: String, private := false, minimum := -1) -> Dictionary:
	for frame in 600:
		socket.poll()
		while socket.get_available_packet_count() > 0:
			var value: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if value is Dictionary and value.get("type") == type and (not private or value.get("payload",{}).get("viewer",-1) >= 0) and value.get("payload",{}).get("revision",-1) >= minimum: return value
		await process_frame
	return {}

func join_phone(name: String, token := "") -> Dictionary:
	var socket := WebSocketPeer.new(); socket.inbound_buffer_size = 8 * 1024 * 1024; socket.connect_to_url("ws://127.0.0.1:%d/" % app.lan_server.websocket_port); await packet(socket,"hello")
	socket.send_text(JSON.stringify({"type":"join","name":name,"reconnect_token":token}))
	return {"socket":socket,"joined":await packet(socket,"joined")}

func send(phone: Dictionary, input: Dictionary) -> void:
	phone.socket.send_text(JSON.stringify({"type":"game","game_id":"monopoly-deal","payload":input}))

func request(path: String) -> Dictionary:
	var client := HTTPClient.new(); client.connect_to_host("127.0.0.1",app.lan_server.http_port)
	for frame in 600:
		client.poll()
		if client.get_status() == HTTPClient.STATUS_CONNECTED: break
		await process_frame
	client.request(HTTPClient.METHOD_GET,path,PackedStringArray())
	for frame in 600:
		client.poll()
		if client.has_response(): break
		await process_frame
	var result := {"status":client.get_response_code(),"headers":client.get_response_headers_as_dictionary(),"body":PackedByteArray()}
	for frame in 600:
		client.poll(); result.body.append_array(client.read_response_body_chunk())
		if client.get_status() != HTTPClient.STATUS_BODY: break
		await process_frame
	return result

func _run() -> void:
	seed(47047)
	var folder := "res://.test_data/monopoly-network-%d" % Time.get_ticks_usec(); DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://Main.tscn").instantiate(); app.profile_store = ProfileStore.new(folder+"/profiles.json"); app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new(); root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true; app._enter_lobby()
	var first := await join_phone("Alex"); var second := await join_phone("Nina"); var third := await join_phone("Sam"); check(not first.joined.is_empty() and not second.joined.is_empty() and not third.joined.is_empty(),"Three real controllers join through the launcher")
	app._play_from_lobby(); var module: Dictionary = app.game_catalog.games.filter(func(game: Dictionary) -> bool: return game.id == "monopoly-deal")[0]
	check(app._can_launch(module),"Catalog admits a two-phone Monopoly Deal session"); app._launch_game(module); await process_frame
	var host = app.active_game; var one: Dictionary = (await packet(first.socket,"game",true)).payload; var two: Dictionary = (await packet(second.socket,"game",true)).payload
	check(not host.host_plays and one.hand.size() == 7 and two.hand.size() == 5 and host._snapshot(-1).hand.is_empty(),"Host stays public and each socket receives its own private hand")
	check(not JSON.stringify(one).contains("reconnect_token") and not one.has("deck") and not one.has("hands"),"Raw game packets omit secrets, other hands and stock order")
	var offered: Dictionary = one.actions.filter(func(choice: Dictionary) -> bool: return choice.payload.action == "bank")[0].payload.duplicate(true); offered.revision = one.revision
	check(one.clock.seconds == 60 and one.clock.running, "Real private packets include the authoritative default turn clock")
	host.settings_button.button_pressed = true
	var paused: Dictionary = (await packet(first.socket,"game",true)).payload
	check(paused.paused and not paused.clock.running and paused.pause_reason == "Host Settings is open", "Host Settings publishes paused game and clock state to real phones")
	send(first, offered)
	for frame in 5: await process_frame
	check(host.rules.revision == int(one.revision) and host.rules.banks[0].is_empty(), "Phone commands cannot mutate the table behind host Settings")
	host.settings_button.button_pressed = false; one = (await packet(first.socket,"game",true)).payload
	send(first,offered); one = (await packet(first.socket,"game",true,int(one.revision)+1)).payload
	check(one.table[0].bank.size() == 1 and one.hand.size() == 6,"JSON-decoded owned card and revision are accepted over real sockets")
	check(one.activity_entries[0].text.begins_with("Alex banked $") and one.activity[0].kind == "bank", "Real snapshots restore the accepted public activity with the player's name")
	var accepted := int(one.revision); send(first,offered)
	for frame in 10: await process_frame
	check(host.rules.revision == accepted,"Duplicate stale network actions cannot apply twice")
	host.animating = true; send(first,{"action":"end","revision":accepted})
	for frame in 10: await process_frame
	check(host.rules.turn == 0 and host.rules.revision == accepted,"Input received during movement is discarded")
	host.animating = false
	var debt: Dictionary = host.rules.cards.filter(func(card: Dictionary) -> bool: return card.kind == "debt-collector")[0]
	var refusal: Dictionary = host.rules.cards.filter(func(card: Dictionary) -> bool: return card.kind == "just-say-no")[0]
	for hand in host.rules.hands: hand.erase(int(refusal.id))
	host.rules.deck.erase(int(refusal.id)); host.rules.discard.erase(int(refusal.id)); host.rules.hands[1].append(int(refusal.id))
	for hand in host.rules.hands: hand.erase(int(debt.id))
	var eligible_payment: int = host.rules.deck.filter(func(id: int) -> bool: return host.rules.cards[id].kind == "money" and host.rules.cards[id].value == 1)[0]
	host.rules.deck.erase(eligible_payment); host.rules.banks[1].append(eligible_payment)
	host.rules.deck.erase(int(debt.id)); host.rules.discard.erase(int(debt.id)); host.rules.hands[0].append(int(debt.id)); host.rules.revision += 1; host._publish()
	send(first,{"action":"debt","card":debt.id,"target":1,"revision":host.rules.revision}); two = (await packet(second.socket,"game",true,host.rules.revision+1)).payload
	check(two.phase == "response" and two.pending.ask == 1,"Target receives its focused response choice")
	check(two.pending.card.key == "debt-collector" and two.pending.target == 1 and two.pending.actor == 0, "Real response packets identify the played card, actor and chosen target")
	var hand_before: Array = host.rules.hands[1].duplicate(); second.socket.close()
	for frame in 180:
		second.socket.poll(); await process_frame
		if not host.missing.is_empty(): break
	check(not host.missing.is_empty() and not host._action(1,{"action":"accept","revision":host.rules.revision}),"Disconnect freezes the same pending action")
	var refreshed := await join_phone("Nina",second.joined.reconnect_token); var restored: Dictionary = (await packet(refreshed.socket,"game",true)).payload
	check(refreshed.joined.player.id == second.joined.player.id and restored.phase == "response" and restored.hand.map(func(card: Dictionary) -> int: return int(card.id)) == hand_before and not restored.paused,"Refresh restores identity, exact hand and pending choice")
	check(restored.clock.key == one.clock.key and restored.clock.remaining <= one.clock.remaining and not restored.clock.running, "Refresh restores remaining turn time paused for the other player's response")
	var payment_card: int = host.rules.deck.filter(func(id: int) -> bool: return host.rules.cards[id].kind == "money" and host.rules.cards[id].value >= 5)[0]
	host.rules.deck.erase(payment_card); host.rules.banks[1].append(payment_card); host.rules.revision += 1; host._publish()
	send(refreshed, {"action":"accept", "revision":host.rules.revision})
	var payment_view: Dictionary = (await packet(refreshed.socket, "game", true, host.rules.revision + 1)).payload
	check(payment_view.phase == "pay" and payment_view.pending.card.key == "debt-collector" and payment_view.payment.assets.any(func(value: Variant) -> bool: return int(value) == payment_card), "Real phones receive applicable asset choices and the original card context together")
	refreshed.socket.close()
	for frame in 180:
		refreshed.socket.poll(); await process_frame
		if not host.missing.is_empty(): break
	refreshed = await join_phone("Nina", second.joined.reconnect_token)
	var payment_restored: Dictionary = (await packet(refreshed.socket, "game", true)).payload
	check(payment_restored.phase == "pay" and payment_restored.pending.card.key == "debt-collector" and payment_restored.pending.target == 1 and payment_restored.payment == payment_view.payment, "Refresh during payment restores the exact applicable choices, played card and chosen recipient")
	# Both phones submit from the same snapshot, including after a reconnect.
	host.rules.start(3)
	for seat in 3:
		host.rules.hands[seat].clear(); host.rules.banks[seat].clear(); host.rules.properties[seat].clear(); host.rules.loose[seat].clear()
	host.rules.deck = range(host.rules.cards.size()); host.rules.discard.clear()
	var birthday: int = host.rules.cards.filter(func(card: Dictionary) -> bool: return card.key == "birthday")[0].id
	var cash_one: int = host.rules.cards.filter(func(card: Dictionary) -> bool: return card.key == "money-10")[0].id
	var cash_two: int = host.rules.cards.filter(func(card: Dictionary) -> bool: return card.key == "money-2")[0].id
	for id in [birthday, cash_one, cash_two]: host.rules.deck.erase(id)
	host.rules.hands[0].append(birthday); host.rules.banks[1].append(cash_one); host.rules.banks[2].append(cash_two); host._publish()
	var revision: int = host.rules.revision
	send(first, {"action":"birthday", "card":birthday, "revision":revision})
	var pay_one: Dictionary = (await packet(refreshed.socket, "game", true, revision + 1)).payload
	var pay_two: Dictionary = (await packet(third.socket, "game", true, revision + 1)).payload
	check(pay_one.phase == "pay" and pay_two.phase == "pay" and int(pay_one.revision) == int(pay_two.revision), "All affected sockets receive payment choices together")
	check(pay_one.pending.target == 1 and pay_two.pending.target == 2 and pay_one.payment.assets == [float(cash_one)] and pay_two.payment.assets == [float(cash_two)], "Simultaneous private choices contain only each owner's payable assets")
	third.socket.close()
	for frame in 180:
		third.socket.poll(); await process_frame
		if not host.missing.is_empty(): break
	var third_restored := await join_phone("Sam", third.joined.reconnect_token)
	var pay_restored: Dictionary = (await packet(third_restored.socket, "game", true, revision + 1)).payload
	check(pay_restored.pending.effect == pay_two.pending.effect and pay_restored.payment == pay_two.payment and not pay_restored.paused, "Reconnect restores an independent outstanding payment ticket")
	var command_one: Dictionary = pay_one.payment.command.duplicate(true); command_one.cards = [cash_one]; command_one.revision = pay_one.revision
	var command_two: Dictionary = pay_two.payment.command.duplicate(true); command_two.cards = [cash_two]; command_two.revision = pay_two.revision
	send(third_restored, command_two); send(refreshed, command_one)
	var paid: Dictionary = (await packet(first.socket, "game", true, int(pay_one.revision) + 2)).payload
	check(paid.phase == "play" and host.rules.banks[0].has(cash_one) and host.rules.banks[0].has(cash_two), "Racing same-revision wire payments both settle without retry")
	revision = host.rules.revision; send(refreshed, command_one)
	for frame in 10: await process_frame
	check(host.rules.revision == revision and host.rules.banks[0].size() == 2, "A repeated wire payment cannot pay twice")
	# Forced Deal enumerates give/take combinations. A real late-game private
	# snapshot is substantially larger than WebSocketPeer's default 64 KiB.
	host.rules.start(3)
	for seat in 3:
		host.rules.hands[seat].clear(); host.rules.banks[seat].clear(); host.rules.properties[seat].clear(); host.rules.loose[seat].clear()
	host.rules.deck = range(host.rules.cards.size()); host.rules.discard.clear()
	var forced: int = host.rules.cards.filter(func(card: Dictionary) -> bool: return card.kind == "forced-deal")[0].id
	host.rules.deck.erase(forced); host.rules.hands[0].append(forced)
	var placed := 0
	for card: Dictionary in host.rules.cards:
		if card.kind != "property": continue
		host.rules.deck.erase(card.id); host.rules._put_property(placed % 3, int(card.id), card.colors[0]); placed += 1
	var rich: Dictionary = host._snapshot(0)
	check(JSON.stringify(rich).to_utf8_buffer().size() > 65535, "The reconnect regression uses an actual oversized private choice snapshot")
	host._publish()
	var rich_wire := await packet(first.socket, "game", true, int(rich.revision))
	check(not rich_wire.is_empty() and rich_wire.payload.actions.size() == rich.actions.size(), "Large private choices arrive intact over the real LAN socket")
	first.socket.close()
	for frame in 180:
		first.socket.poll(); await process_frame
		if not host.missing.is_empty(): break
	first = await join_phone("Alex", first.joined.reconnect_token)
	var rich_restored := await packet(first.socket, "game", true, int(rich.revision))
	check(not rich_restored.is_empty() and rich_restored.payload.hand.size() == 1 and rich_restored.payload.hand[0].key == "forced-deal" and rich_restored.payload.actions.size() == rich.actions.size() and not rich_restored.payload.paused, "Reconnect restores the complete large private hand/choice view instead of an empty table")
	var manager := ThemePacks.new("monopoly-deal"); RuntimeAssets.root_override = ProjectSettings.globalize_path(folder); RuntimeAssets.refresh()
	var created := manager.duplicate_pack("default","Philly QA"); var pack: Dictionary = created.pack; pack.labels.boardwalk = "City Hall"
	var image := Image.create(48,32,false,Image.FORMAT_RGBA8); image.fill(Color.BLUE); image.save_png(folder+"/art.png")
	manager.stage_media(pack,"boardwalk",folder+"/art.png"); manager.stage_media(pack,"background",folder+"/art.png"); check(manager.save_pack(pack).ok,"Theme fixture commits names, card artwork and background together")
	host.skin = manager.pin("philly-qa"); host._publish()
	var response := await request("/game/monopoly-deal/art/boardwalk.svg")
	check(response.status == 200 and response.headers.get("Content-Type","") == "image/png" and response.body == FileAccess.get_file_as_bytes(folder+"/art.png"),"Original card URL serves selected skin bytes and actual MIME type")
	response = await request("/game/monopoly-deal/background.json"); var background: Dictionary = JSON.parse_string(response.body.get_string_from_utf8())
	check(str(background.image).contains("/themes/philly-qa/media/"),"Shared background metadata follows the selected theme")
	response = await request(str(background.image)); check(response.status == 200 and response.body == FileAccess.get_file_as_bytes(folder+"/art.png"),"Theme background URL is reachable through the real offline server")
	response = await request("/card-ui.js"); check(response.status == 200,"Shared card component has a real LAN route")
	for icon in ["cash", "cards", "house"]:
		response = await request("/ui/playful/table-%s.svg" % icon)
		check(response.status == 200 and response.headers.get("Content-Type", "").contains("image/svg+xml"), "Shared %s icon is available through the real offline server" % icon)
	for cue in ["cash-register", "stop-buzzer"]:
		response = await request("/game/monopoly-deal/audio/%s.wav" % cue)
		check(response.status == 200 and response.body.slice(0, 4).get_string_from_ascii() == "RIFF", "Original %s audio remains available offline" % cue)
	app._return_from_game(); check(app.active_game == null and app.current_state == "game_menu" and app.lan_server.running and not ThemePacks.active.has("monopoly-deal"),"Return cleans up game/theme state and preserves the launcher LAN session")
	first.socket.close(); refreshed.socket.close(); third_restored.socket.close(); app.lan_server.stop_server(); app.queue_free(); await process_frame
	RuntimeAssets.root_override = ""; RuntimeAssets.refresh(); await create_timer(0.15).timeout; print("Monopoly Deal network: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
