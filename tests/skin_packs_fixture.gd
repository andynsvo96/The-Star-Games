extends SceneTree

# Synthetic module: the public suite does not require any local playable games.
var checks := 0
var failures := 0
var fixture := "res://.test_data/skin-fixture-%d" % Time.get_ticks_usec()
var definitions := fixture.path_join("definitions")
var runtime := fixture.path_join("runtime")
var server: LanServer


func _init() -> void: call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)


func write(path: String, contents: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents); file.close()


func request(path: String) -> Dictionary:
	var http := HTTPClient.new()
	http.connect_to_host("127.0.0.1", server.http_port)
	for frame in 600:
		http.poll()
		if http.get_status() == HTTPClient.STATUS_CONNECTED: break
		await process_frame
	http.request(HTTPClient.METHOD_GET, path, PackedStringArray())
	for frame in 600:
		http.poll()
		if http.has_response(): break
		await process_frame
	var status := http.get_response_code()
	var headers := "\n".join(http.get_response_headers())
	var body := PackedByteArray()
	for frame in 600:
		http.poll(); body.append_array(http.read_response_body_chunk())
		if http.get_status() != HTTPClient.STATUS_BODY: break
		await process_frame
	http.close()
	return {"status": status, "body": body, "headers": headers}


func _run() -> void:
	var module := definitions.path_join("skin-fixture")
	var art := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><rect width="24" height="24" fill="#112233"/></svg>'
	var slots := [
		{"id":"background", "label":"Background", "group":"Backgrounds", "kind":"background", "path":"Games/skin-fixture/art/background.svg"},
		{"id":"piece", "label":"Piece", "group":"Artwork", "kind":"image", "path":"Games/skin-fixture/art/piece.svg"},
		{"id":"shared", "label":"Shared chip", "group":"Artwork", "kind":"image", "path":"Games/skin-shared/art/chip.svg"},
		{"id":"untouched", "label":"Inherited piece", "group":"Artwork", "kind":"image", "path":"Games/skin-fixture/art/untouched.svg"}
	]
	write(module.path_join("theme-slots.json"), JSON.stringify({"schema_version":1,"asset_sources":["skin-shared"],"preview_kind":"assets","slots":slots}))
	write(module.path_join("themes/default/theme.json"), JSON.stringify({"schema_version":1,"id":"default","name":"Default","assets":{},"labels":{}}))
	for path in ["Games/skin-fixture/art/piece.svg", "Games/skin-fixture/art/background.svg", "Games/skin-shared/art/chip.svg", "Games/skin-fixture/art/untouched.svg"]:
		write(runtime.path_join(path), art)
	write(module.path_join("art/background.svg"), art)
	write(module.path_join("thumbnail.svg"), art)
	write(module.path_join("controller/index.html"), '<!doctype html><html><body>Fixture</body></html>')
	write(module.path_join("host/main.gd"), 'extends BaseGame\nvar piece := RuntimeAssets.texture("res://Games/skin-fixture/art/piece.svg")\nfunc start_game() -> void:\n\tbroadcast_state({"type":"state"})\n')
	write(module.path_join("host/main.tscn"), '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="%s/host/main.gd" id="1"]\n[node name="SkinFixture" type="Control"]\nscript = ExtResource("1")\n' % module)
	write(module.path_join("game.json"), JSON.stringify({"schema_version":1,"id":"skin-fixture","title":"Skin fixture","description":"Synthetic skin test","version":"1.0.0","thumbnail":"thumbnail.svg","background":"art/background","host_scene":"host/main.tscn","controller_entry":"controller/index.html","min_players":1,"max_players":16,"modes":["singleplayer","multiplayer"]}))
	RuntimeAssets.root_override = ProjectSettings.globalize_path(runtime); RuntimeAssets.refresh()
	var manager := ThemePacks.new("skin-fixture", definitions)
	check(manager.slots.size() == 4 and manager.list_packs().size() == 1, "Trusted module and declared shared sources provide grouped slots")
	var original_hash := FileAccess.get_sha256(runtime.path_join("Games/skin-fixture/art/piece.svg"))
	manager.pin("default")
	check(RuntimeAssets.texture("res://Games/skin-fixture/art/piece.svg").get_width() == 24, "Default retains current canonical artwork")
	var created := manager.duplicate_pack("default", "Blue skin")
	check(created.ok, "Default can be duplicated into a separate skin")
	var pack: Dictionary = created.get("pack", {}).duplicate(true)
	var image := Image.create(44, 60, false, Image.FORMAT_RGBA8); image.fill(Color.BLUE); image.save_png(fixture.path_join("custom.png"))
	for id in ["piece", "background", "shared"]: check(manager.stage_media(pack, id, fixture.path_join("custom.png")).ok, "Prepare %s artwork without activating it" % id)
	check(RuntimeAssets.texture("res://Games/skin-fixture/art/piece.svg").get_width() == 24, "Draft preparation leaves the active game unchanged")
	check(manager.save_pack(pack).ok, "Save a validated cosmetic skin")
	check(not manager.save_pack(manager.load_pack("default")).ok, "The built-in default is protected")
	var invalid := pack.duplicate(true); invalid.labels["unknown-slot"] = "Unknown label"
	check(not manager.save_pack(invalid).ok, "Skin labels cannot introduce undeclared slots")
	var store := GameSettingsStore.new(fixture.path_join("settings"))
	store.save_settings("skin-fixture", {"difficulty":2})
	var editor := preload("res://scripts/theme_pack_editor.gd").new()
	editor.settings_store = store; root.add_child(editor)
	editor.manager = manager; editor._load_theme("blue-skin"); editor._use_skin()
	check(store.load_settings("skin-fixture", {"theme":"default","difficulty":0}) == {"theme":"blue-skin","difficulty":2}, "Use skin persists selection without changing other preferences")
	check(ThemePacks.snapshot("skin-fixture").id == "default", "Selecting a skin waits until the next launch")
	var app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new(fixture.path_join("profiles.json")); app.game_settings_store = store
	app.game_catalog = GameCatalog.new(definitions); root.add_child(app)
	app.profile_store.data.settings.reduced_motion = true
	app._launch_game(app.game_catalog.find_game("skin-fixture"))
	check(app.active_game.piece.get_width() == 44, "Launcher pins the saved skin before module member initializers load textures")
	check(RuntimeAssets.texture("res://Games/skin-shared/art/chip.svg").get_width() == 44, "A variant resolves declared shared art through its independent skin")
	check(RuntimeAssets.texture("res://Games/skin-fixture/art/untouched.svg").get_width() == 24, "Missing custom slots inherit their unchanged default media")
	var payload := {"type":"state", "hand":["private-card"]}
	var published: Array = []; var delivered: Array = []
	app.active_game.controller_state_updated.connect(func(value: Dictionary) -> void: published.append(value))
	app.active_game.controller_private_state_updated.connect(func(_player: String, value: Dictionary) -> void: delivered.append(value))
	app.active_game.broadcast_state({"type":"state"}); app.active_game.send_state("phone", payload)
	var public_view: Dictionary = published[0]
	var private_view: Dictionary = delivered[0]
	check(public_view.theme.id == "blue-skin" and not public_view.has("hand") and not public_view.theme.has("assets"), "Public skin metadata contains no private state or filesystem paths")
	check(private_view.hand == payload.hand and not payload.has("theme"), "Skin metadata preserves private snapshots without mutating game state")
	# HTTP uses the same canonical module root as an ordinary installed game;
	# this fixture keeps only its host scene/definitions outside that directory.
	app.game_catalog.games[0].folder = "res://Games/skin-fixture"
	server = app.lan_server; server.start_server()
	var response: Dictionary = await request("/game/skin-fixture/art/piece.svg")
	check(response.status == 200 and response.body.slice(0,8) == PackedByteArray([137,80,78,71,13,10,26,10]) and response.headers.contains("image/png"), "Actual LAN routes serve custom media through canonical URLs and its real MIME type")
	var metadata: Dictionary = await request("/game/skin-fixture/background.json")
	var background: Variant = JSON.parse_string(metadata.body.get_string_from_utf8())
	check(background is Dictionary and str(background.get("image", "")).contains("/themes/blue-skin/"), "Shared background metadata resolves the pinned skin")
	server.stop_server(); app._return_from_game()
	check(ThemePacks.snapshot("skin-fixture").is_empty() and RuntimeAssets.texture("res://Games/skin-shared/art/chip.svg").get_width() == 24, "Leaving clears both owned and shared skin mappings")
	check(FileAccess.get_sha256(runtime.path_join("Games/skin-fixture/art/piece.svg")) == original_hash, "Custom skins never overwrite Default's original artwork")
	var pinned := manager.pin("blue-skin"); var revision: String = pinned.revision
	var saved := pack.duplicate(true); saved.name = "Edited blue skin"; manager.save_pack(saved)
	check(ThemePacks.snapshot("skin-fixture").revision == revision, "Saving an edit leaves a running skin revision pinned")
	var file := FileAccess.open(runtime.path_join(str(pack.assets.piece)), FileAccess.WRITE); file.store_string("corrupt"); file.close()
	check(manager.pin("blue-skin").id == "default", "Missing or corrupt skin media falls back to Default")
	ThemePacks.unpin("skin-fixture"); editor.queue_free(); app.queue_free()
	for frame in 6: await process_frame
	RuntimeAssets.root_override = ""; RuntimeAssets.refresh()
	print("Skin framework: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
