extends SceneTree

var app: Control
var failures := 0
var checks := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)


func packet(socket: WebSocketPeer, type: String, private := false, minimum := 0) -> Dictionary:
	for frame in 700:
		socket.poll()
		while socket.get_available_packet_count() > 0:
			var value: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if not value is Dictionary or value.get("type") != type: continue
			if private and (value.get("payload", {}).get("type") != "state" or value.payload.get("viewer", -1) < 0 or int(value.payload.get("revision", -1)) < minimum): continue
			return value
		await process_frame
	return {}


func join_phone(name: String, token := "") -> Dictionary:
	var socket := WebSocketPeer.new(); socket.connect_to_url("ws://127.0.0.1:%d/" % app.lan_server.websocket_port)
	await packet(socket, "hello")
	socket.send_text(JSON.stringify({"type": "join", "name": name, "reconnect_token": token}))
	return {"socket": socket, "joined": await packet(socket, "joined")}


func send(phone: Dictionary, input: Dictionary) -> void:
	phone.socket.send_text(JSON.stringify({"type": "game", "game_id": "monopoly-classic", "payload": input}))


func request(path: String) -> Dictionary:
	var client := HTTPClient.new(); client.connect_to_host("127.0.0.1", app.lan_server.http_port)
	for frame in 700:
		client.poll()
		if client.get_status() == HTTPClient.STATUS_CONNECTED: break
		await process_frame
	client.request(HTTPClient.METHOD_GET, path, PackedStringArray())
	for frame in 700:
		client.poll()
		if client.has_response(): break
		await process_frame
	var result := {"status": client.get_response_code(), "headers": client.get_response_headers_as_dictionary(), "body": PackedByteArray()}
	for frame in 700:
		client.poll(); result.body.append_array(client.read_response_body_chunk())
		if client.get_status() != HTTPClient.STATUS_BODY: break
		await process_frame
	return result


func wait_disconnect(host, id: String, socket: WebSocketPeer) -> void:
	for frame in 300:
		socket.poll(); await process_frame
		if host.missing.has(id): return


func records() -> Array:
	return app.profile_store.get_profiles().map(func(profile: Dictionary) -> Dictionary: return {"id": profile.id, "wins": int(profile.get("wins", 0)), "losses": int(profile.get("losses", 0)), "points": app.profile_store.lifetime_points(profile)})


