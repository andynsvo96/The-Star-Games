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
	socket.send_text(JSON.stringify({"type":"join", "name":name, "reconnect_token":token}))
	return {"socket":socket, "joined":await packet(socket, "joined")}


func request(client: Dictionary, action: String, extra: Dictionary = {}) -> Dictionary:
	var input := {"action":action, "revision":app.active_game.rules.revision}
	input.merge(extra, true)
	client.socket.send_text(JSON.stringify({"type":"game", "game_id":"spyfall", "payload":input}))
	for frame in 12:
		client.socket.poll()
		await process_frame
	return (await packet(client.socket, "game", true, app.active_game.rules.revision)).get("payload", {})


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.test_data/spyfall-network")
	app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new("res://.test_data/spyfall-network/profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	await process_frame
	var module: Dictionary = app.game_catalog.games.filter(func(game: Dictionary) -> bool: return game.id == "spyfall")[0]
	check(not app._can_launch(module), "Spyfall has no solo or computer fallback")
	var clients: Array = []
	for seat in 4:
		clients.append(await join_player("Spyfall Network Agent %d" % seat))
		check(not clients[seat].joined.is_empty(), "Phone socket joins through the shared launcher")
		if seat == 2:
			check(not app._can_launch(module), "Three humans cannot launch Spyfall")
	app._play_from_lobby()
	check(app._can_launch(module) and not app.lan_server.lobby_open, "Four humans can launch from a locked party")
	app._launch_game(module)
	await process_frame
	var host = app.active_game
	for seat in 4:
		var private: Dictionary = (await packet(clients[seat].socket, "game", true)).payload
		check(private.viewer == seat and private.players[seat].id == clients[seat].joined.player.id, "Private snapshot routes to the corresponding admitted owner")
		check(private.secret.location == ("" if seat == host.rules.spy else host.rules.location), "Raw socket payload gives the spy no selected location")
		check(private.phase == "playing" and private.timer_started and not private.vote_timer_started and private.remaining <= private.duration, "Every phone receives a running game clock and an unstarted voting clock")
	check(host.rules.phase == "playing" and host.rules.clock_running() and not host.rules.vote_timer_started, "Round time starts immediately while voting time waits")
	var spy: int = host.rules.spy
	var accuser: int = (spy + 1) % 4
	var voter: int = (spy + 2) % 4
	await request(clients[accuser], "accuse", {"target":spy})
	check(host.rules.vote_timer_started and host.rules.vote_remaining < host.rules.vote_duration and not host.rules.clock_running(), "A phone's first accusation starts only its voting clock and pauses round time")
	var secret: Dictionary = host.rules.view_for(voter).secret
	var clock: float = host.rules.remaining
	var vote_clock: float = host.rules.vote_remaining
	clients[voter].socket.close()
	for frame in 200:
		clients[voter].socket.poll()
		await process_frame
		if host.rules.missing.has(voter):
			break
	clock = host.rules.remaining
	vote_clock = host.rules.vote_remaining
	await create_timer(0.1).timeout
	check(host.rules.missing.has(voter) and host.rules.phase == "vote" and is_equal_approx(clock, host.rules.remaining) and is_equal_approx(vote_clock, host.rules.vote_remaining), "Disconnect freezes both round and voting time and preserves its phase")
	var token: String = clients[voter].joined.reconnect_token
	var old_id: String = clients[voter].joined.player.id
	clients[voter] = await join_player("Spyfall Network Agent %d" % voter, token)
	check(clients[voter].joined.player.id == old_id and clients[voter].joined.game_id == "spyfall", "Refresh restores the same player in the current game")
	var restored: Dictionary = (await packet(clients[voter].socket, "game", true, host.rules.revision)).payload
	# JSON floating-point text can round the paused value by ~1e-13 seconds.
	# A microsecond tolerance still rejects an advancing/reset paused clock.
	check(restored.secret == secret and restored.phase == "vote" and restored.vote_timer_started and restored.vote_remaining <= vote_clock + 0.000001 and absf(restored.remaining - clock) <= 0.000001 and not restored.paused, "Reconnect restores the same voting deadline and paused round time")
	await request(clients[voter], "vote", {"agree":false})
	check(host.rules.phase == "playing", "An authenticated No resumes spoken conversation")
	await request(clients[spy], "guess", {"location":host.rules.location})
	check(host.rules.phase == "finished" and host.rules.outcome.spy_wins, "The real spy socket can submit its one winning location guess")
	var profile: Dictionary = app.profile_store.get_profile(clients[spy].joined.player.id)
	check(app.profile_store.lifetime_points(profile) >= 4, "Host scoring reaches the existing profile API")
	var completed_round: int = host.rules.round_number
	await request(clients[0], "replay")
	await request(clients[1], "next")
	check(host.rules.phase == "finished" and host.rules.round_number == completed_round, "Real sockets cannot bypass host-only restart")
	host._replay()
	host.rules.anonymous_voting = false
	host.rules.tick(host.rules.duration)
	host._publish()
	var ballot: Dictionary = await request(clients[0], "final_vote", {"target":1})
	check(ballot.phase == "final_vote" and ballot.voting[1].voters.size() == 1 and int(ballot.voting[1].voters[0]) == 0 and host.voting_dialog.overlay.visible and not host.dossier.visible, "Final votes route to the live host popup with identified votes by default")
	clients[0].socket.close()
	for frame in 200:
		clients[0].socket.poll()
		await process_frame
		if host.rules.missing.has(0):
			break
	clients[0] = await join_player("Spyfall Network Agent 0", clients[0].joined.reconnect_token)
	var restored_ballot: Dictionary = (await packet(clients[0].socket, "game", true, host.rules.revision)).payload
	check(restored_ballot.phase == "final_vote" and restored_ballot.voted and not restored_ballot.can_vote and restored_ballot.voting[1].voters.size() == 1 and int(restored_ballot.voting[1].voters[0]) == 0, "Final-vote reconnect restores the same ballot and cannot vote twice")
	host.rules.anonymous_voting = true
	host._publish()
	var hidden_ballot: Dictionary = await request(clients[0], "sync")
	check(hidden_ballot.anonymous_voting and hidden_ballot.voting[1].count == 1 and hidden_ballot.voting[1].voters.is_empty(), "Anonymous socket payloads contain totals without voter identities")
	for seat in range(1, 4):
		await request(clients[seat], "final_vote", {"target":(seat + 1) % 4})
	check(host.rules.phase == "finished" and host.voting_dialog.overlay.visible and host.points_label.get_parsed_text().contains("+2 points"), "Voting transitions the same popup to team, points, spy and location results")
	var http := HTTPRequest.new()
	root.add_child(http)
	for asset in ["", "controller.js", "style.css", "thumbnail.svg", "art/dossier-title.svg", "art/spy-office.png", "background.json", "audio/countdown.wav", "audio/timer_up.wav", "audio/vote.wav", "audio/spy_win.wav", "audio/non_spies_win.wav"]:
		http.request("http://127.0.0.1:%d/game/spyfall/%s" % [app.lan_server.http_port, asset])
		var response: Array = await http.request_completed
		check(response[1] == 200, "Controller and artwork are available completely offline: " + asset)
	for asset in ["paper.svg", "clipboard.svg", "paper-clip.svg"]:
		http.request("http://127.0.0.1:%d/ui/playful/%s" % [app.lan_server.http_port, asset])
		var response: Array = await http.request_completed
		check(response[1] == 200, "Shared social artwork is served offline: " + asset)
	http.queue_free()
	host.return_to_lobby()
	await process_frame
	check(app.current_state == "game_menu" and app.active_game == null and app.lan_server.running and not app.lan_server.lobby_open, "Return navigation cancels Spyfall while preserving the launcher LAN session")
	check((await packet(clients[0].socket, "screen")).get("game_id", "missing") == "", "The SDK receives the normal return-to-games route")
	app._show_lobby()
	for seat in range(4, 8):
		clients.append(await join_player("Spyfall Network Agent %d" % seat))
		check(not clients[-1].joined.is_empty(), "Additional human joins after Back to Lobby")
	app._play_from_lobby()
	check(app._can_launch(module), "Eight human phones can launch")
	app._launch_game(module)
	await process_frame
	check(app.active_game.rules.players.size() == 8, "The eight-player game creates exactly eight human seats")
	app.active_game.return_to_lobby()
	await process_frame
	app._show_lobby()
	clients.append(await join_player("Spyfall Network Agent 8"))
	check(not app._can_launch(module), "Nine humans exceed the catalog limit")
	for client in clients:
		client.socket.close()
	app.lan_server.stop_server()
	clients.clear()
	app.queue_free()
	await process_frame
	print("Spyfall network: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
