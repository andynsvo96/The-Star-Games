extends SceneTree

var failures := 0
var app: Control
const OUTPUT := "res://.test_data/asset-editor-visual"


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func capture(name: String) -> void:
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT.path_join(name + ".png"))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	app = load("res://Main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app._show_settings("title")
	await capture("settings")
	app._show_asset_editor()
	await process_frame
	var editor: Control = app.asset_editor
	for entry in editor.store.entries:
		if entry.path == "Games/chess/art/white-pawn.svg":
			editor.selected = entry
			break
	editor._discard()
	var image := Image.create(160, 160, false, Image.FORMAT_RGBA8)
	image.fill(Color("58aaff"))
	image.save_png(OUTPUT.path_join("chosen.png"))
	var original_hash := FileAccess.get_sha256("res://Games/chess/art/white-pawn.svg")
	for view in [["desktop", 1280, 720], ["portrait", 390, 844], ["landscape", 844, 390]]:
		root.min_size = Vector2i(1, 1)
		root.content_scale_size = Vector2i(view[1], view[2])
		root.size = Vector2i(view[1], view[2])
		editor.search.text = "chess"
		editor._populate()
		await capture(view[0])
		check(editor.tree.get_global_rect().end.x <= editor.preview.get_global_rect().position.x, "%s keeps list to the left of preview" % view[0])
		check(editor.tree.get_global_rect().end.y <= app.size.y and editor.tree.size.x >= 100, "%s keeps asset navigation reachable" % view[0])
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	editor._stage(OUTPUT.path_join("chosen.png"))
	for frame in 600:
		await process_frame
		if editor.worker == null:
			break
	check(not editor.pending.is_empty() and not editor.save_button.disabled, "Supported preview enables Save")
	await capture("replacement")
	var staged_path := str(editor.pending.staged)
	for caption in ["Collapse All", "Expand All"]:
		for button in editor.find_children("*", "Button", true, false):
			if button.text == caption:
				button.pressed.emit()
		await capture("collapsed" if caption == "Collapse All" else "expanded")
		check(str(editor.pending.staged) == staged_path and not editor.save_button.disabled, "Folding sections preserves the previewed replacement")
	editor._confirm_save()
	await capture("confirmation")
	for dialog in editor.get_children():
		if dialog is ConfirmationDialog:
			dialog.canceled.emit()
	editor.request_exit()
	await capture("unsaved")
	for dialog in editor.get_children():
		if dialog is ConfirmationDialog:
			dialog.canceled.emit()
	check(app.current_state == "asset_editor" and not editor.pending.is_empty(), "Cancel preserves the pending preview")
	editor._discard()
	check(FileAccess.get_sha256("res://Games/chess/art/white-pawn.svg") == original_hash, "Preview and cancellation leave real artwork unchanged")
	editor.selected = {"path": "Games/chess/audio/move.wav", "kind": "audio", "background": false}
	editor._show_preview("res://Games/chess/audio/move.wav")
	editor._toggle_audio()
	check(editor.audio.playing, "Audio preview plays through the Effects bus")
	await capture("audio")
	var clip := OUTPUT.path_join("clip.ogv")
	var made_clip := OS.execute("ffmpeg", PackedStringArray(["-v", "error", "-y", "-f", "lavfi", "-i", "color=c=blue:s=160x120:r=12", "-t", "1", "-c:v", "libtheora", ProjectSettings.globalize_path(clip)]), [], true, false)
	if made_clip == 0:
		editor.selected = {"path": "asset/splash_background/clip.ogv", "kind": "video", "background": true}
		editor._show_preview(clip)
		await capture("video")
		check(editor.video.player.is_playing() and editor.video.picture.texture != null, "Native video preview decodes and plays silently")
		editor.reduced_motion = true
		editor._show_preview(clip)
		await capture("reduced-video")
		check(editor.video.player.paused and editor.video.picture.texture != null, "Reduced motion freezes the video after a decoded frame")
	editor.selected = {"path": "Games/chess/art/castle-room.png", "kind": "image", "background": true}
	editor.reduced_motion = true
	editor._show_preview("res://Games/chess/art/castle-room.png")
	await capture("reduced")
	editor.request_exit()
	await process_frame
	check(app.current_state == "settings", "Clean return restores Settings")
	app.queue_free()
	await process_frame
	await process_frame
	print("Asset editor visual: %d failures" % failures)
	quit(0 if failures == 0 else 1)
