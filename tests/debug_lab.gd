extends SceneTree

class InputProbe extends Control:
	var input_count := 0
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed: input_count += 1

var checks := 0
var failures := 0
var visibility_events := 0
const OUTPUT := "res://.test_data/debug-lab-checks/"


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in 8: await process_frame


func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + name + ".png")


func _run() -> void:
	if OS.get_cmdline_user_args().has("--serve-debug-lab"):
		await _serve_fixture()
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new(OUTPUT + "profiles.json")
	app.game_settings_store = preload("res://tests/game_settings_fixture.gd").new()
	root.add_child(app)
	await settle()
	app.profile_store.data.settings.reduced_motion = true
	app._show_settings("title")
	app._toggle_debug_lab()
	check(app.debug_lab.opened and not app.lan_server.running, "Host inspector opens before a server is running")
	app._toggle_debug_lab()
	check(not app.debug_lab.opened, "F8 toggle closes inspector")
	app._show_title()
	app._enter_lobby()
	app._play_from_lobby()
	# The public template is the only game dependency in this test.
	var game := {"id":"replace-with-game-id", "host_scene_path":"res://Games/_Template/host/main.tscn", "folder":"res://Games/_Template", "modes":["singleplayer"], "min_players":1, "max_players":16}
	app._launch_game(game)
	await settle()
	var host: BaseGame = app.active_game
	check(is_instance_valid(host), "Template launches through the actual app")
	var before: Dictionary = app.profile_store.data.duplicate(true)
	var fixture := VBoxContainer.new()
	fixture.name = "HiddenFixture"
	fixture.position = Vector2(500, 220)
	fixture.custom_minimum_size = Vector2(280, 140)
	host.add_child(fixture)
	var button := Button.new()
	button.name = "HiddenDecision"
	button.text = "Literal <player> decision"
	fixture.add_child(button)
	fixture.hide()
	fixture.visibility_changed.connect(func() -> void: visibility_events += 1)
	var probe := InputProbe.new()
	host.add_child(probe)
	var lab = app.debug_lab
	app._toggle_debug_lab()
	check(not probe.is_processing_input(), "Inspector suspends game raw input callbacks as well as GUI interaction")
	check(lab.target == host and lab.tree.get_root().get_child_count() > 20, "Inspector lists the template and its hidden components")
	lab.search.text = "HiddenDecision"
	lab.refresh()
	check(lab.tree.get_root().get_child_count() == 1, "Filter finds hidden descendants by stable path")
	lab.tree.get_root().get_first_child().select(0)
	lab._inspect_selected()
	check(lab.selected == button and lab.details.text.contains("hidden"), "Hidden reason and selected geometry are available")
	lab._mark_checked()
	check(lab.count_label.text.contains("1 marked checked"), "Manual review coverage is separate from element visibility")
	lab._preview_selected()
	check(fixture.visible and button.is_visible_in_tree() and not lab.panel.visible, "Preview reveals ancestors and moves inspector aside")
	check(visibility_events == 0, "Visibility preview does not emit game control signals")
	lab._end_preview()
	check(not fixture.visible and lab.panel.visible, "Returning to inspector restores original visibility")
	check(visibility_events == 0 and before == app.profile_store.data, "Inspection preserves profile data and emits no visibility callbacks")
	check(lab.scenarios.size() == 1, "Template registers a named host UI scenario")
	lab._preview_scenario()
	check(host.phase_dialog.overlay.visible, "Named scenario previews the shared result dialog")
	await settle()
	await capture("host-result-preview")
	lab.close()
	check(probe.is_processing_input(), "Closing restores a game's original raw input policy")
	check(not host.phase_dialog.overlay.visible, "Closing restores a scenario's hidden UI")
	for view in [["desktop",1280,720],["portrait",390,844],["landscape",844,390],["short",568,320]]:
		root.min_size = Vector2i.ONE
		root.content_scale_size = Vector2i(view[1], view[2])
		root.size = root.content_scale_size
		lab.open_for(host)
		lab.search.clear()
		await settle()
		check(root.get_visible_rect().encloses(lab.panel.get_global_rect()), "%s inspector fits with reachable scrolling and Close" % view[0])
		check(lab.panel.get_global_rect().encloses(lab.panel.find_children("*", "Button", true, false)[0].get_global_rect()), "%s Close stays inside inspector" % view[0])
		await capture("host-" + str(view[0]))
		lab.close()
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	lab.open_for(host)
	lab.selected = button
	lab._preview_selected()
	app._return_from_game()
	check(not lab.opened and not fixture.visible and app.current_state == "game_menu" and app.lan_server.running, "Game navigation restores preview and preserves existing LAN server")
	await settle()
	var request := HTTPRequest.new()
	root.add_child(request)
	for route in [["debug.html","Debug Lab"],["debug-lab.css","#device-frame"],["debug-lab.js","StarGamesDebugLab"]]:
		request.request("http://127.0.0.1:%d/%s" % [app.lan_server.http_port, route[0]])
		var response: Array = await request.request_completed
		check(response[1] == 200 and response[3].get_string_from_utf8().contains(route[1]), "Debug asset served through actual LAN route: " + route[0])
	request.queue_free()
	app._leave_lobby()
	app.queue_free()
	await settle()
	print("Debug Lab: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _serve_fixture() -> void:
	var folder := "res://.test_data/debug-lab-lan"
	DirAccess.make_dir_recursive_absolute(folder)
	var store := ProfileStore.new(folder + "/profiles.json")
	store.load_data()
	var catalog := GameCatalog.new()
	catalog.games = [{"id":"debug-fixture", "folder":folder, "controller_entry":"index.html"}, {"id":"replace-with-game-id", "folder":"res://Games/_Template", "controller_entry":"controller/index.html", "private_paths":["host"]}]
	var server := LanServer.new()
	root.add_child(server)
	server.configure(store, catalog)
	if not server.start_server():
		quit(1)
		return
	server.set_active_game("replace-with-game-id")
	var port := FileAccess.open(folder + "/port.json", FileAccess.WRITE)
	port.store_string(JSON.stringify({"port":server.http_port}))
	port.close()
	var deadline := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < deadline and not FileAccess.file_exists(folder + "/stop"):
		await create_timer(0.1).timeout
	server.stop_server()
	server.queue_free()
	await process_frame
	quit()
