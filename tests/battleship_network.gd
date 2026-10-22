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


func _message(socket: WebSocketPeer, type: String, revision := -1) -> Dictionary:
	for frame in 600:
		socket.poll()
		while socket.get_available_packet_count() > 0:
			var packet: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if packet is Dictionary and packet.get("type") == type and (revision < 0 or packet.get("payload", {}).get("revision") == revision):
				return packet
		await process_frame
	return {}


func _join(name: String, token := "") -> Dictionary:
	var socket := WebSocketPeer.new()
	socket.connect_to_url("ws://127.0.0.1:%d/" % app.lan_server.websocket_port)
	await _message(socket, "hello")
	socket.send_text(JSON.stringify({"type": "join", "name": name, "reconnect_token": token}))
	var packet := await _message(socket, "joined")
	return {"socket": socket, "joined": packet}


func _request(socket: WebSocketPeer, action: String) -> Dictionary:
	socket.send_text(JSON.stringify({"type": "game", "game_id": "battleship", "payload": {"action": action, "revision": app.active_game.rules.revision}}))
	for frame in 20:
		socket.poll()
		await process_frame
	return (await _message(socket, "game", app.active_game.rules.revision)).get("payload", {})


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.test_data/battleship-network")
	app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new("res://.test_data/battleship-network/profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	await process_frame
	check(app.current_state == "lobby" and app.lan_server.running, "Launcher opens its existing offline LAN connection flow")
	var first := await _join("Battleship Captain One")
	var second := await _join("Battleship Captain Two")
	check(not first.joined.is_empty() and not second.joined.is_empty(), "Two real browser sockets join the launcher")
	app._play_from_lobby()
	await process_frame
	var module: Dictionary = app.game_catalog.games.filter(func(game: Dictionary) -> bool: return game.id == "battleship")[0]
	check(app._can_launch(module) and not app.lan_server.lobby_open, "Validated two-player catalog entry launches from a locked party")
	app._launch_game(module)
	await process_frame
	var one: Dictionary = (await _message(first.socket, "game")).get("payload", {})
	var two: Dictionary = (await _message(second.socket, "game")).get("payload", {})
	check(one.viewer != two.viewer and one.players[one.viewer - 1].id == first.joined.player.id and two.players[two.viewer - 1].id == second.joined.player.id, "Launcher routes the private hook to each matching admitted identity")
	one = await _request(first.socket, "auto")
	check(one.fleets[one.viewer - 1].size() == 5 and one.fleets[2 - one.viewer].is_empty(), "First socket receives its deployed fleet alone")
	two = (await _message(second.socket, "game", app.active_game.rules.revision)).payload
	check(two.fleets == [[], []], "The opponent's raw WebSocket payload contains no first-fleet ships")
	two = await _request(second.socket, "auto")
	check(two.fleets[two.viewer - 1].size() == 5 and two.fleets[2 - two.viewer].is_empty(), "Second socket receives only its own deployed fleet")
	await _request(first.socket, "ready")
	await _request(second.socket, "ready")
	var own_cells: Array = app.active_game.rules.fleets[one.viewer - 1].duplicate(true)
	var token: String = first.joined.reconnect_token
	first.socket.close()
	for frame in 150:
		first.socket.poll()
		await process_frame
		if not app.active_game.missing.is_empty():
			break
	check(not app.active_game.missing.is_empty() and app.active_game.rules.phase == "battle", "A real disconnect pauses the existing battle and keeps both seats")
	var refreshed := await _join("Battleship Captain One", token)
	check(refreshed.joined.get("game_id") == "battleship" and refreshed.joined.player.id == first.joined.player.id, "Refresh rejoins the same identity and current module")
	var restored: Dictionary = (await _message(refreshed.socket, "game", app.active_game.rules.revision)).payload
	check(restored.fleets[restored.viewer - 1] == JSON.parse_string(JSON.stringify(own_cells)) and restored.fleets[2 - restored.viewer].is_empty() and not restored.paused, "Reconnect restores the authoritative private fleet without leaking the opponent")
	var request := HTTPRequest.new()
	root.add_child(request)
	for asset in ["background.json", "controller.js", "art/ship.png"]:
		var url: String = "/game/battleship/" + asset
		request.request("http://127.0.0.1:%d%s" % [app.lan_server.http_port, url])
		var response: Array = await request.request_completed
		check(response[1] == 200, "Battle controller artwork and sources are served entirely offline: " + asset)
	request.queue_free()
	var game = app.active_game
	game.return_to_lobby()
	await process_frame
	check(app.current_state == "game_menu" and app.active_game == null and app.lan_server.running and not app.lan_server.lobby_open, "Back to Games cancels the module and preserves the launcher LAN session")
	var exit_packet := await _message(refreshed.socket, "screen")
	check(exit_packet.get("game_id", "missing") == "", "Shared SDK receives normal return navigation")
	refreshed.socket.close()
	second.socket.close()
	app.lan_server.stop_server()
	app.queue_free()
	await process_frame
	print("Battleship network: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
