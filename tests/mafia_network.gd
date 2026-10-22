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


func packet(socket: WebSocketPeer, type: String, private := false, revision := -1) -> Dictionary:
	for frame in 600:
		socket.poll()
		while socket.get_available_packet_count() > 0:
			var data: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if data is Dictionary and data.get("type") == type:
				if type == "game" and (private and data.payload.get("viewer", -1) < 0 or revision >= 0 and data.payload.get("revision") != revision):
					continue
				return data
		await process_frame
	return {}


func join_player(name: String, token := "") -> Dictionary:
	var socket := WebSocketPeer.new()
	socket.connect_to_url("ws://127.0.0.1:%d/" % app.lan_server.websocket_port)
	await packet(socket, "hello")
	socket.send_text(JSON.stringify({"type": "join", "name": name, "reconnect_token": token}))
	return {"socket": socket, "joined": await packet(socket, "joined")}


func request(client: Dictionary, action: String, extra: Dictionary = {}) -> Dictionary:
	var input := {"action": action, "revision": app.active_game.rules.revision}
	input.merge(extra, true)
	client.socket.send_text(JSON.stringify({"type": "game", "game_id": "mafia", "payload": input}))
	for frame in 12:
		client.socket.poll()
		await process_frame
	return (await packet(client.socket, "game", true, app.active_game.rules.revision)).get("payload", {})


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.test_data/mafia-network")
	app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new("res://.test_data/mafia-network/profiles-%d.json" % Time.get_ticks_usec())
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	await process_frame
	var modules: Array = app.game_catalog.games.filter(func(game: Dictionary) -> bool: return game.id == "mafia")
	check(modules.size() == 1, "The validated catalog discovers Mafia exactly once")
	var module: Dictionary = modules[0]
	check(module.min_players == 4 and module.max_players == 16 and module.modes == ["multiplayer"] and not app._can_launch(module), "Manifest enforces human-only 4–16 player limits")
	var clients: Array = []
	for seat in 7:
		clients.append(await join_player("Mafia Network Player %d" % seat))
		check(not clients[seat].joined.is_empty(), "Each phone joins through the shared launcher server")
		if seat == 2:
			check(not app._can_launch(module), "Three phones cannot launch Mafia")
		if seat == 3:
			check(app._can_launch(module), "Four phones can launch Mafia")
	app._play_from_lobby()
	app._launch_game(module)
	await process_frame
	var host = app.active_game
	for seat in 7:
		var initial: Dictionary = (await packet(clients[seat].socket, "game", true)).payload
		check(initial.viewer == seat and initial.phase == "setup" and initial.secret.role == "", "Private setup arrives at its admitted owner without assigned roles")
	host._set_option("godfather", true)
	host._set_option("boxer", true)
	host._apply_options()
	# A deterministic test deal exercises the same real private routing and rules.
	host.rules.roles = ["godfather", "mafia", "detective", "doctor", "boxer", "civilian", "civilian"]
	host.rules.revision += 1
	host._publish()
	var shared: Dictionary = (await packet(clients[6].socket, "game", false, host.rules.revision)).payload
	check(shared.viewer == -1 and not shared.has("secret") and shared.outcome.is_empty(), "Raw public packets contain no roles or private night choices")
	for seat in 7:
		var own: Dictionary = await request(clients[seat], "sync")
		check(own.secret.role == host.rules.roles[seat] and not JSON.stringify(own).contains("profile_id") and not JSON.stringify(own).contains("reconnect_token"), "Raw private packets contain the owner's role and no identity storage secrets")
	await request(clients[0], "night_action", {"target": 6})
	var teammate: Dictionary = await request(clients[1], "sync")
	check(teammate.secret.mafia_votes.size() == 1 and int(teammate.secret.mafia_votes[0].voter) == 0 and int(teammate.secret.mafia_votes[0].target) == 6, "A confirmed Godfather vote reaches their fellow mafia")
	var civilian: Dictionary = await request(clients[5], "sync")
	check(civilian.secret.allies.is_empty() and civilian.secret.mafia_votes.is_empty(), "Town sockets never receive mafia collaboration")
	await request(clients[5], "suspect", {"target": 0})
	await request(clients[6], "suspect", {"target": -1})
	var private_suspicion: Dictionary = await request(clients[0], "sync")
	check(not private_suspicion.has("suspicions") and private_suspicion.suspect_choice == -1, "Private sockets receive no shared suspicion list or other player's choice")
	var secret: Dictionary = teammate.secret
	clients[1].socket.close()
	for frame in 200:
		clients[1].socket.poll()
		await process_frame
		if host.rules.disconnected.has(1):
			break
	check(host.rules.paused() and host.rules.night_actions.size() == 1, "Disconnect pauses without discarding the confirmed vote")
	await request(clients[4], "night_action", {"target": 0})
	check(host.rules.night_actions.size() == 1, "A real controller cannot act while the game is paused")
	var original_id: String = clients[1].joined.player.id
	clients[1] = await join_player("Mafia Network Player 1", clients[1].joined.reconnect_token)
	check(clients[1].joined.player.id == original_id and clients[1].joined.game_id == "mafia", "Refresh rejoins the same identity and active module")
	var restored: Dictionary = (await packet(clients[1].socket, "game", true, host.rules.revision)).payload
	check(restored.secret == secret and not restored.paused and host.rules.night_actions.size() == 1, "Refresh restores the same role and mafia votes")
	await request(clients[1], "night_action", {"target": 6})
	await request(clients[2], "night_action", {"target": 0})
	await request(clients[3], "night_action", {"target": 3})
	await request(clients[4], "night_action", {"target": 0})
	check(host.rules.phase == "vote" and not host.rules.alive[6] and host.rules.alive[5], "Two confirmed votes still kill and dawn opens voting when Boxer blocks only Godfather")
	var dawn: Dictionary = await request(clients[6], "sync")
	check(not dawn.has("suspicions") and dawn.daytime and dawn.can_suspect, "Dawn changes phone scenery and grants the eliminated player one will")
	var public_dawn: Dictionary = host.rules.view_for()
	check(public_dawn.suspicions == [{"target": 0}] and public_dawn.events[0] == "Day 1. Suspected players: Mafia Network Player 0.", "Host list and shared history reveal only targets, without authors")
	await request(clients[6], "suspect", {"target": 1})
	await request(clients[6], "suspect", {"target": 0})
	check(host.rules.last_wills[6] == 1, "A second last will is rejected over real sockets")
	var detective: Dictionary = await request(clients[2], "sync")
	check(detective.secret.reports[0].result == "civilian", "Godfather reads as civilian in the Detective's raw private result")
	clients[6].socket.close()
	for frame in 100:
		clients[6].socket.poll()
		await process_frame
		if host.rules.disconnected.has(6):
			break
	check(not host.rules.paused(), "An eliminated player's disconnect does not stop the remaining party")
	await request(clients[5], "begin_vote")
	check(host.rules.phase == "vote" and host.rules.votes.is_empty() and not host.phase_dialog.overlay.visible, "Real sockets restore immediate voting without a popup or first ballot")
	await request(clients[0], "vote", {"target": 5})
	for seat in range(1, 6):
		await request(clients[seat], "vote", {"target": 0})
	check(host.rules.phase == "ejection" and host.phase_dialog.overlay.visible, "A decisive real-socket vote always shows an ejection")
	await create_timer(host.rules.EJECTION_DURATION + 0.2).timeout
	check(not host.rules.alive[0] and host.rules.phase == "night" and host.rules.day == 2, "Day votes eliminate the suspect and start the next night")
	for seat in [1, 2, 3, 4]:
		await request(clients[seat], "night_action", {"target": 3 if seat == 3 else (1 if seat == 2 else -1)})
	await request(clients[5], "suspect", {"target": -1})
	check(host.rules.suspicions.any(func(entry: Dictionary) -> bool: return entry.voter == 6 and entry.last_will and entry.target == 1), "The disconnected spectator's accepted will is published the next dawn")
	await request(clients[2], "begin_vote")
	await request(clients[1], "vote", {"target": 5})
	for seat in [2, 3, 4, 5]:
		await request(clients[seat], "vote", {"target": 1})
	check(host.rules.phase == "ejection" and host.rules.history.is_empty(), "The final elimination cannot skip directly to results")
	await create_timer(host.rules.EJECTION_DURATION + 0.2).timeout
	check(host.rules.phase == "finished" and not host.rules.outcome.mafia_wins and host.rules.outcome.winners.size() == 5, "The town wins over real sockets, including its eliminated teammate")
	for seat in 7:
		var profile: Dictionary = app.profile_store.get_profile(clients[seat].joined.player.id)
		check(app.profile_store.lifetime_points(profile) == (0 if seat < 2 else 1) and profile.wins == (0 if seat < 2 else 1) and profile.losses == (1 if seat < 2 else 0), "Existing profile APIs record exactly one team result and winner point")
	var completed: int = host.rules.round_number
	await request(clients[2], "replay")
	check(host.rules.round_number == completed and host.rules.phase == "finished", "Phone replay cannot bypass the host")
	host.return_to_lobby()
	await process_frame
	check(app.current_state == "game_menu" and app.active_game == null and app.lan_server.running and not app.lan_server.lobby_open, "Clean exit preserves the existing LAN server and locked game menu")
	check((await packet(clients[2].socket, "screen")).get("game_id", "missing") == "", "Controllers receive the SDK's normal return navigation")
	app._show_lobby()
	clients[6] = await join_player("Mafia Network Player 6", clients[6].joined.reconnect_token)
	for seat in range(7, 16):
		clients.append(await join_player("Mafia Network Player %d" % seat))
	app._play_from_lobby()
	check(app._can_launch(module), "Sixteen connected phones are admitted")
	app._launch_game(module)
	await process_frame
	app.active_game._replay()
	check(app.active_game.rules.players.size() == 16 and app.active_game.rules.roles.count("mafia") == 3 and app.active_game.rules.roles.count("godfather") == 1 and app.active_game.rules.roles.count("boxer") == 1, "Sixteen-player relaunch remembers optional roles and assigns four mafia-team members across sixteen human seats")
	app.active_game.return_to_lobby()
	await process_frame
	for client in clients:
		client.socket.close()
	app.lan_server.stop_server()
	clients.clear()
	app.queue_free()
	await process_frame
	print("Mafia network: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
