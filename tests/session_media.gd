extends SceneTree

var checks := 0
var failures := 0
var server: LanServer


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(30).timeout.connect(func() -> void: printerr("FAIL: session media watchdog"); quit(1))
	var catalog := GameCatalog.new("res://tests/fixtures/Games")
	catalog.scan()
	var store := ProfileStore.new("user://session-media-profiles.json")
	store.load_data()
	server = LanServer.new()
	root.add_child(server)
	server.configure(store, catalog)
	check(server.start_server(), "Existing LAN server starts")
	server.set_active_game("valid-game")
	var folder := "user://valid-game/content/media"
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("sample.png")
	var picture := Image.create(24, 16, false, Image.FORMAT_RGBA8)
	picture.fill(Color("2463eb"))
	picture.save_png(path)
	var host := BaseGame.new()
	root.add_child(host)
	host.controller_media_updated.connect(func(resources: Dictionary) -> void: server.set_game_media("valid-game", resources))
	var urls := host.set_controller_media([path])
	check(urls[path].begins_with("/session-media/") and not urls[path].contains("sample"), "Capabilities contain no content filename or filesystem path")
	var response := await fetch(urls[path])
	check(response[1] == 200 and response[3] == FileAccess.get_file_as_bytes(path), "Exposed original image is served through real LAN HTTP")
	var partial := await fetch(urls[path], ["Range: bytes=0-15"])
	check(partial[1] == 206 and partial[3].size() == 16, "Session media preserves bounded byte-range streaming")
	check(host.set_controller_media([path])[path] == urls[path], "Repeated permitted snapshots keep stable capabilities")
	host.set_controller_media([])
	check((await fetch(urls[path]))[1] == 404, "Removing a file immediately revokes its earlier route")
	var next := host.set_controller_media([path])
	check(next[path] != urls[path], "Reexposure issues a fresh unpredictable capability")
	var token: String = next[path].get_file()
	for forbidden in ["res://project.godot", "user://session-media-profiles.json", "res://Games/valid-game/../another.png", "user://another/content/media/a.png", "user://valid-game/content/media/../media/sample.png"]:
		server.set_game_media("valid-game", {token: forbidden})
		check(server.session_media.is_empty(), "Unscoped, unsupported and noncanonical paths cannot be registered")
	server.set_game_media("another-game", {token: path})
	check(server.session_media.is_empty(), "Inactive game cannot register media")
	server.set_game_media("valid-game", {token: path})
	server.set_active_game("")
	check((await fetch(next[path]))[1] == 404, "Navigation clears all active game capabilities")
	var media := GameMediaView.new()
	root.add_child(media)
	media.show_media({"sources": [path], "poster": "", "alt": "Literal <b> sample"})
	check(media.visible and media.picture.texture != null and not media.actions.visible and media.notice.text == "Literal <b> sample", "Shared native image surface preserves artwork and literal description")
	media.set_suspended(true)
	media.clear()
	check(not media.visible and media.picture.texture == null and media.player.stream == null, "Clearing shared media releases both image and video resources")
	server.stop_server()
	check(server.session_media.is_empty(), "Server shutdown clears capabilities")
	media.queue_free()
	host.queue_free()
	server.queue_free()
	await process_frame
	print("%s: %d session media checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)


func fetch(path: String, headers: PackedStringArray = []) -> Array:
	var request := HTTPRequest.new()
	root.add_child(request)
	request.request("http://127.0.0.1:%d%s" % [server.http_port, path], headers)
	var result: Array = await request.request_completed
	request.queue_free()
	return result


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + message)
