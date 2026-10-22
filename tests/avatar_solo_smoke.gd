extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new("res://.test_data/avatar_solo.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	await process_frame
	app.profile_store.data["settings"]["reduced_motion"] = true
	app._enter_lobby()
	assert(app.screen_root.find_children("*", "OptionButton", true, false).is_empty())
	assert(app._can_launch({"modes": ["singleplayer"], "min_players": 1, "max_players": 1}))
	assert(app._host_solo_profile()["display_name"] == app.profile_store.get_settings()["host_name"])
	var result: Dictionary = app.profile_store.create_or_get_profile("Solo regression")
	var id: String = result["profile"]["id"]
	app.active_game_id = "regression"
	var before: Dictionary = app.profile_store.get_profile(id).duplicate(true)
	app._on_points_awarded(id, 100)
	app._on_result_reported(id, true)
	app._on_result_reported(id, false)
	assert(app.profile_store.get_profile(id) == before)
	app.active_game_is_party = true
	app._on_points_awarded(id, 100)
	assert(app.profile_store.lifetime_points(app.profile_store.get_profile(id)) == app.profile_store.lifetime_points(before) + 100)
	app._on_result_reported(id, true)
	assert(app.profile_store.get_profile(id)["wins"] == int(before.get("wins", 0)) + 1)
	app._launch_game({"id": "solo-test", "host_scene_path": "res://Games/_Template/host/main.tscn", "modes": ["singleplayer"], "min_players": 1, "max_players": 1})
	assert(app.active_game != null and not app.active_game_is_party)
	assert(app.active_game.session.players.is_empty())
	assert(app.active_game.session.solo_profile["id"] == "local-host")
	assert(app.lan_server.active_game_id.is_empty())
	app._return_from_game()
	app._show_lobby()
	var server: LanServer = app.lan_server
	server.active_players[id] = {"id": id, "display_name": "Pose test", "color": LanServer.PLAYER_COLORS[0], "pose": 0, "lifetime_points": 0}
	for i in 60:
		var previous: int = server.active_players[id]["pose"]
		assert(server.change_player_color(id, LanServer.PLAYER_COLORS[1 + i % 2]))
		var pose: int = server.active_players[id]["pose"]
		assert(pose != previous and pose >= 0 and pose < 6)
		assert(server._public_player(server.active_players[id])["pose"] == pose)
		assert(server.change_player_color(id, server.active_players[id]["color"]))
		assert(server.active_players[id]["pose"] == pose)
		assert(not server.change_player_color(id, "#123456"))
		assert(server.active_players[id]["pose"] == pose)
	app._leave_lobby()
	await process_frame
	print("PASS: automatic host solo identity, solo stats excluded, party awards preserved, six nonrepeating poses, rejected/no-op colors preserve pose")
	quit()
