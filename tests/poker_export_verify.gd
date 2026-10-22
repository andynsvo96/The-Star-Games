extends SceneTree

var failures := 0
var checks := 0


func _init() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)


func _run() -> void:
	var target := str(OS.get_cmdline_user_args()[0]).path_join("run-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(target)
	check(not FileAccess.file_exists("res://tests/poker_export_verify.gd"), "Standalone pack has no loose test-source fallback")
	check(not DirAccess.dir_exists_absolute("res://Godot"), "Export excludes portable editor and saved user data")
	for id in ["poker", "poker-texas-holdem", "poker-omaha"]:
		var original := FileAccess.get_file_as_bytes("res://Games/%s/art/lounge.png" % id)
		check(original.size() > 100000 and original.slice(0, 8).hex_encode() == "89504e470d0a1a0a", "Export retains the raw %s background" % id)
		check(FileAccess.get_file_as_string("res://Games/%s/thumbnail.svg" % id).contains("<path"), "Export retains outlined thumbnails")
	var table := Image.new(); var table_data := FileAccess.get_file_as_bytes("res://Games/poker/art/table.png")
	check(table.load_png_from_buffer(table_data) == OK and table.detect_alpha() != Image.ALPHA_NONE, "Export preserves the transparent table's original PNG alpha")
	check(FileAccess.get_file_as_string("res://Games/poker/controller/controller.js").contains("StarGamesController"), "Export retains the shared offline Poker controller")
	for name in ["casino-frame", "casino-frame-active", "casino-button-fold", "casino-button-call", "casino-button-raise", "casino-button-neutral", "casino-slider-track", "casino-slider-fill", "casino-slider-knob", "casino-slider-knob-disabled"]:
		var path := "res://ui/playful/%s.svg" % name
		check(FileAccess.get_file_as_string(path).begins_with("<svg") and RuntimeAssets.texture(path) != null, "Export retains raw browser art and a native texture for " + str(name))
	for name in ["casino-player", "casino-player-active"]:
		var path := "res://ui/playful/%s.svg" % name
		check(FileAccess.get_file_as_string(path).begins_with("<svg") and RuntimeAssets.texture(path) != null, "Export retains the shared rounded player plaque " + name)
	check(RuntimeAssets.audio("res://Games/poker/audio/all-in.ogg") != null, "Export retains the offline All In money cue")
	for mode in ["texas-holdem", "omaha"]:
		var id := "poker-" + str(mode); var host = load("res://Games/%s/host/main.tscn" % id).instantiate()
		host.settings_store = GameSettingsStore.new(target.path_join("settings")); host.saved_game.path = target.path_join(id + ".json"); root.add_child(host)
		var context := GameSessionContext.new(id, [], {"id": "export-host", "display_name": "Host", "color": "#2463eb", "pose": 0}); context.reduced_motion = true
		host.initialize_session(context); host.start_game(); host.set_process(false)
		check(host.seats.size() == 2 and host._snapshot(0).hand.size() == (4 if mode == "omaha" else 2), "Packed %s starts a complete solo game" % id)
		check(host._save(), "Packed %s writes a validated session" % id)
		host.shutdown_game(); host.queue_free(); await process_frame
	await create_timer(.2).timeout
	print("Poker exported pack: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
