extends SceneTree

# Synthetic optional mode installation: no playable local content is required.
var checks := 0
var failures := 0
var fixture := "res://.test_data/nested-modes-%d" % Time.get_ticks_usec()


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


func module(relative: String, id: String, title: String) -> Dictionary:
	var folder := fixture.path_join(relative)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/Games/valid-game/game.json"))
	manifest.id = id
	manifest.title = title
	manifest["private_paths"] = ["host"]
	for path in ["host/main.tscn", "controller/index.html", "thumbnail.svg"]:
		write(folder.path_join(path), FileAccess.get_file_as_string("res://tests/fixtures/Games/valid-game/" + path))
	write(folder.path_join("host/main.gd"), "extends BaseGame\n")
	write(folder.path_join("host/main.tscn"), '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="%s/host/main.gd" id="1"]\n[node name="Fixture" type="Control"]\nscript = ExtResource("1")\n' % folder)
	write(folder.path_join("game.json"), JSON.stringify(manifest))
	return manifest


func _run() -> void:
	var first := module("family/first", "mode-first", "First mode")
	module("family/second", "mode-second", "Second mode")
	var family := module("family", "mode-family", "Family")
	family.game_choices = [{"id":"mode-first", "title":"First mode", "folder":"first"}, {"id":"mode-second", "title":"Second mode", "folder":"second"}]
	family.settings_variants = true
	write(fixture.path_join("family/game.json"), JSON.stringify(family))
	module("family/art/unlisted", "unlisted", "Must stay undiscovered")
	var catalog := GameCatalog.new(fixture)
	catalog.scan()
	check(catalog.games.size() == 3 and catalog.menu_games().size() == 1 and catalog.diagnostics.is_empty(), "Only declared direct mode folders join the catalog")
	check(catalog.find_game("mode-first").folder == fixture.path_join("family/first"), "Stable IDs resolve to their physical nested folder")
	check(GameCatalog.module_folder("mode-second", fixture) == fixture.path_join("family/second"), "Skin/editor discovery shares nested module paths")
	write(fixture.path_join("family/second/theme-slots.json"), JSON.stringify({"schema_version":1,"slots":[{"id":"piece","label":"Piece","group":"Art","kind":"image","path":"Games/family/second/art/piece.svg"}]}))
	write(fixture.path_join("family/second/themes/default/theme.json"), JSON.stringify({"schema_version":1,"id":"default","name":"Default","assets":{},"labels":{}}))
	var skins := ThemePacks.new("mode-second", fixture)
	check(skins.slots.size() == 1 and skins.relative_folder == "Games/family/second" and skins.list_packs().size() == 1, "Nested skins use actual paths while retaining their stable game ID")
	var runtime := fixture.path_join("_runtime")
	var art := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><rect width="24" height="24" fill="#345678"/></svg>'
	write(runtime.path_join("Games/family/second/art/piece.svg"), art)
	write(runtime.path_join("Games/family/shared.svg"), art)
	RuntimeAssets.root_override = ProjectSettings.globalize_path(runtime)
	RuntimeAssets.refresh()
	var store := AssetStore.new()
	store.definitions_root = fixture
	check(store.categories().any(func(category: Dictionary) -> bool: return category.id == "Games/mode-second"), "Asset categories retain nested modes' stable IDs")
	var entries := store.scan_category("Games/mode-second")
	check(entries.size() == 1 and entries[0].path == "Games/family/second/art/piece.svg" and entries[0].category_folder == "Games/family/second" and entries[0].protected, "Nested asset rows retain the physical path, category prefix and protected skin slot")
	entries = store.scan_category("Games/mode-family")
	check(entries.size() == 1 and entries[0].path == "Games/family/shared.svg", "Parent asset scans exclude separately removable modes")
	var pack := skins.duplicate_pack("default", "Nested skin")
	check(pack.ok and skins.stage_media(pack.pack, "piece", runtime.path_join("Games/family/shared.svg")).ok and skins.save_pack(pack.pack).ok, "Nested custom skins stage and save under their own folder")
	check(str(skins.load_pack("nested-skin").assets.piece).begins_with("Games/family/second/themes/nested-skin/media/"), "Content-addressed skin media follows its nested module")
	ThemePacks.unpin("mode-second")
	RuntimeAssets.root_override = ""
	RuntimeAssets.refresh()
	var server := LanServer.new()
	server.game_catalog = catalog
	check(server._resolve_game_web_path("/game/mode-first/") == fixture.path_join("family/first/controller/index.html"), "Controller routes retain stable IDs")
	for path in ["/game/mode-first/host/main.tscn", "/game/mode-family/first/host/main.tscn", "/game/mode-family/FIRST/controller/index.html"]:
		check(server._resolve_game_web_path(path).is_empty(), "Parent routes cannot bypass child routing or privacy")
	var app: Control = load("res://Main.tscn").instantiate()
	app.game_catalog = catalog
	app.profile_store = ProfileStore.new(fixture.path_join("profiles.json"))
	app.game_settings_store = GameSettingsStore.new(fixture.path_join("_preferences"))
	root.add_child(app)
	app.game_settings_store.save_settings("mode-family", {"gamemode":"mode-first"})
	# Removing only a mode's folder leaves its declared title and disabled entry.
	var original := fixture.path_join("family/first")
	var removed := fixture.path_join("_removed-first")
	check(DirAccess.rename_absolute(original, removed) == OK, "Temporarily remove a complete mode folder")
	catalog.scan()
	var parent := catalog.find_game("mode-family")
	var choices := catalog.choices_for(parent)
	check(catalog.diagnostics.is_empty(), "Removing an optional mode is not a catalog error")
	check(catalog.menu_games().size() == 1 and choices.size() == 2 and not choices[0].available and choices[0].title == "First mode", "Missing modes stay named while their parent and siblings remain available")
	app._launch_game(parent)
	check(app.active_game_id == "mode-second", "A missing remembered mode falls back to an installed eligible mode")
	var control := OptionButton.new()
	var group := VBoxContainer.new()
	app.active_game.add_child(group)
	group.add_child(control)
	app.active_game.configure_game_mode_choice(control)
	check(control.item_count == 2 and control.is_item_disabled(0) and not control.is_item_disabled(1) and control.selected == 1, "Settings shows the missing mode greyed out with the installed mode selected")
	app.active_game.game_selected.emit("mode-first")
	check(app.active_game_id == "mode-second", "A forged selection cannot launch a missing mode")
	check(app.game_settings_store.load_settings("mode-family", {"gamemode":""}).gamemode == "mode-first", "Fallback preserves saved mode intent")
	check(server._resolve_game_web_path("/game/mode-first/").is_empty(), "Removed modes have no LAN route")
	app.active_game.return_to_lobby()
	await process_frame
	check(DirAccess.rename_absolute(removed, original) == OK, "Restore the optional mode folder")
	catalog.scan()
	app._launch_game(catalog.find_game("mode-family"))
	check(app.active_game_id == "mode-first", "Restoring the folder re-enables the remembered mode")
	app.active_game.return_to_lobby()
	await process_frame
	# Invalid child files/IDs disable that child without removing its family.
	first.host_scene = "host/missing.tscn"
	write(original.path_join("game.json"), JSON.stringify(first))
	catalog.scan()
	check(not catalog.find_game("mode-family").is_empty() and not catalog.choices_for(catalog.find_game("mode-family"))[0].available, "An invalid installed mode is disabled independently")
	first.host_scene = "host/main.tscn"
	first.id = "forged-id"
	write(original.path_join("game.json"), JSON.stringify(first))
	catalog.scan()
	check(catalog.find_game("forged-id").is_empty() and catalog.find_game("mode-first").is_empty(), "A nested manifest cannot impersonate another mode ID")
	var second := fixture.path_join("family/second")
	check(DirAccess.rename_absolute(second, fixture.path_join("_removed-second")) == OK, "Remove the last usable mode")
	catalog.scan()
	parent = catalog.find_game("mode-family")
	check(not parent.is_empty() and catalog.menu_games().size() == 1 and not app._can_launch_for_count(parent, 0), "A family with no usable modes remains listed and cannot launch")
	for unsafe in ["../first", "/first", "first/child", "first\\child", "_hidden", ""]:
		family.game_choices[0].folder = unsafe
		write(fixture.path_join("family/game.json"), JSON.stringify(family))
		check(not catalog._read_game("family").ok, "Unsafe mode folder declarations are rejected")
	app.lan_server.stop_server()
	server.free()
	app.queue_free()
	for frame in 8: await process_frame
	print("Nested game modes: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
