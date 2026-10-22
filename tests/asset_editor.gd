extends SceneTree

var failures: Array[String] = []
var checks := 0
var server: LanServer
var fixture := "res://.test_data/asset-editor-fixture"
var original := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><rect width="24" height="24" fill="#ff0000"/></svg>'


func _init() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)


func write(path: String, contents: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()


func request(path: String) -> Dictionary:
	var http := HTTPClient.new()
	http.connect_to_host("127.0.0.1", server.http_port)
	for frame in 600:
		http.poll()
		if http.get_status() == HTTPClient.STATUS_CONNECTED:
			break
		await process_frame
	http.request(HTTPClient.METHOD_GET, path, PackedStringArray())
	for frame in 600:
		http.poll()
		if http.has_response():
			break
		await process_frame
	var response := {"status": http.get_response_code(), "headers": http.get_response_headers_as_dictionary(), "body": PackedByteArray()}
	for frame in 600:
		http.poll()
		response.body.append_array(http.read_response_body_chunk())
		if http.get_status() != HTTPClient.STATUS_BODY:
			break
		await process_frame
	return response


func _run() -> void:
	# All replacements and backups are isolated; bundled art is never modified.
	fixture += "-" + str(Time.get_ticks_usec())
	RuntimeAssets.root_override = ProjectSettings.globalize_path(fixture)
	RuntimeAssets.refresh()
	write(fixture.path_join("asset/test/piece.svg"), original)
	write(fixture.path_join("asset/test/unrelated.txt"), "Do not list code or documents")
	var image := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLUE)
	image.save_png(fixture.path_join("chosen.png"))
	var store := AssetStore.new()
	var entries := store.scan()
	check(entries.any(func(item: Dictionary) -> bool: return item.path == "asset/test/piece.svg"), "Scans media under the launcher hierarchy")
	check(entries.any(func(item: Dictionary) -> bool: return item.path == "Games/chess/art/white-pawn.svg"), "Scans game piece art")
	check(entries.any(func(item: Dictionary) -> bool: return str(item.path).begins_with("Games/uno/art/cards/")), "Scans UNO card art")
	check(not entries.any(func(item: Dictionary) -> bool: return str(item.path).ends_with(".txt") or str(item.path).contains(".import")), "Excludes documents and generated imports")
	var entry := {"path": "asset/test/piece.svg", "background": false}
	var before := FileAccess.get_sha256(fixture.path_join(entry.path))
	var staged := store.stage(entry, fixture.path_join("chosen.png"))
	check(staged.ok and staged.kind == "image", "Validates PNG replacement of an SVG asset")
	check(FileAccess.get_sha256(fixture.path_join(entry.path)) == before and not DirAccess.dir_exists_absolute(fixture.path_join("Backups")), "Preview never writes originals or backups")
	var saved := store.save(staged)
	check(saved.ok, "Commits validated media after the UI confirmation")
	check(FileAccess.file_exists(fixture.path_join("asset/test/piece.replacement.png")), "Writes the actual replacement file")
	check(FileAccess.file_exists(str(saved.backup).path_join("asset/test/piece.svg")), "Backup preserves the original folder hierarchy")
	var texture := RuntimeAssets.texture("res://asset/test/piece.svg")
	check(texture != null and texture.get_width() == 32, "Host loads the new format through the original resource path")
	check(RuntimeAssets.source("res://asset/test/piece.svg").ends_with("piece.replacement.png"), "Controller HTTP resolution receives the same replacement")
	server = LanServer.new()
	root.add_child(server)
	var catalog := GameCatalog.new()
	catalog.games = [{"id": "asset-preview", "folder": RuntimeAssets.root_folder().path_join("asset/test"), "controller_entry": "index.html"}]
	server.configure(ProfileStore.new(), catalog)
	check(server.start_server(), "Controller media server starts")
	var response := await request("/game/asset-preview/piece.svg")
	check(response.status == 200 and response.headers.get("Content-Type", "") == "image/png", "Original browser URL serves the replacement's actual MIME type")
	check(response.body == FileAccess.get_file_as_bytes(fixture.path_join("chosen.png")), "Browser receives the saved image bytes")
	RuntimeAssets.refresh()
	check(RuntimeAssets.texture("res://asset/test/piece.svg").get_width() == 32, "Saved replacements survive a resolver reload")
	var previous := store.previous(entry.path)
	check(FileAccess.get_file_as_string(previous) == original, "Restore Previous locates an intact original")
	var restore := store.stage(entry, previous)
	check(restore.ok and store.save(restore).ok, "Restoration uses staged, backed-up saving")
	check(RuntimeAssets.texture("res://asset/test/piece.svg").get_width() == 24, "Restoration recovers the original artwork")
	response = await request("/game/asset-preview/piece.svg")
	check(response.status == 200 and response.body.get_string_from_utf8() == original, "Browser refresh receives restored artwork")
	server.stop_server()
	server.queue_free()
	DirAccess.remove_absolute(staged.staged)
	write(fixture.path_join("asset/test/sound.wav"), "not audio")
	# Use bundled offline recordings as valid decoder fixtures.
	DirAccess.copy_absolute("res://Games/chess/audio/move.wav", fixture.path_join("asset/test/sound.wav"))
	entries = store.scan()
	var sound := {"path": "asset/test/sound.wav", "background": false, "kind": "audio"}
	var audio_stage := store.stage(sound, "res://Games/uno/audio/card-place-1.ogg")
	check(audio_stage.ok and store.save(audio_stage).ok, "Audio replacement accepts a different native audio format")
	check(RuntimeAssets.audio("res://asset/test/sound.wav") != null, "Host decodes replaced OGG through the original WAV reference")
	check(not store.stage(entry, "res://Games/chess/audio/move.wav").ok, "Rejects audio as replacement for a game piece")
	DirAccess.remove_absolute(audio_stage.staged)
	write(fixture.path_join("asset/splash_background/scene.svg"), original)
	entries = store.scan()
	var background := {"path": "asset/splash_background/scene.svg", "background": true}
	var video_path := fixture.path_join("chosen.mp4")
	var video_result := OS.execute("ffmpeg", PackedStringArray(["-v", "error", "-y", "-f", "lavfi", "-i", "color=c=blue:s=32x24:r=12", "-t", "0.25", "-c:v", "libx264", "-pix_fmt", "yuv420p", ProjectSettings.globalize_path(video_path)]), [], true, false)
	if video_result == 0:
		var video_stage := store.stage(background, video_path)
		check(video_stage.ok and video_stage.kind == "video", "Decodes a video frame before supporting an image-to-video background replacement")
		if video_stage.ok:
			check(store.save(video_stage).ok, "Saves a video background with its original image preserved")
			var candidates := BackgroundMedia.candidates("res://asset/splash_background/scene")
			check(candidates.size() == 2 and candidates[0].ends_with(".mp4") and candidates[1].ends_with(".svg"), "Video takes priority and the image remains as a fallback")
			DirAccess.remove_absolute(video_stage.staged)
	else:
		print("SKIP: video validation fixture requires FFmpeg")
	var music_path := fixture.path_join("asset/lobby_songs/music.m4a")
	DirAccess.make_dir_recursive_absolute(music_path.get_base_dir())
	var made_music := OS.execute("ffmpeg", PackedStringArray(["-v", "error", "-y", "-f", "lavfi", "-i", "sine=frequency=440:duration=0.25", "-c:a", "aac", ProjectSettings.globalize_path(music_path)]), [], true, false)
	if made_music == 0:
		entries = store.scan()
		var songs := entries.filter(func(item: Dictionary) -> bool: return item.path == "asset/lobby_songs/music.m4a")
		check(songs.size() == 1 and songs[0].kind == "audio", "Existing converted music is listed as audio")
		var prepared := AssetStore.prepare_audio_preview(music_path)
		check(prepared.ok, "Converted audio preview uses the launcher-owned preparer")
		if prepared.ok:
			for frame in 600:
				await process_frame
				if FileAccess.file_exists(str(prepared.preview)):
					break
			check(RuntimeAssets.audio(str(prepared.preview)) != null, "Music in an AAC container becomes playable without changing its source")
		var music_stage := store.stage(songs[0], "res://Games/uno/audio/card-place-1.ogg")
		check(music_stage.ok and store.save(music_stage).ok, "Existing converted music accepts a native audio replacement")
		check(RuntimeAssets.source("res://asset/lobby_songs/music.m4a").ends_with(".ogg"), "Music scanning resolves the new format")
		DirAccess.remove_absolute(music_stage.staged)
	DirAccess.remove_absolute(restore.staged)
	write(fixture.path_join("bad.png"), "not an image")
	check(not store.stage(entry, fixture.path_join("bad.png")).ok, "Rejects corrupt content with a supported extension")
	check(not store.stage(entry, fixture.path_join("asset/test/unrelated.txt")).ok, "Rejects unsupported file types")
	check(not store.stage({"path": "../outside.png", "background": false}, fixture.path_join("chosen.png")).ok, "Rejects assets outside the catalog")
	write(fixture.path_join("linked.svg"), '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><image href="https://example.com/art.png"/></svg>')
	check(not store.stage(entry, fixture.path_join("linked.svg")).ok, "Rejects online SVG dependencies")
	staged = store.stage(entry, fixture.path_join("chosen.png"))
	write(fixture.path_join("asset/test/piece.svg"), original.replace("#ff0000", "#00ff00"))
	check(not store.save(staged).ok, "Detects originals changed since preview")
	DirAccess.remove_absolute(staged.staged)
	write(fixture.path_join("asset/test/piece.svg"), original)
	staged = store.stage(entry, fixture.path_join("chosen.png"))
	write(str(staged.staged), "changed staged bytes")
	check(not store.save(staged).ok, "Detects a changed prepared replacement")
	DirAccess.remove_absolute(staged.staged)
	RuntimeAssets.root_override = ""
	RuntimeAssets.refresh()
	var app = load("res://Main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app._show_settings("title")
	check(app.screen_root.find_children("*", "Button", true, false).any(func(button: Button) -> bool: return button.text == "Asset Editor"), "Settings offers Asset Editor beside Debug")
	app._show_asset_editor()
	await process_frame
	var editor: Control = app.asset_editor
	check(app.current_state == "asset_editor" and not app.lan_server.running, "Opening the editor preserves launcher/server state")
	check(editor.tree.get_root().get_child_count() == 2, "Asset list separates Launcher and Games")
	check(editor.save_button.disabled, "Save stays disabled without a replacement")
	editor.request_exit()
	await process_frame
	check(app.current_state == "settings" and app.settings_caller == "title", "Return restores the calling Settings screen")
	app._return_from_settings()
	app._enter_lobby()
	await create_timer(0.5).timeout
	app._show_settings("lobby")
	app._show_asset_editor()
	await process_frame
	check(app.lan_server.running and app.lan_server.lobby_open, "Editor keeps the lobby connection flow alive")
	app.asset_editor.request_exit()
	app._return_from_settings()
	check(app.current_state == "lobby", "Return navigation preserves the lobby")
	app.lan_server.stop_server()
	app.queue_free()
	await process_frame
	await process_frame
	RuntimeAssets.refresh()
	print("Asset editor: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
