extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new("res://.test_data/host_avatar.json")
	root.add_child(app)
	await process_frame
	app.profile_store.data["settings"]["reduced_motion"] = true
	app._enter_lobby()
	app.profile_store.data["settings"]["reduced_motion"] = false
	var server: LanServer = app.lan_server
	server.active_players["preview"] = {"id": "preview", "display_name": "Animation preview", "color": LanServer.PLAYER_COLORS[2], "pose": 0, "lifetime_points": 0}
	server._broadcast_roster()
	await create_timer(0.8).timeout
	var avatar: TextureRect = app.lobby_avatars["preview"]
	assert(avatar.scale.is_equal_approx(Vector2.ONE))
	assert(server.change_player_color("preview", LanServer.PLAYER_COLORS[4]))
	await create_timer(0.1).timeout
	assert(not avatar.scale.is_equal_approx(Vector2.ONE))
	assert(not is_zero_approx(avatar.rotation))
	assert(avatar.pivot_offset.is_equal_approx(avatar.size * 0.5))
	var tween: Tween = avatar.get_meta("avatar_tween")
	server._broadcast_roster()
	await process_frame
	assert(app.lobby_avatars["preview"] == avatar)
	assert(avatar.get_meta("avatar_tween") == tween and tween.is_running())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.test_data/host-avatar-moving.png")
	assert(server.change_player_color("preview", LanServer.PLAYER_COLORS[3]))
	await create_timer(0.8).timeout
	assert(avatar.scale.is_equal_approx(Vector2.ONE) and is_zero_approx(avatar.rotation))
	assert(avatar.modulate == Color(LanServer.PLAYER_COLORS[3]))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.test_data/host-avatar-settled.png")
	app.profile_store.data["settings"]["reduced_motion"] = true
	assert(server.change_player_color("preview", LanServer.PLAYER_COLORS[5]))
	assert(avatar.scale == Vector2.ONE and avatar.rotation == 0.0)
	assert(avatar.modulate == Color(LanServer.PLAYER_COLORS[5]))
	server.kick_player("preview")
	await process_frame
	assert(app.lobby_avatars.is_empty() and app.avatar_states.is_empty())
	app._leave_lobby()
	await process_frame
	print("PASS: host animation survives layout and roster refresh, rapid changes settle, reduced motion and removal")
	quit()
