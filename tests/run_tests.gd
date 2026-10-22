extends SceneTree

var failures: Array[String] = []
var assertions := 0


func _init() -> void:
	_test_profile_store()
	_test_game_catalog()
	_test_private_game_paths()
	_test_qr_generation()
	_test_readable_names()
	if failures.is_empty():
		print("PASS: %d assertions" % assertions)
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: %s" % failure)
		printerr("%d failure(s) across %d assertions" % [failures.size(), assertions])
		quit(1)


func _test_readable_names() -> void:
	for panel in [Color("101f30"), Color("fff4cf")]:
		for identity in [Color("202020"), Color("008000"), Color.WHITE, GameLook.RED, GameLook.BLUE]:
			var readable := GameLook.readable_text_color(identity, panel, 5.0)
			_expect(GameLook.text_contrast(readable, panel) >= 5.0, "Player names remain readable on dark and light panels")
			if GameLook.text_contrast(identity, panel) >= 5.0:
				_expect(readable == identity, "Readable identity colors retain their original color")


func _test_profile_store() -> void:
	var path := "user://the_star_games_test.json"
	_cleanup(path)
	var store := ProfileStore.new(path)
	_expect(store.load_data(), "Profile store initializes")
	var alice := store.create_or_get_profile("Alice")
	_expect(alice["ok"] and alice["created"], "Creates a new profile")
	var reclaimed := store.create_or_get_profile("  alice  ")
	_expect(reclaimed["ok"] and not reclaimed["created"], "Reclaims names case-insensitively")
	_expect(alice["profile"]["id"] == reclaimed["profile"]["id"], "Reclaimed profile keeps stable ID")
	var bob := store.create_or_get_profile("Bob")
	_expect(bob["ok"], "Creates a second profile")
	var collision := store.rename_profile(bob["profile"]["id"], "ALICE")
	_expect(not collision["ok"], "Rejects rename collision")
	_expect(store.add_game_points(alice["profile"]["id"], "valid-game", 25), "Awards game points")
	_expect(store.lifetime_points(store.get_profile(alice["profile"]["id"])) == 25, "Calculates lifetime points")
	_expect(store.reset_game_points(alice["profile"]["id"], "valid-game"), "Resets selected game points")
	_expect(store.lifetime_points(store.get_profile(alice["profile"]["id"])) == 0, "Reset updates lifetime total")
	_expect(store.record_result(alice["profile"]["id"], true), "Records a win")
	_expect(store.record_result(alice["profile"]["id"], false), "Records a loss")
	_expect(not store.record_result("missing", true), "Rejects unknown result profile")
	var reloaded := ProfileStore.new(path)
	_expect(reloaded.load_data() and reloaded.get_profiles().size() == 2, "Profiles persist and reload")
	var record := reloaded.get_profile(alice["profile"]["id"])
	_expect(record["wins"] == 1 and record["losses"] == 1, "Win/loss totals survive reload")
	_cleanup(path)


func _test_game_catalog() -> void:
	var catalog := GameCatalog.new("res://tests/fixtures/Games")
	var games := catalog.scan()
	_expect(games.size() == 1, "Catalog accepts one valid fixture")
	_expect(games[0]["id"] == "valid-game", "Catalog returns the expected game")
	_expect(games[0]["modes"] == ["singleplayer", "multiplayer"], "Catalog accepts singleplayer and multiplayer modes")
	_expect(catalog.diagnostics.size() == 1, "Catalog reports invalid fixture without crashing")


func _test_private_game_paths() -> void:
	var root_path := "res://.test_data/private-paths-%d" % OS.get_process_id()
	var folder := root_path.path_join("module")
	DirAccess.make_dir_recursive_absolute(folder.path_join("host"))
	DirAccess.make_dir_recursive_absolute(folder.path_join("controller"))
	for relative in ["thumbnail.svg", "host/main.tscn", "controller/index.html"]:
		DirAccess.copy_absolute("res://tests/fixtures/Games/valid-game/" + relative, folder.path_join(relative))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/Games/valid-game/game.json"))
	var catalog := GameCatalog.new(root_path)
	for paths in [[], ["host"], ["host/main.tscn"], ["host", "controller/private"]]:
		manifest.private_paths = paths
		var file := FileAccess.open(folder.path_join("game.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(manifest))
		file.close()
		_expect(catalog._read_game("module").ok, "Accepts safe optional host-only paths")
	for paths in [null, "host", [1], [""], ["../host"], ["/host"], ["host\\data"], ["host/"], ["host//data"], ["host", "HOST"], ["controller"], ["thumbnail.svg"]]:
		manifest.private_paths = paths
		var file := FileAccess.open(folder.path_join("game.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(manifest))
		file.close()
		_expect(not catalog._read_game("module").ok, "Rejects unsafe, duplicate or public-resource-hiding private paths")
	manifest.erase("private_paths")
	var file := FileAccess.open(folder.path_join("game.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	var legacy := catalog._read_game("module")
	_expect(legacy.ok, "Manifests without private_paths remain compatible")
	catalog.games = [legacy.game]
	var server := LanServer.new()
	server.game_catalog = catalog
	_expect(server._resolve_game_web_path("/game/valid-game/host/main.tscn") == folder.path_join("host/main.tscn"), "Legacy module asset routing is unchanged")
	_expect(not server._game_path_is_private({"private_paths": ["host"]}, "host-art/icon.svg"), "A protected folder does not hide similarly named public artwork")
	catalog.games[0]["private_paths"] = ["host", "controller/private"]
	for private_path in ["./host/main.tscn", "host/./main.tscn", "controller/./private/secret.json", "./private/secret.json"]:
		_expect(server._resolve_game_web_path("/game/valid-game/" + private_path).is_empty(), "Normalized dot segments cannot bypass protected files or sibling aliases")
	manifest.background = "art/background"
	manifest.private_paths = ["art/background.png"]
	file = FileAccess.open(folder.path_join("game.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	_expect(not catalog._read_game("module").ok, "Protecting an individual background extension cannot hide public scenery")
	server.free()


func _test_qr_generation() -> void:
	var texture := QrCode.texture_for_text("http://192.168.1.20:8080/")
	_expect(texture != null, "QR generator creates a texture for a LAN URL")
	_expect(texture.get_width() == 259 and texture.get_height() == 259, "QR texture has expected Version 3 dimensions")
	_expect(QrCode.texture_for_text("x".repeat(54)) == null, "QR generator rejects over-capacity content")


func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _cleanup(path: String) -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var target: String = path + suffix
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
