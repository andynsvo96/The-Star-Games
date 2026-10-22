extends SceneTree

var app: Control
var checks := 0
var failures := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func packet(socket: WebSocketPeer, type: String, kind := "", viewer := -2) -> Dictionary:
	for frame in 600:
		socket.poll()
		while socket.get_available_packet_count() > 0:
			var value: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if not value is Dictionary or value.get("type") != type:
				continue
			if type == "game":
				if not kind.is_empty() and value.payload.get("kind") != kind:
					continue
				if viewer >= -1 and int(value.payload.get("viewer", -2)) != viewer:
					continue
			return value
		await process_frame
	return {}


func join_player(name: String, token := "") -> Dictionary:
	var socket := WebSocketPeer.new()
	socket.connect_to_url("ws://127.0.0.1:%d/" % app.lan_server.websocket_port)
	await packet(socket, "hello")
	socket.send_text(JSON.stringify({"type": "join", "name": name, "reconnect_token": token}))
	return {"socket": socket, "joined": await packet(socket, "joined")}


func request(client: Dictionary, action: String, extra: Dictionary = {}, kind := "state") -> Dictionary:
	var host = app.active_game
	client.socket.poll()
	while client.socket.get_available_packet_count() > 0:
		client.socket.get_packet()
	var input := {"action": action, "revision": host.rules.revision, "turn_id": host.rules.turn_id}
	input.merge(extra, true)
	client.socket.send_text(JSON.stringify({"type": "game", "game_id": "pictionary", "payload": input}))
	for frame in 12:
		client.socket.poll()
		await process_frame
	var viewer: int = host._seat_for(str(client.joined.player.id)) if kind == "state" else -2
	return (await packet(client.socket, "game", kind, viewer)).get("payload", {})


