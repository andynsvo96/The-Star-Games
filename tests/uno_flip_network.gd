extends "res://tests/uno_network.gd"


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.test_data/uno-flip-network")
	app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new("res://.test_data/uno-flip-network/profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	var phones: Array = []
	for index in 4: phones.append(await join_phone("Flip Player %d" % index))
	check(phones.all(func(phone: Dictionary) -> bool: return not phone.joined.is_empty()), "Four real phones join the existing launcher")
	app._play_from_lobby()
	app._launch_game(app.game_catalog.games.filter(func(module: Dictionary) -> bool: return module.id == "uno")[0])
	var game = app.active_game
	for timer in [game.ai_timer,game.auto_timer,game.jump_timer]: timer.process_mode = Node.PROCESS_MODE_DISABLED
	game._set_gamemode(1)
	game._apply_options()
	var revision: int = game.rules.revision
	for index in phones.size():
		var view: Dictionary = (await packet(phones[index].socket,"game",true,revision)).payload
		check(view.gamemode == "flip" and int(view.viewer) == index and view.hand.map(func(face: Dictionary) -> int: return int(face.id)) == game.rules.hands[index], "Apply privately routes the new Flip hand to its admitted owner")
		check(view.backs.all(func(backs: Array) -> bool: return backs.all(func(face: Dictionary) -> bool: return not face.has("id"))) and not view.has("flip_faces") and not view.has("deck"), "Public inactive faces omit identities, pairs and deck order")
	phones[0].socket.send_text(JSON.stringify({"type":"game","game_id":"uno","payload":{"action":"set_gamemode","gamemode":"classic","revision":revision}}))
	for frame in 5: await process_frame
	check(game.rules.gamemode == "flip" and game.rules.revision == revision, "Controllers cannot change host settings")
	game.rules.side = "light"
	game.rules._activate_faces()
	var flip: int = game.rules.cards.filter(func(face: Dictionary) -> bool: return face.color == "red" and face.kind == "flip")[0].id
	var top: int = game.rules.cards.filter(func(face: Dictionary) -> bool: return face.color == "red" and face.kind == "4")[0].id
	for hand in game.rules.hands:
		hand.erase(flip)
		hand.erase(top)
	game.rules.hands[0].append(flip)
	game.rules.discard = [top]
	game.rules.deck = range(112).filter(func(id: int) -> bool: return not game.rules.discard.has(id) and not game.rules.hands.any(func(hand: Array) -> bool: return hand.has(id)))
	game.rules.turn = 0
	game.rules.phase = "play"
	game.rules.color = "red"
	game.rules.pending_draw = 0
	game.rules.pending_color = ""
	game.rules.drawn = -1
	game.rules.revision += 1
	game._publish()
	revision = game.rules.revision
	phones[0].socket.send_text(JSON.stringify({"type":"game","game_id":"uno","payload":{"action":"play","card":flip,"revision":revision}}))
	var flipped: Dictionary = (await packet(phones[0].socket,"game",true,revision + 1)).payload
	check(flipped.side == "dark" and flipped.motion.flights.back().kind == "flip" and flipped.hand.all(func(face: Dictionary) -> bool: return face.side == "dark"), "A real play flips the private hand and table on the authoritative host")
	phones[0].socket.send_text(JSON.stringify({"type":"game","game_id":"uno","payload":{"action":"play","card":flip,"revision":revision}}))
	for frame in 5: await process_frame
	check(game.rules.revision == int(flipped.revision), "Queued light-side input cannot affect the dark table")
	var own: Array = game.rules.hands[1].duplicate()
	phones[1].socket.close()
	for frame in 180:
		phones[1].socket.poll()
		await process_frame
		if not game.missing.is_empty(): break
	check(not game.missing.is_empty() and game.apply_options.disabled and game.gamemode_choice.disabled, "Disconnect pauses Flip and locks settings")
	var refreshed := await join_phone("Flip Player 1",phones[1].joined.reconnect_token)
	var restored: Dictionary = (await packet(refreshed.socket,"game",true)).payload
	check(restored.gamemode == "flip" and restored.side == "dark" and restored.hand.map(func(face: Dictionary) -> int: return int(face.id)) == own and not restored.paused, "Refresh restores the exact dark-side hand and mode")
	var request := HTTPRequest.new()
	root.add_child(request)
	for asset in ["art/cards/red-flip.svg","art/cards/wild-draw2.svg","art/cards/green-draw2-chosen.svg","art/cards/flip-dark-purple-skip_all.svg","art/cards/flip-dark-wild-draw_color.svg","art/cards/flip-dark-teal-draw_color-chosen.svg"]:
		request.request("http://127.0.0.1:%d/game/uno/%s" % [app.lan_server.http_port,asset])
		var response: Array = await request.request_completed
		check(response[1] == 200, "Flip asset loads from the offline LAN server: " + asset)
	request.queue_free()
	game.return_to_lobby()
	await process_frame
	check(app.active_game == null and app.current_state == "game_menu" and app.lan_server.running, "Flip exits cleanly through shared navigation")
	check((await packet(refreshed.socket,"screen")).get("game_id","missing") == "", "The SDK receives the existing return route")
	refreshed.socket.close()
	for phone in phones: phone.socket.close()
	app.lan_server.stop_server()
	app.queue_free()
	await process_frame
	await create_timer(.15).timeout
	print("UNO Flip network: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
