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
	return {"socket": socket, "joined": await _message(socket, "joined")}


func _request(socket: WebSocketPeer, input: Dictionary) -> Dictionary:
	input.revision = app.active_game.rules.revision
	socket.send_text(JSON.stringify({"type": "game", "game_id": "quoridor", "payload": input}))
	for frame in 20:
		socket.poll()
		await process_frame
	return (await _message(socket, "game", app.active_game.rules.revision)).get("payload", {})


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.test_data/quoridor-network")
	app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new("res://.test_data/quoridor-network/profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	await process_frame
	var first := await _join("Quoridor Player 1")
	var second := await _join("Quoridor Player 2")
	var third := await _join("Quoridor Player 3")
	var fourth := await _join("Quoridor Player 4")
	check(not first.joined.is_empty() and not second.joined.is_empty() and not third.joined.is_empty() and not fourth.joined.is_empty(), "Four actual controller sockets use the launcher join flow")
	app._play_from_lobby()
	await process_frame
	var module: Dictionary = app.game_catalog.games.filter(func(game: Dictionary) -> bool: return game.id == "quoridor")[0]
	check(app._can_launch(module) and not app.lan_server.lobby_open, "Catalog launches the locked four-player party")
	app._launch_game(module)
	await process_frame
	for sound in app.active_game.sounds.values():
		sound.volume_db = -80
	var state: Dictionary = (await _message(first.socket, "game")).get("payload", {})
	check(state.pawns == [76.0, 36.0, 4.0, 44.0] and state.remaining == [5.0, 5.0, 5.0, 5.0] and state.players[0].id == first.joined.player.id, "Socket receives host-authoritative four-player opening state")
	state = await _request(first.socket, {"action": "move", "to": 67})
	check(state.pawns[0] == 67 and state.turn == 2, "Phone move reaches the authoritative host")
	state = await _request(second.socket, {"action": "wall", "row": 3, "col": 3, "orientation": "h"})
	check(state.walls.size() == 1 and state.remaining == [5.0, 4.0, 5.0, 5.0], "Second controller places a legal wall")
	state = await _request(third.socket, {"action": "move", "to": 13})
	check(state.pawns[2] == 13 and state.turn == 4, "Third phone controls its north pawn")
	state = await _request(fourth.socket, {"action": "move", "to": 43})
	check(state.pawns[3] == 43 and state.turn == 1, "Fourth phone controls its east pawn and turn wraps")
	var revision: int = app.active_game.rules.revision
	state = await _request(first.socket, {"action": "wall", "row": 3, "col": 3, "orientation": "v"})
	check(state.revision == revision and state.walls.size() == 1, "Crossing request is rejected over actual sockets")
	var token: String = first.joined.reconnect_token
	first.socket.close()
	for frame in 150:
		first.socket.poll()
		await process_frame
		if not app.active_game.missing.is_empty():
			break
	check(not app.active_game.missing.is_empty() and app.active_game.rules.revision == revision, "Disconnect pauses without altering the board")
	var refreshed := await _join("Quoridor Player 1", token)
	check(refreshed.joined.get("game_id") == "quoridor" and refreshed.joined.player.id == first.joined.player.id, "Refresh restores admitted identity and current game")
	state = (await _message(refreshed.socket, "game", revision)).get("payload", {})
	check(not state.paused and state.pawns == [67.0, 36.0, 13.0, 43.0] and state.walls.size() == 1 and state.remaining[1] == 4, "Reconnect snapshot restores all four pawns, walls, stock, and turn")
	var third_token: String = third.joined.reconnect_token
	third.socket.close()
	for frame in 150:
		third.socket.poll()
		await process_frame
		if app.active_game.missing.has(third.joined.player.id):
			break
	check(app.active_game.missing.has(third.joined.player.id), "A side-seat disconnect pauses the four-player board")
	var third_refreshed := await _join("Quoridor Player 3", third_token)
	state = (await _message(third_refreshed.socket, "game", revision)).get("payload", {})
	check(not state.paused and state.players[2].id == third.joined.player.id and state.pawns[2] == 13, "Third-seat refresh restores its original identity and board")
	app.active_game._select_computers(2)
	app.active_game._apply_settings()
	state = await _request(third_refreshed.socket, {"action": "sync"})
	check(state.players.size() == 4 and state.computer_count == 2 and state.players[2].computer, "Host settings broadcast a changed human/AI lineup to spectators")
	revision = app.active_game.rules.revision
	third_refreshed.socket.send_text(JSON.stringify({"type": "game", "game_id": "quoridor", "payload": {"action": "move", "to": 67, "revision": revision}}))
	for frame in 12:
		third_refreshed.socket.poll()
		await process_frame
	check(app.active_game.rules.revision == revision, "Spectator sockets cannot play as an AI seat")
	var request := HTTPRequest.new()
	root.add_child(request)
	for path in ["/controller-sdk.js", "/styles.css", "/ui/playful/button-carved.svg", "/ui/playful/button-carved-primary.svg", "/ui/playful/score-ornate.svg", "/ui/playful/stat-wins.svg", "/ui/playful/stat-walls.svg", "/ui/playful/control-move.svg", "/ui/playful/control-wall.svg", "/ui/playful/control-rotate.svg", "/game/quoridor/", "/game/quoridor/controller.js", "/game/quoridor/style.css", "/game/quoridor/background.json", "/game/quoridor/art/courtyard.png", "/game/quoridor/art/pawn.svg", "/game/quoridor/art/title.svg", "/game/quoridor/audio/wall.wav"]:
		request.request("http://127.0.0.1:%d%s" % [app.lan_server.http_port, path])
		var response: Array = await request.request_completed
		check(response[1] == 200, "Required offline asset is served locally: " + path)
	request.queue_free()
	app.active_game.return_to_lobby()
	await process_frame
	check(app.current_state == "game_menu" and app.active_game == null and app.lan_server.running and not app.lan_server.lobby_open, "Back to Games keeps the LAN server and locked roster")
	check((await _message(refreshed.socket, "screen")).get("game_id", "missing") == "", "SDK receives normal return navigation")
	refreshed.socket.close()
	second.socket.close()
	third_refreshed.socket.close()
	fourth.socket.close()
	app.lan_server.stop_server()
	app.queue_free()
	for frame in 8:
		await process_frame
	await create_timer(0.15).timeout
	print("Quoridor network: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