func _run() -> void:
	var folder := "res://.test_data/pictionary-network/%d/" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new(folder + "profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	await process_frame
	var modules: Array = app.game_catalog.games.filter(func(game: Dictionary) -> bool: return game.id == "pictionary")
	check(modules.size() == 1, "Catalog discovers Pictionary exactly once")
	if modules.size() != 1:
		quit(1)
		return
	var module: Dictionary = modules[0]
	check(module.min_players == 3 and module.max_players == 16 and not app._can_launch(module), "Catalog requires three to sixteen human controllers")
	var clients: Array = []
	for seat in 3:
		clients.append(await join_player("Pictionary Artist %d" % seat))
		check(not clients[seat].joined.is_empty(), "Phones join through the launcher")
		if seat < 2:
			check(not app._can_launch(module), "One or two phones cannot launch")
	app._play_from_lobby()
	check(app._can_launch(module) and not app.lan_server.lobby_open, "Three humans launch as an admitted locked party")
	app._launch_game(module)
	await process_frame
	var host = app.active_game
	for seat in 3:
		var state: Dictionary = (await packet(clients[seat].socket, "game", "state", seat)).get("payload", {})
		check(not state.is_empty() and state.viewer == seat and state.has("choices") == (seat == 0), "Private word choices go only to the drawer's real socket")
	var chosen: Dictionary = await request(clients[0], "choose", {"choice": 0})
	check(chosen.phase == "drawing" and chosen.has("secret") and host.rules.phase == "drawing", "Drawer chooses a word through the SDK contract")
	var public: Dictionary = (await packet(clients[1].socket, "game", "state", -1)).get("payload", {})
	check(not public.has("secret") and not public.has("choices") and not public.has("word"), "Raw public payloads contain no selected word")
	var private: Dictionary = await request(clients[1], "sync")
	check(not private.has("secret") and not private.has("choices") and private.hint.contains("_"), "Guessers never receive the word in hidden fields")
	var close_guess: Dictionary = await request(clients[1], "guess", {"guess": host.rules.chosen.word + "x"})
	check(close_guess.last_guess.quality == "close" and close_guess.last_guess.points == 0 and not close_guess.last_guess.has("word") and host.rules.scores == [0, 0, 0], "Real sockets receive orange feedback without points or answer fields")
	var live_public: Dictionary = host._snapshot(-1)
	check(live_public.guess_bubbles.size() == 1 and live_public.guess_bubbles[0].text == host.rules.chosen.word + "x" and not live_public.guess_bubbles[0].has("word"), "The host scoreboard receives a bounded live near-miss bubble without the answer field")
	await create_timer(0.8).timeout
	var ink: Dictionary = await request(clients[0], "ink", {"epoch": host.rules.drawing_epoch, "stroke_id": "network-stroke", "sequence": 0, "color": 0, "width": 1, "points": [[20, 40], [500, 300]], "end": false}, "ink")
	check(ink.kind == "ink" and ink.points.size() == 2 and host.rules.strokes.size() == 1, "Real drawing chunks reach host and other controllers")
	var delta: Dictionary = (await packet(clients[2].socket, "game", "ink")).get("payload", {})
	check(delta.stroke_id == "network-stroke" and not delta.has("secret"), "Shared ink deltas are small and secret-free")
	await request(clients[1], "guess", {"guess": host.rules.chosen.word})
	check(host.rules.scores == [0, 0, 0] and host.rules.phase == "drawing", "Correct guesses record rank while the fixed pool waits for turn completion")
	var ranked: Dictionary = await request(clients[1], "sync")
	check(ranked.last_guess.rank == 1 and ranked.last_guess.seconds >= 0.8 and ranked.last_guess.text.is_empty() and ranked.guess_results.is_empty(), "First correct rank and elapsed time are authoritative and live answer stays hidden")
	await request(clients[0], "ink", {"epoch": host.rules.drawing_epoch, "stroke_id": "network-stroke", "sequence": 1, "color": 0, "width": 1, "points": [[700, 500]], "end": true}, "ink")
	check(host.rules.strokes[0].points.size() == 3, "Simultaneous guessing preserves stream sequence validation")
	var refreshed: Dictionary = await request(clients[2], "sync")
	check(refreshed.strokes[0].points.size() == 3 and refreshed.scores[1] == 0 and refreshed.feed.is_empty(), "Full sync restores the drawing without exposing other last guesses or provisional points")
	var word: String = host.rules.chosen.word
	var token: String = clients[0].joined.reconnect_token
	var identity: String = clients[0].joined.player.id
	clients[0].socket.close()
	for frame in 240:
		clients[0].socket.poll()
		await process_frame
		if host.rules.missing.has(0): break
	var remaining: float = host.rules.remaining
	await create_timer(0.08).timeout
	check(host.rules.missing.has(0) and is_equal_approx(remaining, host.rules.remaining), "Drawer disconnect freezes the authoritative timer")
	clients[0] = await join_player("Pictionary Artist 0", token)
	check(clients[0].joined.player.id == identity and clients[0].joined.game_id == "pictionary", "Refresh rejoins the same admitted player in the current game")
	var restored: Dictionary = (await packet(clients[0].socket, "game", "state", 0)).get("payload", {})
	check(restored.secret == word and restored.strokes[0].points.size() == 3 and not restored.paused and restored.remaining <= remaining + 0.000001, "Reconnect retains private word, canvas, score and remaining time")
	await request(clients[2], "guess", {"guess": word})
	check(host.rules.phase == "reveal" and host.rules.scores == [0, 67, 33], "Two correct guesses split exactly 100 points by rank")
	var revealed: Dictionary = await request(clients[2], "sync")
	check(revealed.guess_results.is_empty() and revealed.feed.is_empty() and not revealed.has("last_guess"), "Turn completion keeps last guesses hidden on real sockets until match completion")
	host._next_turn()
	for turn in range(1, 3):
		await request(clients[turn], "choose", {"choice": 0})
		for seat in 3:
			if seat != turn:
				await request(clients[seat], "guess", {"guess": host.rules.chosen.word})
		host._next_turn()
	check(host.rules.phase == "finished" and host.rules.scores == [134, 100, 66], "A complete real-socket match conserves one hundred points per successful turn")
	var final_state: Dictionary = await request(clients[2], "sync")
	check(final_state.guess_results.size() == 3 and final_state.guess_results[0].correct and final_state.score_order.map(func(seat: float) -> int: return int(seat)) == [0, 1, 2], "Finished sync restores sorted last guesses and cumulative scoreboard order")
	check(final_state.guess_results[0].seconds <= final_state.guess_results[1].seconds and final_state.guess_results[1].seconds <= final_state.guess_results[2].seconds, "Finished socket results list the fastest correct guesses first")
	for seat in 3:
		var profile: Dictionary = app.profile_store.get_profile(clients[seat].joined.player.id)
		check(app.profile_store.lifetime_points(profile) == [134, 100, 66][seat], "Completed weighted points reach the existing saved profile API exactly once")
	host._publish(true)
	host._record_result()
	check(app.profile_store.lifetime_points(app.profile_store.get_profile(identity)) == 134, "Repeat result publication never awards twice")
	await request(clients[0], "replay")
	check(host.rules.phase == "finished", "Controller replay cannot restart a match")
	host._replay()
	check(host.rules.drawer == 1 and host.rules.session_wins == [1, 0, 0], "Host replay rotates the first drawer and keeps the ranked winner")
	var http := HTTPRequest.new()
	root.add_child(http)
	for asset in ["", "style.css", "controller.js", "thumbnail.svg", "background.json", "art/studio.png", "art/title.png", "art/canvas-frame.png", "audio/turn.wav", "audio/correct.wav", "audio/wrong.wav", "audio/countdown.wav", "audio/time_up.wav", "audio/match.wav"]:
		http.request("http://127.0.0.1:%d/game/pictionary/%s" % [app.lan_server.http_port, asset])
		var response: Array = await http.request_completed
		check(response[1] == 200, "Production server supplies offline asset: " + asset)
	for asset in ["/styles.css", "/controller-sdk.js", "/ui/playful/paper-fill.png"]:
		http.request("http://127.0.0.1:%d%s" % [app.lan_server.http_port, asset])
		var response: Array = await http.request_completed
		check(response[1] == 200, "Shared UI dependency is routed offline: " + asset)
	http.queue_free()
	host.return_to_lobby()
	await process_frame
	check(app.current_state == "game_menu" and app.active_game == null and app.lan_server.running and not app.lan_server.lobby_open, "Return preserves shared LAN hosting and locked selection")
	check((await packet(clients[0].socket, "screen")).get("game_id", "missing") == "", "Controllers receive standard return navigation")
	app._show_lobby()
	for seat in range(3, 16):
		clients.append(await join_player("Pictionary Artist %d" % seat))
		check(not clients[-1].joined.is_empty(), "Additional players join only after return to lobby")
	app._play_from_lobby()
	check(app._can_launch(module), "Sixteen humans can launch Pictionary")
	app._launch_game(module)
	await process_frame
	check(app.active_game.rules.players.size() == 16, "Maximum party uses sixteen admitted human seats")
	app.active_game.return_to_lobby()
	await process_frame
	for client in clients:
		client.socket.close()
		client.socket.poll()
	app.lan_server.stop_server()
	app.queue_free()
	await process_frame
	# Audio playback releases on the mixer thread after the host has shut down.
	await create_timer(0.3).timeout
	print("Pictionary network: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
