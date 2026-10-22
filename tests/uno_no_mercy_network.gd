extends "res://tests/uno_network.gd"


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.test_data/uno-no-mercy-network")
	app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new("res://.test_data/uno-no-mercy-network/profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	var phones: Array = []
	for index in 4: phones.append(await join_phone("Mercy Player %d" % index))
	app._play_from_lobby()
	app._launch_game(app.game_catalog.games.filter(func(module: Dictionary) -> bool: return module.id == "uno")[0])
	var game = app.active_game
	for timer in [game.ai_timer,game.auto_timer,game.jump_timer,game.catch_timer]: timer.process_mode = Node.PROCESS_MODE_DISABLED
	game._set_gamemode(2)
	game._apply_options()
	var revision: int = game.rules.revision
	for index in phones.size():
		var view: Dictionary = (await packet(phones[index].socket,"game",true,revision)).payload
		check(view.gamemode == "no_mercy" and int(view.viewer) == index and view.options.allow_mercy and not view.options.force_play and view.hand.map(func(face: Dictionary) -> int: return int(face.id)) == game.rules.hands[index], "Mode Apply privately routes the new hand and mode defaults")
		check(not view.has("deck") and not view.has("retired") and not view.has("hands"), "No Mercy preserves private hands and stock")
	phones[0].socket.send_text(JSON.stringify({"type":"game","game_id":"uno","payload":{"action":"set_option","option":"allow_mercy","enabled":false,"revision":revision}}))
	for frame in 5: await process_frame
	check(game.rules.allow_mercy and game.rules.revision == revision, "Controllers cannot edit host settings")
	var roulette: int = game.rules.cards.filter(func(face: Dictionary) -> bool: return face.kind == "color_roulette")[0].id
	for hand in game.rules.hands: hand.erase(roulette)
	game.rules.deck.erase(roulette)
	game.rules.hands[0].append(roulette)
	game.rules.turn = 0
	game.rules.phase = "play"
	game.rules.pending_draw = 0
	game.rules.pending_color = ""
	game.rules.drawn = -1
	game.rules.revision += 1
	game._publish()
	revision = game.rules.revision
	phones[0].socket.send_text(JSON.stringify({"type":"game","game_id":"uno","payload":{"action":"play","card":roulette,"revision":revision}}))
	var choice: Dictionary = (await packet(phones[1].socket,"game",true,revision + 1)).payload
	check(choice.phase == "roulette_color" and int(choice.turn) == 1 and not choice.top.has("selected_color"), "Roulette privately restores the recipient's pending choice")
	phones[1].socket.close()
	for frame in 180:
		phones[1].socket.poll()
		await process_frame
		if not game.missing.is_empty(): break
	var refreshed := await join_phone("Mercy Player 1",phones[1].joined.reconnect_token)
	var restored: Dictionary = (await packet(refreshed.socket,"game",true,revision + 1)).payload
	check(restored.phase == "roulette_color" and int(restored.turn) == 1 and not restored.paused, "Refresh restores roulette choice and resumes the same hand")
	refreshed.socket.send_text(JSON.stringify({"type":"game","game_id":"uno","payload":{"action":"color","color":"red","revision":restored.revision}}))
	var chosen: Dictionary = (await packet(refreshed.socket,"game",true,int(restored.revision) + 1)).payload
	check(chosen.phase != "roulette_color" and chosen.color == "red", "The real controller's choice resolves on the host")
	game.rules._eliminate(2)
	game.rules.turn = 0
	game.rules.pending_draw = 0
	game.rules.pending_color = ""
	game.rules.phase = "play"
	game.rules.drawn = -1
	game.rules.revision += 1
	game._publish()
	var out_view: Dictionary = (await packet(phones[2].socket,"game",true,game.rules.revision)).payload
	check(out_view.eliminated[2] and out_view.hand.is_empty() and out_view.legal_cards.is_empty(), "Eliminated phone receives a private spectator snapshot")
	revision = game.rules.revision
	phones[2].socket.send_text(JSON.stringify({"type":"game","game_id":"uno","payload":{"action":"draw","revision":revision}}))
	for frame in 5: await process_frame
	check(game.rules.revision == revision, "Eliminated controller input is rejected")
	phones[2].socket.close()
	for frame in 30: await process_frame
	check(game.missing.is_empty(), "An eliminated spectator disconnect cannot pause surviving players")
	game.rules._eliminate(1)
	game.rules._eliminate(3)
	game.rules._check_survivor()
	game._publish()
	game.rules.play_again()
	game._start_deal()
	game._publish()
	check(game.missing.has(str(phones[2].joined.player.id)), "Replay pauses for a previously disconnected spectator restored to active play")
	var spectator := await join_phone("Mercy Player 2",phones[2].joined.reconnect_token)
	var rejoined: Dictionary = (await packet(spectator.socket,"game",true,game.rules.revision)).payload
	check(not rejoined.eliminated[2] and not rejoined.paused and rejoined.hand.size() == 7, "Spectator reconnect restores the fresh active hand after replay")
	var request := HTTPRequest.new()
	root.add_child(request)
	for asset in ["art/cards/red-draw4.svg","art/cards/blue-skip_all.svg","art/cards/green-discard_all.svg","art/cards/wild-reverse_draw4.svg","art/cards/wild-draw6.svg","art/cards/wild-draw10.svg","art/cards/wild-color_roulette.svg","art/cards/blue-color_roulette-chosen.svg"]:
		request.request("http://127.0.0.1:%d/game/uno/%s" % [app.lan_server.http_port,asset])
		var response: Array = await request.request_completed
		check(response[1] == 200, "No Mercy artwork loads from the offline LAN server: " + asset)
	request.queue_free()
	game.return_to_lobby()
	await process_frame
	check(app.active_game == null and app.current_state == "game_menu" and app.lan_server.running, "No Mercy exits through shared navigation")
	check((await packet(refreshed.socket,"screen")).get("game_id","missing") == "", "The SDK receives the existing return route")
	refreshed.socket.close()
	spectator.socket.close()
	for phone in phones: phone.socket.close()
	app.lan_server.stop_server()
	app.queue_free()
	await process_frame
	await create_timer(.15).timeout
	print("UNO No Mercy network: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
