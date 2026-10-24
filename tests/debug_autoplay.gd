extends SceneTree

class WaitingAdapter extends GameDebugAdapter:
	func step(_rng: RandomNumberGenerator) -> bool: return false

class CountingAdapter extends GameDebugAdapter:
	var value := 0
	func progress() -> String: return str(value)
	func step(_rng: RandomNumberGenerator) -> bool:
		value += 1
		return true

class InvalidCountsAdapter extends GameDebugAdapter:
	func player_counts(_manifest: Dictionary) -> Array: return [0, 17, 1, 2, 2, 3, "4"]

class FiniteAdapter extends CountingAdapter:
	func is_complete() -> bool: return value >= 1

var failures := 0
var checks := 0

func _init() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)

func _run() -> void:
	var roster := GameDebugRunner.players(16)
	var identities := {}
	var colors := {}
	for player: Dictionary in roster:
		identities[player.id] = true; colors[player.color] = true
	check(roster.size() == 16 and identities.size() == 16 and colors.size() == 16, "Sixteen distinct ephemeral identities and colors")
	check(roster[0].id != roster[15].id and roster[0].color != roster[15].color and not roster[0].has("reconnect_token"), "Distinct colors and no reconnect credentials")
	check(InvalidCountsAdapter.new().supported_counts({"modes":["multiplayer"], "min_players":2, "max_players":2}) == [2], "Adapters cannot exceed validated manifest limits")
	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new("res://.test_data/debug-autoplay/profiles.json")
	app.game_settings_store = GameSettingsStore.new("res://.test_data/debug-autoplay/preferences-%d" % OS.get_process_id())
	root.add_child(app)
	await process_frame
	var template: Dictionary = app.game_catalog._read_game("_Template").game
	var profile: Dictionary = app.profile_store.create_or_get_profile("Debug isolation").profile
	app.game_settings_store.save_settings(str(template.id), {"mode":0})
	var settings_path: String = app.game_settings_store._path(str(template.id))
	var saved_settings := FileAccess.get_file_as_string(settings_path)
	app.game_catalog.games = [template]
	app._show_settings("title")
	app._show_debug_setup()
	await process_frame
	var panel: GameDebugPanel = app.screen_root.get_child(0)
	check(panel.player_choice.item_count == 16 and not panel.start_button.disabled, "Module supplies selectable counts without phones")
	if DisplayServer.get_name() != "headless":
		for size in [Vector2i(1280, 720), Vector2i(390, 844), Vector2i(844, 390)]:
			await capture("setup", size)
	var before: String = JSON.stringify(app.profile_store.data)
	for count in [1, 16]:
		app._start_debug_game(template, count, 0.05, true)
		check(app.current_state == "debug_game" and app.active_game.session.debug_mode, "Debug context reaches template")
		check(app.active_game.session.players.size() == count and not app.lan_server.running, "Fake roster requires no live server")
		app.debug_runner.toggle_pause()
		for frame in 3: await process_frame
		check(app.active_game.debug_sample_turn == 0, "Pause bots prevents automatic inputs")
		app.debug_runner.step_once()
		check(app.active_game.debug_sample_turn == 1, "Step uses validated host input")
		if count == 16 and DisplayServer.get_name() != "headless":
			for size in [Vector2i(1280, 720), Vector2i(390, 844), Vector2i(844, 390)]:
				await capture("running", size)
		if count > 1: app.debug_runner.toggle_pause()
		var deadline := Time.get_ticks_msec() + 4000
		while app.debug_runner.state != "completed" and Time.get_ticks_msec() < deadline: await process_frame
		check(app.debug_runner.state == "completed" and app.active_game.debug_sample_turn == count, "Autoplay stops at one completed game")
		var actions: int = app.debug_runner.actions
		for frame in 5: await process_frame
		check(app.debug_runner.actions == actions, "Completion never triggers replay")
		var emitted := [0]
		app.active_game.points_awarded.connect(func(_id: String, _amount: int) -> void: emitted[0] += 1)
		app.active_game.result_reported.connect(func(_id: String, _won: bool) -> void: emitted[0] += 1)
		app.active_game.award_points(str(profile.id), 5)
		app.active_game.report_result(str(profile.id), true)
		app._on_points_awarded(str(profile.id), 5)
		app._on_result_reported(str(profile.id), true)
		check(emitted[0] == 0 and JSON.stringify(app.profile_store.data) == before, "Debug cannot alter saved standings")
		app.active_game.save_game_settings({"mode":1})
		check(app.active_game.load_game_settings({"mode":0}).mode == 1, "Debug preferences are in memory")
		check(FileAccess.get_file_as_string(settings_path) == saved_settings, "Debug leaves real game preferences untouched")
		app._restart_debug_game()
		check(app.debug_runner.actions == 0 and app.active_game.debug_sample_turn == 0, "Restart creates a fresh game")
		check(app.active_game.load_game_settings({"mode":0}).mode == 0, "Restart discards temporary edits")
		app._return_from_game()
		await process_frame
		check(app.current_state == "debug_setup" and app.active_game == null, "Stop returns cleanly to setup")
	# Unsupported modules remain usable normally and explain their missing hook.
	app.game_catalog.games = [dict_without_adapter(template)]
	app._show_debug_setup(); await process_frame
	panel = app.screen_root.get_child(0)
	check(panel.start_button.disabled and panel.notice.text.contains("host/debug.gd"), "Unsupported module is explicit")
	var host := BaseGame.new(); root.add_child(host)
	var driver := WaitingAdapter.new(); driver.game = host
	var runner := GameDebugRunner.new(); root.add_child(runner)
	runner.start(driver, 0.05); runner._process(31.0)
	check(runner.state == "stalled", "Stuck adapters stop with a useful state")
	runner.toggle_pause(); check(runner.state == "running", "A stalled run can be resumed")
	var counting := CountingAdapter.new(); counting.game = host
	runner.start(counting)
	runner.actions = runner.MAX_ACTIONS - 1
	runner._step()
	check(runner.state == "limit reached", "Endless legal play has a hard action limit")
	var finite := FiniteAdapter.new(); finite.game = host
	runner.start(finite); runner._step()
	finite.value = 0 # A module's explicit Play Again/Apply starts another game.
	runner._process(0.1)
	check(runner.state == "paused" and runner.actions == 0 and finite.value == 0, "Explicit replay rearms bots without playing before Resume")
	runner.stop(); check(runner.adapter == null, "Stopping drops game references")
	app._enter_lobby()
	var admission: Array = app.lan_server.get_admitted_players().duplicate(true)
	app._start_debug_game(template, 2, 1.0, true)
	app.lan_server.controller_message.emit("debug-player-01", {"action":"debug_sample", "revision":0})
	check(app.active_game.debug_sample_turn == 0 and app.lan_server.active_game_id.is_empty(), "Live LAN inputs and routes are isolated from debug")
	check(app.lan_server.get_admitted_players() == admission and app.lan_server.get_players().is_empty(), "Debug never adds fake players to the lobby")
	app._return_from_game(); app.lan_server.stop_server()
	var solo := template.duplicate(true); solo.modes = ["singleplayer"]
	app._start_debug_game(solo, 1, 0.05, true)
	check(app.active_game.session.players.is_empty() and app.active_game.session.solo_profile.id == "debug-player-01", "Singleplayer-only modules receive a temporary solo identity")
	app._return_from_game()
	host.queue_free(); runner.queue_free()
	app.queue_free(); await create_timer(0.15).timeout
	print("Debug autoplay: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func dict_without_adapter(template: Dictionary) -> Dictionary:
	var missing := template.duplicate(true)
	missing.folder = "res://tests/fixtures/Games/valid-game"
	return missing

func capture(label: String, dimensions: Vector2i) -> void:
	root.min_size = Vector2i.ONE
	root.content_scale_size = dimensions; root.size = dimensions
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	var folder := "res://.test_data/debug-autoplay/"
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder + "%s-%dx%d.png" % [label, dimensions.x, dimensions.y])