func _run() -> void:
	var folder := "res://.test_data/monopoly-classic-network-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://Main.tscn").instantiate(); app.profile_store = ProfileStore.new(folder + "/profiles.json"); app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new(); root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true; app._enter_lobby()
	var phones: Array = []
	for name in ["Alice", "Bob", "Charlie", "Dina", "Eli", "Fran"]: phones.append(await join_phone(name))
	check(phones.all(func(phone: Dictionary) -> bool: return not phone.joined.is_empty()), "Six phones join through the launcher")
	app._play_from_lobby(); app._launch_game(app.game_catalog.find_game("monopoly"))
	for phone in phones:
		var screen: Dictionary = await packet(phone.socket, "screen")
		check(screen.get("game_id") == "monopoly", "Every phone enters the shared Monopoly chooser route")
	check(app.active_game.choices.get_child(1).disabled, "Deal remains unavailable for six human players")
	app._on_collection_choice("monopoly-deal")
	check(app.active_game_id == "monopoly", "A forged six-player Deal launch is rejected outside its unchanged module")
	phones[5].socket.close(); await wait_disconnect(app.active_game, str(phones[5].joined.player.id), phones[5].socket)
	check(app.active_game.choices.get_children().all(func(button: Button) -> bool: return button.disabled), "Chooser waits for a disconnected admitted player")
	app._on_collection_choice("monopoly-classic")
	check(app.active_game_id == "monopoly", "Variant cannot launch with an incomplete locked party")
	phones[5] = await join_phone("Fran", str(phones[5].joined.reconnect_token))
	check(not app.active_game.choices.get_child(0).disabled and app.active_game.choices.get_child(1).disabled, "Reconnection restores choices using the original six-player limits")
	app._on_collection_choice("monopoly-classic")
	var host = app.active_game; host.saved_game.path = folder + "/session.json"; host._new_round(false); host.set_process(false)
	host.rules.s.turn = 0; host.rules.s.phase = "buy"; host.rules.s.positions[0] = 1; host.rules.s.buy_id = 1; host.rules.s.revision += 1; host._publish()
	var first: Dictionary = (await packet(phones[0].socket, "game", true, int(host.rules.s.revision))).payload
	var second: Dictionary = (await packet(phones[1].socket, "game", true, int(host.rules.s.revision))).payload
	check(not host.host_plays and first.viewer == 0 and second.viewer == 1 and first.players.size() == 6, "Six-player host is public and phone decisions are seat-specific")
	check(not first.has("board") and not first.has("decks") and not first.has("rng_state") and not JSON.stringify(first).contains("reconnect_token") and not first.players[0].has("id"), "Wire snapshots omit board, deck order, random state and identity secrets")
	send(phones[0], {"action": "buy", "revision": first.revision})
	first = (await packet(phones[0].socket, "game", true, int(first.revision) + 1)).payload
	check(host.rules.s.owners[1] == 0 and host.rules.s.cash[0] == 1440 and first.actions.any(func(choice: Dictionary) -> bool: return choice.payload.action == "mortgage"), "JSON-decoded purchase reaches authoritative ownership and cash")
	var revision := int(host.rules.s.revision)
	send(phones[0], {"action": "buy", "revision": revision - 1}); send(phones[1], {"action": "mortgage", "property": 1, "revision": revision})
	for frame in 10: await process_frame
	check(int(host.rules.s.revision) == revision and not host.rules.s.mortgaged[1], "Duplicate purchase and another player's mortgage are rejected")
	host.rules.s.owners[5] = 1; host.rules.s.revision += 1; host._publish()
	send(phones[0], {"action": "offer_trade", "revision": host.rules.s.revision, "to": 1, "give_cash": 25, "take_cash": 0, "give_properties": [1], "take_properties": [5], "give_jail": [], "take_jail": []})
	second = (await packet(phones[1].socket, "game", true, int(host.rules.s.revision) + 1)).payload
	var third: Dictionary = (await packet(phones[2].socket, "game", true, int(host.rules.s.revision))).payload
	check(second.phase == "trade" and second.trade.give_properties == [1.0] and second.trade.take_properties == [5.0] and not third.trade.has("give_properties"), "Only the two trade participants receive the pending offer")
	host.options.turn_timer = false
	var ticket := int(second.trade.ticket); phones[1].socket.close(); await wait_disconnect(host, str(phones[1].joined.player.id), phones[1].socket)
	var time_before: float = host.response_remaining; host._step(20)
	check(host._paused() and host.response_remaining == time_before and host.rules.s.phase == "trade", "Disconnect preserves the exact pending trade and clock")
	phones[1] = await join_phone("Bob", str(phones[1].joined.reconnect_token))
	second = (await packet(phones[1].socket, "game", true, int(host.rules.s.revision))).payload
	check(not second.paused and int(second.trade.ticket) == ticket and second.viewer == 1, "Refresh restores the same identity and pending trade ticket")
	send(phones[1], {"action": "accept_trade", "revision": second.revision})
	first = (await packet(phones[0].socket, "game", true, int(second.revision) + 1)).payload
	check(host.rules.s.owners[1] == 1 and host.rules.s.owners[5] == 0 and host.rules.s.cash[0] == 1415 and host.rules.s.cash[1] == 1525, "Reconnected recipient explicitly commits the offered exchange once")
	var untouched := records()
	phones[2].socket.close(); await wait_disconnect(host, str(phones[2].joined.player.id), phones[2].socket)
	host.options.turn_timer = false; host._step(100)
	check(host._paused() and not host.practice, "Continue setting waits for reconnection when turn timer is off")
	host.options.turn_timer = true; host.rules.s.turn = 2; host.rules.s.phase = "roll"; host.turn_remaining = .01; host._step(.02); host._step(.5)
	check(host.practice and host.saved_game.was_practice(host.round_id), "Disconnected timeout persists the irreversible practice flag")
	phones[2] = await join_phone("Charlie", str(phones[2].joined.reconnect_token))
	await packet(phones[2].socket, "game", true, int(host.rules.s.revision))
	host.rules.finish("time"); host._record_results()
	check(records() == untouched, "Actual profile files record no win, loss or point after any AI use")
	host._new_round(true); host.set_process(false); host.rules.s.owners[39] = 0; host.rules.finish("time"); host._record_results(); host._record_results()
	var recorded := records(); var wins := 0; var losses := 0; var points := 0
	for item in recorded: wins += int(item.wins); losses += int(item.losses); points += int(item.points)
	check(wins == 1 and losses == 5 and points == 1 and app.profile_store.get_profile(str(phones[0].joined.player.id)).wins == 1, "Fresh all-human game records exactly one winner, five losses and one point")
	for path in ["/game/monopoly/", "/game/monopoly-classic/", "/game/monopoly-classic/controller.js", "/game/monopoly-classic/art/boardwalk.svg", "/game/monopoly-deal/", "/card-ui.js", "/controller-sdk.js"]:
		check((await request(path)).status == 200, "Offline route exists: " + path)
	for path in ["/game/monopoly-classic/art/space-chest.svg", "/game/monopoly-classic/art/space-jail.svg", "/ui/playful/table-cash.svg", "/game/monopoly-classic/audio/card-draw.ogg", "/game/monopoly-classic/audio/chest.wav", "/game/monopoly-classic/audio/roll.wav", "/game/monopoly-classic/audio/jail.wav"]:
		check((await request(path)).status == 200, "Public effect artwork/audio is available offline: " + path)
	var page: String = (await request("/game/monopoly-classic/")).body.get_string_from_utf8()
	check(not page.contains("id=\"board\"") and not page.contains("https://"), "Real phone HTML contains no board and no remote dependencies")
	var manager := ThemePacks.new("monopoly-classic"); RuntimeAssets.root_override = ProjectSettings.globalize_path(folder); RuntimeAssets.refresh()
	var created := manager.duplicate_pack("default", "Classic QA"); var pack: Dictionary = created.pack
	pack.labels["mediterranean-avenue"] = "Atlantic House"
	var image := Image.create(48, 32, false, Image.FORMAT_RGBA8); image.fill(Color.BLUE); image.save_png(folder + "/art.png")
	check(manager.stage_media(pack, "mediterranean-avenue", folder + "/art.png").ok and manager.stage_media(pack, "table", folder + "/art.png").ok and manager.save_pack(pack).ok, "Classic theme independently saves cosmetic deed and background media")
	host.options.theme = "classic-qa"; host._pin_theme()
	var response := await request("/game/monopoly-classic/art/mediterranean-avenue.svg")
	check(response.status == 200 and response.headers.get("Content-Type", "").contains("image/png") and response.body == FileAccess.get_file_as_bytes(folder + "/art.png"), "Canonical deed route delivers selected skin bytes and their actual MIME type")
	var metadata: Dictionary = JSON.parse_string((await request("/game/monopoly-classic/background.json")).body.get_string_from_utf8())
	check(str(metadata.image).contains("/themes/classic-qa/media/"), "Shared extensionless background metadata follows Classic's skin")
	check((await request(str(metadata.image))).body == FileAccess.get_file_as_bytes(folder + "/art.png"), "Selected skin background is served offline")
	check(host.property_name(1) == "Atlantic House" and host.rules.properties[1].name == "Mediterranean Avenue" and host.rules.properties[1].price == 60, "Custom skin names and art never change canonical game rules")
	phones[5].socket.close(); await wait_disconnect(host, str(phones[5].joined.player.id), phones[5].socket)
	app._return_from_game(); check(app.active_game_id == "monopoly" and app.lan_server.running and not ThemePacks.active.has("monopoly-classic"), "Exit clears Classic's theme and returns to chooser without stopping the server")
	check(app.active_game.session.players.size() == 6 and not app.active_game.missing.is_empty() and app.active_game.choices.get_child(0).disabled, "Returning to chooser preserves offline members of the original party")
	phones[5] = await join_phone("Fran", str(phones[5].joined.reconnect_token))
	check(app.active_game.missing.is_empty() and not app.active_game.choices.get_child(0).disabled, "Returning party reconnects without losing seats")
	app._return_from_game(); check(app.current_state == "game_menu" and app.active_game == null, "Chooser Back returns to game selection")
	for phone in phones: phone.socket.close()
	app.lan_server.stop_server(); app.queue_free(); await process_frame
	RuntimeAssets.root_override = ""; RuntimeAssets.refresh()
	await create_timer(.2).timeout
	print("Monopoly Classic network: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
