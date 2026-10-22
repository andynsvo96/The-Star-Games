extends SceneTree

var app: Control
var checks := 0
var failures := 0
var folder := "res://.test_data/poker-network-%d/" % Time.get_ticks_usec()


func _init() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)


func packet(socket: WebSocketPeer, type: String, minimum := -1) -> Dictionary:
	for frame in 600:
		socket.poll()
		while socket.get_available_packet_count() > 0:
			var data: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if data is Dictionary and data.get("type") == type and (type != "game" or int(data.get("payload", {}).get("revision", -1)) >= minimum): return data
		await process_frame
	return {}


func join_phone(name: String, token := "") -> Dictionary:
	var socket := WebSocketPeer.new(); socket.connect_to_url("ws://127.0.0.1:%d/" % app.lan_server.websocket_port); await packet(socket, "hello")
	socket.send_text(JSON.stringify({"type": "join", "name": name, "reconnect_token": token}))
	return {"socket": socket, "joined": await packet(socket, "joined")}


func send(phone: Dictionary, command: Dictionary) -> void:
	phone.socket.send_text(JSON.stringify({"type": "game", "game_id": app.active_game_id, "payload": command}))


func request(path: String) -> Dictionary:
	var client := HTTPClient.new(); client.connect_to_host("127.0.0.1", app.lan_server.http_port)
	for frame in 600:
		client.poll()
		if client.get_status() == HTTPClient.STATUS_CONNECTED: break
		await process_frame
	client.request(HTTPClient.METHOD_GET, path, PackedStringArray())
	for frame in 600:
		client.poll()
		if client.has_response(): break
		await process_frame
	var result := {"status": client.get_response_code(), "headers": client.get_response_headers_as_dictionary(), "body": PackedByteArray()}
	for frame in 600:
		client.poll(); result.body.append_array(client.read_response_body_chunk())
		if client.get_status() != HTTPClient.STATUS_BODY: break
		await process_frame
	return result


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://Main.tscn").instantiate(); app.profile_store = ProfileStore.new(folder + "profiles.json"); app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new(); root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true; app._enter_lobby()
	app.screen_root.child_entered_tree.connect(func(node: Node) -> void:
		if node is BaseGame and node.has_method("resume_game"): node.saved_game.path = folder + str(app.active_game_id) + "/session.json")
	var phones: Array = []
	for index in 10: phones.append(await join_phone("Poker Player %d" % index))
	check(phones.all(func(phone: Dictionary) -> bool: return not phone.joined.is_empty()), "Ten real LAN phones join")
	app._play_from_lobby(); var collection: Dictionary = app.game_catalog.find_game("poker")
	check(app._can_launch(collection) and not app._can_launch_for_count(collection, 11), "Catalog admits ten and rejects eleven humans")
	app._launch_game(collection); await process_frame
	check(app.active_game_id == "poker" and app.active_game.choices.get_child_count() == 2, "Launcher opens the two-mode Poker chooser")
	app.active_game.game_selected.emit("poker-texas-holdem"); await process_frame
	var host = app.active_game; host.set_process(false)
	check(app.active_game_id == "poker-texas-holdem" and host.seats.size() == 10 and not host.host_plays, "Chooser launches Texas with the admitted ten-player party")
	var initial: Dictionary = (await packet(phones[0].socket, "game")).get("payload", {})
	check(initial.get("hand", []).size() == 2 and initial.get("viewer") == 0, "Actual Texas socket receives only its own two cards")
	check(not initial.has("deck") and not JSON.stringify(initial).contains("reconnect_token") and initial.players.all(func(player: Dictionary) -> bool: return player.hand.is_empty()), "Raw packets omit every other hand, deck and identity secret")
	var revision: int = host.rules.revision; var active: int = host.rules.turn
	send(phones[active], {"action": "call", "revision": revision})
	var changed: Dictionary = (await packet(phones[active].socket, "game", revision + 1)).get("payload", {})
	check(changed.get("revision", -1) == revision + 1, "Host accepts JSON-normalized action from the current phone")
	send(phones[active], {"action": "call", "revision": revision})
	for frame in 8: await process_frame
	check(host.rules.revision == revision + 1, "Stale duplicate socket input cannot apply twice")
	host.ui.open_settings(); var remaining: float = host.turn_remaining
	send(phones[host.rules.turn], {"action": "fold", "revision": host.rules.revision})
	for frame in 8: await process_frame
	check(host.rules.revision == revision + 1 and host.turn_remaining == remaining and host._snapshot(0).paused, "Host Settings pause and reject actual network actions")
	host.ui.close_settings()
	var own_hand: Array = host.rules.players[1].hand.duplicate(); phones[1].socket.close()
	for frame in 180:
		phones[1].socket.poll(); await process_frame
		if not host.missing.is_empty(): break
	check(host.paused(), "A disconnected seated phone pauses play")
	var restored := await join_phone("Poker Player 1", phones[1].joined.reconnect_token); phones[1] = restored
	var refreshed: Dictionary = (await packet(restored.socket, "game")).get("payload", {})
	check(refreshed.get("hand", []).map(func(value: Variant) -> int: return int(value)) == own_hand and not refreshed.get("paused", true) and restored.joined.player.id == host.seats[1].id, "Refresh restores identity, exact private hand and paused clock")
	for path in ["/game/poker/art/table.png", "/game/poker/art/chip.svg", "/game/poker/art/title.svg", "/game/poker/controller/controller.js", "/game/poker/controller/style.css", "/game/poker-texas-holdem/", "/game/poker-omaha/", "/card-ui.js", "/styles.css", "/ui/playful/table-cards.svg", "/ui/playful/control-history.svg", "/ui/playful/control-settings.svg", "/ui/playful/casino-frame.svg", "/ui/playful/casino-frame-active.svg", "/ui/playful/casino-button-fold.svg", "/ui/playful/casino-button-call.svg", "/ui/playful/casino-button-raise.svg", "/ui/playful/casino-button-neutral.svg", "/ui/playful/casino-slider-track.svg", "/ui/playful/casino-slider-fill.svg", "/ui/playful/casino-slider-knob.svg", "/ui/playful/casino-slider-knob-disabled.svg"]:
		var response := await request(path); check(response.status == 200 and response.body.size() > 100, "Offline HTTP asset route " + path)
	for filename in ["casino-player.svg", "casino-player-active.svg"]:
		var response := await request("/ui/playful/" + filename)
		check(response.status == 200 and response.body.size() > 100, "Player plaque art uses the real offline LAN route " + filename)
	var background := await request("/game/poker-texas-holdem/background.json")
	var metadata: Variant = JSON.parse_string(background.body.get_string_from_utf8())
	check(background.status == 200 and metadata is Dictionary and str(metadata.get("image", "")).contains("art/lounge.png"), "Extensionless background metadata resolves the bundled original")
	var folded: int = host.rules.turn
	host._action(folded, {"action": "fold", "revision": host.rules.revision})
	for step in 1000:
		if host.rules.phase in ["hand_over", "finished"]: break
		if host.rules.phase == "runout":
			var exposed: Dictionary = (await packet(phones[0].socket, "game", host.rules.revision)).get("payload", {})
			check(exposed.get("players", []).size() == 10 and exposed.players[folded].hand.is_empty() and range(10).all(func(seat: int) -> bool: return seat == folded or exposed.players[seat].hand.size() == 2), "Actual all-in packets reveal contenders and keep the folded hand private before runout completes")
			host._process(2)
		else:
			var legal: Dictionary = host.rules.legal(host.rules.turn)
			host._action(host.rules.turn, {"action": "raise" if legal.can_raise else "check" if legal.check else "call", "amount": legal.max_raise_to, "revision": host.rules.revision})
	var complete: Dictionary = (await packet(phones[0].socket, "game", host.rules.revision)).get("payload", {})
	check(complete.get("hand_results", []).size() == 10 and complete.get("phase_remaining", 0) == 12, "Actual LAN results restore every ranked seat and the twelve-second review")
	check(complete.hand_results.filter(func(entry: Dictionary) -> bool: return int(entry.seat) == folded).all(func(entry: Dictionary) -> bool: return entry.cards.is_empty() and entry.category == "Folded"), "Actual ranked packets keep folded cards private")
	var survivor: int = range(10).filter(func(seat: int) -> bool: return not host.rules.players[seat].out)[0]
	host._process(4); phones[survivor].socket.close()
	for frame in 180:
		phones[survivor].socket.poll(); await process_frame
		if host.paused(): break
	var review_remaining: float = host.phase_remaining; host._process(20)
	check(host.paused() and host.phase_remaining == review_remaining, "Human socket loss freezes the result review")
	check(not host.continue_review() and host.phase_remaining == review_remaining, "Host Continue also waits for an active human's reconnection")
	phones[survivor] = await join_phone("Poker Player %d" % survivor, phones[survivor].joined.reconnect_token)
	var reviewed: Dictionary = (await packet(phones[survivor].socket, "game", host.rules.revision)).get("payload", {})
	check(reviewed.get("hand_results", []) == complete.hand_results and reviewed.get("phase_remaining", 0) == review_remaining and not reviewed.get("paused", true), "Reconnect restores ranked results and the remaining review without restarting it")
	host.return_to_lobby(); await process_frame
	check(app.active_game_id == "poker" and app.collection_roster.size() == 10, "Returning from Texas reopens Poker and retains the party")
	phones[2].socket.close()
	for frame in 180:
		phones[2].socket.poll(); await process_frame
		if not app.active_game.missing.is_empty(): break
	check(app.active_game.choices.get_children().all(func(button: Button) -> bool: return button.disabled), "Chooser requires offline party members to reconnect")
	app.active_game.game_selected.emit("poker-omaha"); await process_frame
	check(app.active_game_id == "poker", "Cannot bypass chooser reconnection eligibility")
	phones[2] = await join_phone("Poker Player 2", phones[2].joined.reconnect_token)
	app.active_game.game_selected.emit("poker-omaha"); await process_frame
	host = app.active_game; host.set_process(false)
	check(app.active_game_id == "poker-omaha" and host.seats.size() == 10, "Same ten-player party launches Omaha")
	var omaha: Dictionary = (await packet(phones[2].socket, "game")).get("payload", {})
	check(omaha.get("hand", []).size() == 4 and not omaha.has("deck"), "Actual Omaha socket receives only its own four cards")
	host.return_to_lobby(); await process_frame; app.active_game.return_to_lobby(); await process_frame
	check(not is_instance_valid(app.active_game) and app.lan_server.active_game_id.is_empty(), "Child → Poker → game selection returns cleanly")
	for phone in phones: phone.socket.close()
	app.lan_server.stop_server(); app.queue_free(); await process_frame; await process_frame
	print("Poker network: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
