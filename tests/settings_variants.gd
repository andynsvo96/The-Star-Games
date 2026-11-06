extends SceneTree

# Synthetic modes exercise the launcher without any installed playable modules.
var checks := 0
var failures := 0
var folder := "res://.test_data/settings-variants-%d" % Time.get_ticks_usec()
var app: Control


class FailingSettings extends GameSettingsStore:
	func save_settings(_id: String, _values: Dictionary) -> bool:
		last_error = "Expected fixture save failure"
		return false


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func write(path: String, contents: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).store_string(contents)


func message(socket: WebSocketPeer, type: String, id := "*") -> Dictionary:
	for frame in 600:
		socket.poll()
		while socket.get_available_packet_count() > 0:
			var packet: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
			if packet is Dictionary and packet.get("type") == type and (id == "*" or packet.get("game_id") == id): return packet
		await process_frame
	return {}


func join_phone(name: String, token := "") -> Dictionary:
	var socket := WebSocketPeer.new()
	socket.connect_to_url("ws://127.0.0.1:%d/" % app.lan_server.websocket_port)
	await message(socket, "hello")
	socket.send_text(JSON.stringify({"type":"join", "name":name, "reconnect_token":token}))
	return {"socket":socket, "joined":await message(socket, "joined")}


func _run() -> void:
	var source := "extends BaseGame\nvar screen: GameScreen\nvar choice: OptionButton\nvar settings_button: Button\nfunc _ready() -> void:\n\tscreen = GameScreen.new()\n\tadd_child(screen)\n\tscreen.configure(\"Fixture\")\n\tscreen.use_playful_style(get_script().resource_path.get_base_dir().get_base_dir().path_join(\"art/background\"))\n\tvar body := screen.add_corner_details([\"SETTINGS\"], Callable(), false, false, false, true, true)[0]\n\tsettings_button = body.get_meta(\"toggle_button\")\n\tchoice = screen.add_choice_control(body, \"GAME MODE\", [])\nfunc initialize_session(context: GameSessionContext) -> void:\n\tsuper.initialize_session(context)\n\tconfigure_game_mode_choice(choice, settings_button)\nfunc start_game() -> void:\n\tbroadcast_state({\"mode\": session.game_id})\nfunc shutdown_game() -> void:\n\tsession.collection_state[session.game_id] = true\n\tscreen.background_media.set_active(false)\n"
	var art := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><rect width="24" height="24" fill="#345678"/></svg>'
	for id in ["variant-pack", "variant-first", "variant-second", "plain-pack"]:
		var module := folder.path_join(id)
		write(module.path_join("host/main.gd"), source)
		write(module.path_join("host/main.tscn"), '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="%s/host/main.gd" id="1"]\n[node name="Fixture" type="Control"]\nscript = ExtResource("1")\n' % module)
		write(module.path_join("controller/index.html"), "<!doctype html><html><body>Fixture</body></html>")
		write(module.path_join("thumbnail.svg"), art)
		write(module.path_join("art/background.svg"), art)
		var manifest := {"schema_version":1, "id":id, "title":id, "description":"Synthetic variant", "version":"1.0.0", "thumbnail":"thumbnail.svg", "background":"art/background", "host_scene":"host/main.tscn", "controller_entry":"controller/index.html", "min_players":1, "max_players":2 if id == "variant-first" else 6, "modes":["singleplayer","multiplayer"]}
		if id in ["variant-pack", "plain-pack"]:
			manifest.game_choices = ["variant-first", "variant-second"]
			if id == "variant-pack": manifest.settings_variants = true
		write(module.path_join("game.json"), JSON.stringify(manifest))
	var catalog := GameCatalog.new(folder)
	catalog.scan()
	check(catalog.games.size() == 4 and catalog.menu_games().size() == 2, "Modes validate independently and share their menu entry")
	var manifest_path := folder.path_join("variant-first/game.json")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	manifest.settings_variants = true
	write(manifest_path, JSON.stringify(manifest))
	check(not catalog._read_game("variant-first").ok, "Settings variants require declared children")
	manifest.erase("settings_variants")
	write(manifest_path, JSON.stringify(manifest))
	var pack_path := folder.path_join("variant-pack/game.json")
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pack_path))
	for invalid in [1, "true", null]:
		pack.settings_variants = invalid
		write(pack_path, JSON.stringify(pack))
		check(not catalog._read_game("variant-pack").ok, "Settings variants reject malformed flags")
	pack.settings_variants = true
	write(pack_path, JSON.stringify(pack))
	app = load("res://Main.tscn").instantiate()
	app.game_catalog = catalog
	app.profile_store = ProfileStore.new(folder.path_join("profiles.json"))
	app.game_settings_store = GameSettingsStore.new(folder.path_join("preferences"))
	root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._enter_lobby()
	var peers: Array = [await join_phone("First"), await join_phone("Second")]
	check(peers.all(func(peer: Dictionary) -> bool: return not peer.joined.is_empty()), "Real phone identities join")
	app._play_from_lobby()
	var collection: Dictionary = catalog.find_game("variant-pack")
	app._launch_game(collection)
	check(app.active_game_id == "variant-first" and app.active_collection_id == "variant-pack", "First entry opens a playable mode directly")
	check(app.active_game.choice.item_count == 2 and app.active_game.choice.selected == 0, "Host Settings contains the validated modes and current selection")
	check(not app.active_game.settings_button.button_pressed, "Initial entry does not request an open Settings view")
	check((await message(peers[0].socket, "screen", "variant-first")).get("path") == "/game/variant-first/", "SDK routes phones straight to the active mode")
	var original: BaseGame = app.active_game
	original.game_selected.emit("variant-first")
	original.game_selected.emit("forged")
	check(app.active_game == original, "Same and undeclared modes cannot restart a game")
	var preferences: GameSettingsStore = app.game_settings_store
	app.game_settings_store = FailingSettings.new()
	original.choice.item_selected.emit(1)
	check(app.active_game == original and original.choice.selected == 0, "Failed preference writes preserve the current board and selector")
	app.game_settings_store = preferences
	original.choice.item_selected.emit(1)
	check(app.active_game_id == "variant-second" and original.is_queued_for_deletion(), "Selecting a mode replaces and shuts down the previous game")
	check(app.active_game.session.open_game_settings and app.active_game.settings_button.button_pressed, "Settings-variant transitions open the destination Settings before starting")
	check(app.active_game.session.collection_state.get("variant-first", false), "Transient module summaries survive mode changes")
	check(app.game_settings_store.load_settings("variant-pack", {"gamemode":""}).gamemode == "variant-second", "Accepted mode persists under the parent ID")
	check((await message(peers[0].socket, "game", "variant-second")).payload.mode == "variant-second", "New mode publishes through the existing LAN connection")
	peers[1].socket.close()
	for frame in 180:
		peers[1].socket.poll()
		await process_frame
		if app.lan_server.get_players().size() == 1: break
	original = app.active_game
	original.game_selected.emit("variant-first")
	check(app.active_game == original and app.collection_roster.size() == 2, "Disconnected identities remain admitted and block switching")
	var fresh := await join_phone("Second", peers[1].joined.reconnect_token)
	check(fresh.joined.get("game_id") == "variant-second" and fresh.joined.player.id == peers[1].joined.player.id, "Refresh restores the selected mode and identity")
	peers[1] = fresh
	app.active_game.return_to_lobby()
	await process_frame
	check(app.active_game == null and app.current_state == "game_menu" and app.collection_state.is_empty() and app.lan_server.running, "Back skips the chooser, clears transient summaries and retains LAN")
	app._launch_game(collection)
	check(app.active_game_id == "variant-second" and app.active_game.session.collection_state.is_empty(), "Re-entry restores the remembered mode with a fresh session")
	check(not app.active_game.session.open_game_settings and not app.active_game.settings_button.button_pressed, "Returning from Games clears the transient Settings request")
	app.active_game.return_to_lobby()
	await process_frame
	app.game_settings_store.save_settings("variant-pack", {"gamemode":"missing"})
	app._launch_game(collection)
	check(app.active_game_id == "variant-first", "Unknown saved modes fall back safely")
	app.active_game.return_to_lobby()
	await process_frame
	app.game_settings_store.save_settings("variant-pack", {"gamemode":"variant-first"})
	for count in range(3, 7):
		app._show_lobby()
		peers.append(await join_phone("Extra %d" % count))
		check(not peers.back().joined.is_empty(), "Phone %d joins before the party starts" % count)
		app._play_from_lobby()
		app._launch_game(collection)
		check(app.active_game_id == "variant-second" and app.active_game.session.players.size() == count, "%d connected players automatically open their eligible mode" % count)
		check(app.active_game.choice.is_item_disabled(0), "Two-player mode stays disabled with %d connected players" % count)
		original = app.active_game
		original.game_selected.emit("variant-first")
		check(app.active_game == original, "Mode requests cannot bypass the %d-player party" % count)
		check(app.game_settings_store.load_settings("variant-pack", {"gamemode":""}).gamemode == "variant-first", "Automatic selection preserves saved mode intent for %d players" % count)
		app.active_game.return_to_lobby()
		await process_frame
	app._launch_game(catalog.find_game("plain-pack"))
	check(app.active_game_id == "plain-pack", "Existing collections retain their chooser")
	app.active_game.game_selected.emit("variant-second")
	app.active_game.return_to_lobby()
	await process_frame
	check(app.active_game_id == "plain-pack", "Existing child Back still returns to its chooser")
	app.active_game.return_to_lobby()
	for peer in peers: peer.socket.close()
	app.lan_server.stop_server()
	app.queue_free()
	for frame in 8: await process_frame
	print("Settings variants: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
