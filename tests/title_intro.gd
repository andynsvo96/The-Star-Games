extends SceneTree

var failures := 0
var checks := 0
var rendered := false


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func make_app(reduced: bool) -> Control:
	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new("res://.test_data/title_intro_%s.json" % reduced)
	app.profile_store.data.settings.reduced_motion = reduced
	app.profile_store.save_data()
	root.add_child(app)
	return app


func capture(filename: String) -> void:
	if rendered:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.test_data/title-intro/" + filename + ".png")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.test_data/title-intro")
	rendered = DisplayServer.get_name() != "headless"
	var app = make_app(false)
	var intro: Tween = app.title_intro
	check(intro != null, "Launch starts a title introduction")
	intro.pause()
	await process_frame
	await process_frame
	var play: Button = app.screen_root.find_children("*", "Button", true, false)[0]
	check(not play.disabled and play.has_focus(), "PLAY remains available to mouse and keyboard during the introduction")
	intro.custom_step(0.15)
	check(app.title_background.modulate.a > 0.0 and app.title_background.modulate.a < 1.0, "Artwork fades into view")
	check(app.title_background.scale.x > 1.0, "Artwork starts closer and eases into its framing")
	await capture("01-reveal")
	intro.custom_step(0.4)
	check(play.get_parent().modulate.a > 0.2 and play.get_parent().modulate.a < 1.0, "PLAY reveals after the artwork")
	await capture("02-play-reveal")
	root.size = Vector2i(720, 1280)
	root.content_scale_size = Vector2i(720, 1280)
	await process_frame
	await process_frame
	check(app.title_background.get_global_rect().get_center().distance_to(app.size * 0.5) < 2.0, "Resizing during the zoom keeps the artwork centered")
	check(play.get_global_rect().get_center().distance_to(app.size * Vector2(0.5, 0.75)) < 2.0, "PLAY stays centered in portrait during the reveal")
	await capture("03-portrait-reveal")
	intro.custom_step(1.0)
	check(app.title_intro == null, "Introduction finishes without a lingering tween")
	check(app.title_background.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(app.title_background.modulate.a, 1.0), "Artwork settles to its original full-screen framing")
	check(is_equal_approx(play.get_parent().modulate.a, 1.0), "PLAY settles fully visible")
	await capture("04-portrait-settled")
	app._show_settings("title")
	app._return_from_settings()
	check(app.title_intro == null and is_equal_approx(app.title_background.modulate.a, 1.0), "Returning from settings does not repeat the introduction")
	app.queue_free()
	await process_frame
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	app = make_app(false)
	intro = app.title_intro
	intro.pause()
	intro.custom_step(0.2)
	await process_frame
	play = app.screen_root.find_children("*", "Button", true, false)[0]
	play.pressed.emit()
	check(app.title_intro == null and not intro.is_valid(), "Pressing PLAY early cancels the entrance before the lobby transition")
	await create_timer(0.65).timeout
	check(app.current_state == "lobby" and app.lan_server.running, "Early PLAY reaches a live lobby")
	check(app.screen_root.position.is_equal_approx(Vector2.ZERO), "Cancelled entrance leaves lobby layout centered")
	app._leave_lobby()
	check(app.title_intro == null and app.title_background.scale.is_equal_approx(Vector2.ONE), "Returning from the lobby restores the settled splash")
	await capture("05-landscape-settled")
	app.queue_free()
	await process_frame
	app = make_app(false)
	intro = app.title_intro
	app._show_settings("title")
	check(app.title_intro == null and not intro.is_valid(), "Navigation during the introduction cancels its tween")
	app._return_from_settings()
	check(app.title_background.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(app.title_background.modulate.a, 1.0), "Interrupted introduction cannot leave the returned title enlarged or dimmed")
	app.queue_free()
	await process_frame
	app = make_app(true)
	await process_frame
	check(app.title_intro == null, "Saved reduced motion skips the introduction on launch")
	check(app.title_background.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(app.title_background.modulate.a, 1.0), "Reduced motion immediately shows the final artwork")
	play = app.screen_root.find_children("*", "Button", true, false)[0]
	check(not play.disabled and is_equal_approx(play.get_parent().modulate.a, 1.0), "Reduced motion immediately shows an active PLAY button")
	await capture("06-reduced-motion")
	app._enter_lobby()
	check(app.current_state == "lobby" and app.title_transition == null, "Reduced-motion PLAY enters the lobby immediately")
	app._leave_lobby()
	app.queue_free()
	await process_frame
	print("Title introduction: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
