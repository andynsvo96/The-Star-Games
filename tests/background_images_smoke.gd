extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var folder := "user://background_image_test_%s" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var still := Image.create(64, 32, false, Image.FORMAT_RGB8)
	still.fill(Color.CORNFLOWER_BLUE)
	var first := folder.path_join("first.png")
	var second := folder.path_join("second.jpg")
	var third := folder.path_join("third.png")
	assert(still.save_png(first) == OK)
	still.fill(Color.SALMON)
	assert(still.save_jpg(second) == OK)
	var selections: Array[String] = []
	for launch in 16:
		# Fixed seeds exercise different startup choices reproducibly.
		seed(launch)
		var background = load("res://scripts/title_background.gd").new()
		background.source_dir = folder
		root.add_child(background)
		await process_frame
		var selected: String = background.last_video
		var texture: Texture2D = background.picture.texture
		assert(selected in [first, second])
		assert(texture != null)
		if not selections.has(selected):
			selections.append(selected)
		for interval in 12:
			background._process(9.0)
			assert(background.last_video == selected and background.picture.texture == texture)
			assert(not background.blending and background.standby_path.is_empty())
		background.set_active(false)
		background._process(9.0)
		background.set_active(true)
		assert(background.last_video == selected and background.picture.texture == texture)
		assert(still.save_png(third) == OK)
		background._scan()
		assert(background.playlist.has(third))
		background._prepare_next()
		assert(background.standby_path.is_empty())
		assert(background._take_next() == selected)
		assert(background.picture.texture == texture)
		# Video loop selection must also stay pinned despite other candidates.
		background.last_video = "chosen.ogv"
		assert(background._take_next() == "chosen.ogv")
		background.queue_free()
		await process_frame
		DirAccess.remove_absolute(third)
	assert(selections.size() == 2, "Fresh launches should randomly choose either background")
	DirAccess.remove_absolute(first)
	DirAccess.remove_absolute(second)
	DirAccess.remove_absolute(folder)
	print("PASS: random launch selection, no timed rotation, retained selection on return and rescan")
	quit()
