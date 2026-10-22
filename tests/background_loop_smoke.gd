extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Run this rendering test without --headless.")
		quit(1)
		return
	Engine.max_fps = 60
	var background := load("res://scripts/title_background.gd").new() as Control
	root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var loops := [0]
	background.video_changed.connect(func() -> void: loops[0] += 1)
	var checked_frames := 0
	var previous_frame := PackedByteArray()
	var repeated_frames := 0
	var max_repeated := 0
	var blending_frames := 0
	var deadline := Time.get_ticks_msec() + 25000
	while loops[0] < 3 or background.player.stream_position < 0.4:
		await RenderingServer.frame_post_draw
		if Time.get_ticks_msec() > deadline:
			printerr("FAIL: background did not complete three loops")
			quit(1)
			return
		var position: float = background.player.stream_position
		if background.blending or (loops[0] > 0 and position < 0.4) or position > 5.6:
			var frame := root.get_texture().get_image()
			frame.resize(160, 90, Image.INTERPOLATE_BILINEAR)
			var pixels := frame.get_data()
			repeated_frames = repeated_frames + 1 if pixels == previous_frame else 0
			max_repeated = maxi(max_repeated, repeated_frames)
			previous_frame = pixels
			if repeated_frames >= 2:
				printerr("FAIL: repeated frozen frames at video loop boundary")
				quit(1)
				return
			if background.blending:
				blending_frames += 1
				if not background.standby_ready or background.standby.paused:
					printerr("FAIL: next video was not prepared and moving during transition")
					quit(1)
					return
			var brightness := 0.0
			for y in frame.get_height():
				for x in frame.get_width():
					brightness += frame.get_pixel(x, y).get_luminance()
			brightness /= frame.get_width() * frame.get_height()
			if brightness < 0.04:
				printerr("FAIL: black frame at video loop boundary")
				quit(1)
				return
			checked_frames += 1
	if blending_frames < 3:
		printerr("FAIL: transitions were not rendered")
		quit(1)
		return
	print("PASS: three preloaded loops, %d moving blend frames, %d boundary frames, %d consecutive repeats" % [blending_frames, checked_frames, max_repeated])
	quit()
