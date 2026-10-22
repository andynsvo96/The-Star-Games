extends SceneTree

const FOLDER := "res://.test_data/game_backgrounds"
var failures := 0
var server: LanServer


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _request(path: String, headers := PackedStringArray()) -> Dictionary:
	var http := HTTPClient.new()
	http.connect_to_host("127.0.0.1", server.http_port)
	for frame in 600:
		http.poll()
		if http.get_status() == HTTPClient.STATUS_CONNECTED:
			break
		await process_frame
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return {}
	http.request(HTTPClient.METHOD_GET, path, headers)
	for frame in 600:
		http.poll()
		if http.has_response():
			break
		await process_frame
	var body := PackedByteArray()
	var response_headers := http.get_response_headers_as_dictionary()
	var status := http.get_response_code()
	for frame in 600:
		http.poll()
		body.append_array(http.read_response_body_chunk())
		if http.get_status() != HTTPClient.STATUS_BODY:
			break
		await process_frame
	return {"status": status, "headers": response_headers, "body": body}


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	for filename in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FOLDER.path_join(filename)))
	var stem := FOLDER.path_join("scene")
	var image := Image.create(32, 24, false, Image.FORMAT_RGB8)
	image.fill(Color("28bbee"))
	check(image.save_png(stem + ".png") == OK, "Image fixture saved")
	var background := preload("res://scripts/game_background.gd").new()
	background.source_stem = stem
	background.size = Vector2(320, 240)
	root.add_child(background)
	await process_frame
	check(background.last_video == stem + ".png" and background.picture.texture != null, "Same-name image loads without specifying its extension")
	var day_stem := FOLDER.path_join("day")
	image.fill(Color("e6dcb4"))
	check(image.save_png(day_stem + ".png") == OK, "Alternate phase image fixture saved")
	background.transition_to(day_stem)
	await process_frame
	check(background.source_stem == day_stem and background.phase_overlay.visible and background.phase_overlay.texture != null, "Shared phase transition preserves the outgoing frame while switching stems")
	await create_timer(1.0).timeout
	check(not background.phase_overlay.visible and background.last_video == day_stem + ".png", "Phase crossfade settles and releases the outgoing texture")
	background.transition_to(stem)
	background.reduced_motion = true
	check(not background.phase_overlay.visible, "Reduced motion cancels an in-progress phase fade")
	background.transition_to(day_stem)
	check(not background.phase_overlay.visible and background.last_video == day_stem + ".png", "Reduced motion switches phase scenery immediately")
	background.reduced_motion = false
	background.transition_to(stem)
	background.set_active(false)
	check(not background.phase_overlay.visible and not background.phase_pending, "Exiting cancels the phase transition")
	background.set_active(true)
	var catalog := GameCatalog.new()
	catalog.games = [{"id": "background-test", "folder": FOLDER, "background": "scene", "background_variants": {"day": "day"}, "controller_entry": "index.html"}]
	server = LanServer.new()
	root.add_child(server)
	server.configure(ProfileStore.new(), catalog)
	check(server.start_server(), "Background HTTP server starts")
	var metadata := await _request("/game/background-test/background.json")
	var parsed: Variant = JSON.parse_string(metadata.get("body", PackedByteArray()).get_string_from_utf8())
	check(metadata.get("status") == 200 and parsed.image == "/game/background-test/scene.png", "Controller discovers the same image from the manifest stem")
	check(parsed.variants.day.image == "/game/background-test/day.png" and parsed.variants.day.videos.is_empty(), "Shared metadata resolves extensionless phase variants")
	check((await _request("/game/background-test/day.png")).get("status") == 200, "Variant artwork is served offline through the existing LAN server")
	_test_variant_manifest()
	# Exercise large streaming responses and byte ranges with deterministic bytes.
	var bytes := PackedByteArray()
	bytes.resize(180000)
	for index in bytes.size():
		bytes[index] = index % 251
	var binary := FileAccess.open(FOLDER.path_join("sample.mp4"), FileAccess.WRITE)
	binary.store_buffer(bytes)
	binary.close()
	var full := await _request("/game/background-test/sample.mp4")
	check(full.get("status") == 200 and full.get("body") == bytes, "Video response streams every chunk without truncation")
	var range_reply := await _request("/game/background-test/sample.mp4", PackedStringArray(["Range: bytes=65530-65550"]))
	check(range_reply.get("status") == 206 and range_reply.get("body") == bytes.slice(65530, 65551), "Video byte range is exact across a chunk boundary")
	var suffix := await _request("/game/background-test/sample.mp4", PackedStringArray(["Range: bytes=-17"]))
	check(suffix.get("status") == 206 and suffix.get("body") == bytes.slice(bytes.size() - 17), "Suffix byte ranges work")
	var invalid := await _request("/game/background-test/sample.mp4", PackedStringArray(["Range: bytes=190000-"]))
	check(invalid.get("status") == 416 and invalid.get("body").is_empty(), "Out-of-bounds byte ranges are rejected")
	check(server._resolve_game_web_path("/game/background-test/../scene.png").is_empty(), "Media traversal is rejected")
	# Playback/conversion checks run when desktop FFmpeg is available.
	var output: Array = []
	var encoded := OS.execute("ffmpeg", PackedStringArray(["-hide_banner", "-loglevel", "error", "-y", "-f", "lavfi", "-i", "testsrc2=size=160x120:rate=15", "-t", "1", "-an", "-c:v", "libtheora", ProjectSettings.globalize_path(stem + ".ogv")]), output, true, false)
	if encoded == 0:
		background._scan()
		await create_timer(0.3).timeout
		check(background.last_video == stem + ".ogv" and background.player.stream_position > 0, "Same-name video takes priority over the image and plays")
		await create_timer(1.1).timeout
		check(background.picture.texture != null and background.last_video == stem + ".ogv", "Video loops with the shared prepared-frame player")
		background.reduced_motion = true
		await process_frame
		var position: float = background.player.stream_position
		await create_timer(0.2).timeout
		check(background.player.paused and is_equal_approx(background.player.stream_position, position), "Reduced motion freezes video artwork")
		background.set_active(false)
		check(background.player.paused and background.standby.paused, "Leaving pauses both decoders")
		background.reduced_motion = false
		# Release the source decoder before removing an open file on Windows.
		background.source_stem = FOLDER.path_join("missing")
		background._scan()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(stem + ".ogv"))
		background.source_stem = stem
		encoded = OS.execute("ffmpeg", PackedStringArray(["-hide_banner", "-loglevel", "error", "-y", "-f", "lavfi", "-i", "testsrc2=size=160x120:rate=15", "-t", "1", "-an", "-c:v", "libx264", "-pix_fmt", "yuv420p", ProjectSettings.globalize_path(stem + ".mp4")]), output, true, false)
		check(encoded == 0, "MP4 fixture prepared")
		background.set_active(true)
		for frame in 600:
			if background.last_video == BackgroundMedia.cache_path(stem + ".mp4"):
				break
			await process_frame
		check(background.last_video == BackgroundMedia.cache_path(stem + ".mp4"), "Desktop MP4 converts into user-data cache and becomes the background")
		check(not FileAccess.file_exists(stem + ".ogv"), "Conversion never writes alongside source artwork")
		metadata = await _request("/game/background-test/background.json")
		parsed = JSON.parse_string(metadata.body.get_string_from_utf8())
		check(parsed.videos.size() == 1 and parsed.videos[0].type == "video/mp4" and not parsed.image.is_empty(), "Controllers receive original video plus same-name image fallback")
		var abandoned_stem := FOLDER.path_join("abandoned_%s" % Time.get_ticks_usec())
		DirAccess.copy_absolute(ProjectSettings.globalize_path(stem + ".mp4"), ProjectSettings.globalize_path(abandoned_stem + ".mp4"))
		var abandoned := preload("res://scripts/game_background.gd").new()
		abandoned.source_stem = abandoned_stem
		root.add_child(abandoned)
		abandoned.set_active(false)
		abandoned.queue_free()
		await process_frame
		check(not is_instance_valid(abandoned), "Leaving releases the background while conversion is pending")
		for frame in 600:
			if FileAccess.file_exists(BackgroundMedia.cache_path(abandoned_stem + ".mp4")):
				break
			await process_frame
		check(FileAccess.file_exists(BackgroundMedia.cache_path(abandoned_stem + ".mp4")), "Shared conversion completes after the game background exits")
	else:
		print("SKIP: FFmpeg playback/conversion fixtures unavailable; image and HTTP checks ran")
	background.set_active(false)
	background.queue_free()
	server.stop_server()
	server.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FOLDER.path_join(filename)))
	print("Shared game backgrounds: %d failures" % failures)
	quit(0 if failures == 0 else 1)


func _test_variant_manifest() -> void:
	var folder := FOLDER.path_join("module")
	DirAccess.make_dir_recursive_absolute(folder)
	for filename in ["host.tscn", "index.html", "thumbnail.svg"]:
		var asset := FileAccess.open(folder.path_join(filename), FileAccess.WRITE)
		asset.store_string("Fixture")
		asset.close()
	var manifest := {"schema_version": 1, "id": "background-fixture", "title": "Fixture", "description": "Fixture", "version": "1", "thumbnail": "thumbnail.svg", "host_scene": "host.tscn", "controller_entry": "index.html", "min_players": 1, "max_players": 16, "modes": ["multiplayer"], "background": "scene", "background_variants": {"day": "day"}}
	var catalog := GameCatalog.new(FOLDER)
	for variants in [{"day": "day"}, {"day": "../day"}, {"day": "day.svg"}, {"../day": "day"}, {"day": 3}, ["day"]]:
		manifest.background_variants = variants
		var file := FileAccess.open(folder.path_join("game.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(manifest))
		file.close()
		check(catalog._read_game("module").ok == (variants is Dictionary and variants == {"day": "day"}), "Variant manifest validation accepts only safe named extensionless stems")
	for filename in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)
