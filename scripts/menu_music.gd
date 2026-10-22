extends Control

signal volume_changed(value: float)

var song_dir := "res://asset/lobby_songs"
var cache_dir := "user://menu_music"
const CONVERT_EXTENSIONS := ["mp4", "m4a", "aac", "mov", "mkv", "webm", "flac", "wma"]
var playable_paths: Dictionary = {}
var worker: Thread
var converting_source := ""
var converting_target := ""
var failed: Array[String] = []
var scan_elapsed := 0.0
var player := AudioStreamPlayer.new()
var playlist: Array[String] = []
var remaining: Array[String] = []
var history: Array[String] = []
var history_index := -1
var user_paused := false
var active := true
var reduced_motion := false
var panel := PanelContainer.new()
var trigger := Button.new()
var title_clip := Control.new()
var song_title := Label.new()
var toggle := Button.new()
var previous := Button.new()
var next := Button.new()
var scroll_elapsed := 0.0
var hide_elapsed := 0.0
var icons: Dictionary = {}
var keyboard_navigation := false
var menu_open := false
var reveal_tween: Tween
var volume_slider := HSlider.new()
var volume_dragging := false
var volume_open := false
var volume_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.bus = "Music"
	add_child(player)
	player.finished.connect(play_next)
	_build_menu()
	_scan()
	_update_controls()


func _scan() -> void:
	var found: Array[String] = []
	var directories: Array[String] = [song_dir]
	if OS.has_feature("standalone"):
		directories.append(RuntimeAssets.root_folder().path_join(song_dir.trim_prefix("res://")))
	for directory in directories:
		if not DirAccess.dir_exists_absolute(directory):
			continue
		for filename in DirAccess.get_files_at(directory):
			if filename.contains(".replacement."):
				continue
			var source := RuntimeAssets.source(directory.path_join(filename))
			var extension := source.get_extension().to_lower()
			if extension in ["ogg", "mp3", "wav"]:
				playable_paths[source] = source
				found.append(source)
			elif extension in CONVERT_EXTENSIONS:
				var signature := "%s:%s" % [source, FileAccess.get_modified_time(source)]
				var cached := cache_dir.path_join(signature.sha256_text() + ".ogg")
				if FileAccess.file_exists(cached):
					playable_paths[source] = cached
					found.append(source)
				elif worker == null and not failed.has(source):
					_start_conversion(source, cached)
	var unique := {}
	for source in found:
		unique[source] = true
	found.assign(unique.keys())
	found.sort()
	if found != playlist:
		var old_playlist := playlist.duplicate()
		playlist = found
		remaining = remaining.filter(func(path: String) -> bool: return playlist.has(path))
		for path in playlist:
			if not old_playlist.has(path):
				remaining.append(path)
		remaining.shuffle()
		# Remove deleted files from navigation history while keeping the current position.
		for index in range(history.size() - 1, -1, -1):
			if not playlist.has(history[index]):
				history.remove_at(index)
				if index <= history_index:
					history_index -= 1
	if playlist.is_empty():
		player.stop()
		player.stream = null
	elif player.stream == null or not player.playing:
		play_next()
	_update_controls()


func _start_conversion(source: String, target: String) -> void:
	if OS.get_name() not in ["Windows", "macOS", "Linux"]:
		failed.append(source)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_dir))
	converting_source = source
	converting_target = target
	var args := PackedStringArray([
		"-hide_banner", "-loglevel", "error", "-y", "-i", ProjectSettings.globalize_path(source),
		"-vn", "-c:a", "libvorbis", "-q:a", "5", ProjectSettings.globalize_path(target + ".tmp.ogg")
	])
	worker = Thread.new()
	worker.start(func() -> int:
		var actual := RuntimeAssets.materialize(source)
		if actual.is_empty():
			return ERR_FILE_NOT_FOUND
		args[5] = actual
		return OS.execute("ffmpeg", args, [], false, false)
	)


func _exit_tree() -> void:
	if worker != null:
		worker.wait_to_finish()


func _build_menu() -> void:
	# Draw icons as vectors so controls do not depend on font glyph coverage.
	var shapes := {
		"play": '<path d="M8 4L21 12L8 20Z"/>',
		"pause": '<path d="M6 4H10V20H6ZM14 4H18V20H14Z"/>',
		"previous": '<path d="M4 4H7V20H4ZM20 4L8 12L20 20Z"/>',
		"next": '<path d="M17 4H20V20H17ZM4 4L16 12L4 20Z"/>',
		"music": '<path d="M10 4V16A4 4 0 1 1 8 12.5V5L21 2V13A4 4 0 1 1 19 9.5V5Z"/>'
	}
	for key in shapes:
		var svg := Image.new()
		svg.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="#f4f7ff">%s</g></svg>' % shapes[key])
		icons[key] = ImageTexture.create_from_image(svg)
	add_child(trigger)
	trigger.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	trigger.offset_left = -48
	trigger.offset_right = -12
	trigger.offset_top = 12
	trigger.offset_bottom = 48
	trigger.icon = icons["music"]
	_style_control(trigger, 18)
	trigger.add_theme_stylebox_override("normal", _surface(Color("0b1425b8"), 18))
	trigger.mouse_entered.connect(_reveal)
	trigger.focus_entered.connect(_reveal)
	trigger.pressed.connect(_reveal)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -308
	panel.offset_right = -12
	panel.offset_top = 12
	panel.offset_bottom = 56
	var style := _surface(Color("0b1425ed"), 14)
	style.border_color = Color("ffffff18")
	style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.resized.connect(func() -> void: panel.pivot_offset = Vector2(panel.size.x, 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	title_clip.custom_minimum_size = Vector2(0, 22)
	title_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_clip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_clip.clip_contents = true
	title_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title_clip)
	song_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	song_title.add_theme_font_size_override("font_size", 13)
	song_title.add_theme_color_override("font_color", Color("e2e8f2"))
	title_clip.add_child(song_title)
	_build_volume_slider()
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 4
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	for button in [previous, toggle, next]:
		button.custom_minimum_size = Vector2(28, 32)
		_style_control(button, 10)
		row.add_child(button)
	toggle.add_theme_stylebox_override("normal", _surface(Color("ffffff12"), 10))
	previous.icon = icons["previous"]
	previous.pressed.connect(play_previous)
	next.icon = icons["next"]
	next.pressed.connect(play_next)
	toggle.pressed.connect(toggle_pause)
	panel.hide()


func _surface(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(0)
	return style


func _style_control(button: Button, radius: int) -> void:
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 15)
	button.add_theme_color_override("icon_normal_color", Color("becbdd"))
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _surface(Color.TRANSPARENT, radius))
	button.add_theme_stylebox_override("hover", _surface(Color("ffffff18"), radius))
	button.add_theme_stylebox_override("pressed", _surface(Color("ffffff28"), radius))
	var focus := _surface(Color.TRANSPARENT, radius)
	focus.border_color = Color("8edcff99")
	focus.set_border_width_all(1)
	button.add_theme_stylebox_override("focus", focus)


func _build_volume_slider() -> void:
	title_clip.add_child(volume_slider)
	volume_slider.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	volume_slider.offset_left = 5
	volume_slider.offset_right = -5
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	volume_slider.focus_mode = Control.FOCUS_ALL
	var track := _surface(Color("ffffff25"), 2)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	volume_slider.add_theme_stylebox_override("slider", track)
	var fill := _surface(Color("ffffff9c"), 2)
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	volume_slider.add_theme_stylebox_override("grabber_area", fill)
	volume_slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var thumb := Image.new()
	thumb.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><circle cx="4" cy="4" r="4" fill="#edf5ff"/></svg>')
	var texture := ImageTexture.create_from_image(thumb)
	for state in ["grabber", "grabber_highlight", "grabber_disabled"]:
		volume_slider.add_theme_icon_override(state, texture)
	volume_slider.value_changed.connect(func(value: float) -> void:
		volume_changed.emit(value)
	)
	volume_slider.drag_started.connect(func() -> void: volume_dragging = true)
	volume_slider.drag_ended.connect(func(_changed: bool) -> void: volume_dragging = false)
	volume_slider.hide()


func set_volume(value: float) -> void:
	volume_slider.set_value_no_signal(clampf(value, 0.0, 1.0))


func _show_volume(value: bool) -> void:
	if volume_open == value:
		return
	volume_open = value
	if volume_tween != null:
		volume_tween.kill()
	if value:
		volume_slider.modulate.a = 0.0
		volume_slider.show()
	else:
		volume_slider.hide()
	if reduced_motion:
		volume_slider.modulate.a = 1.0
		song_title.modulate.a = 0.0 if value else 1.0
		return
	volume_tween = create_tween().set_parallel(true)
	volume_tween.tween_property(volume_slider, "modulate:a", 1.0, 0.12)
	volume_tween.tween_property(song_title, "modulate:a", 0.0 if value else 1.0, 0.12)


func _reveal() -> void:
	hide_elapsed = 0.0
	if menu_open or not active:
		return
	menu_open = true
	if reveal_tween != null:
		reveal_tween.kill()
	if not panel.visible:
		panel.modulate.a = 0.0
		panel.scale = Vector2(0.92, 0.92)
	panel.show()
	panel.pivot_offset = Vector2(panel.size.x, 0)
	if reduced_motion:
		panel.modulate.a = 1.0
		panel.scale = Vector2.ONE
		trigger.modulate.a = 0.0
		return
	reveal_tween = create_tween().set_parallel(true)
	reveal_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	reveal_tween.tween_property(panel, "scale", Vector2.ONE, 0.22)
	reveal_tween.tween_property(trigger, "modulate:a", 0.0, 0.1)


func _dismiss(immediate := false) -> void:
	if not menu_open and not immediate:
		return
	menu_open = false
	_show_volume(false)
	if reveal_tween != null:
		reveal_tween.kill()
	if immediate or reduced_motion:
		panel.hide()
		trigger.modulate.a = 1.0
		return
	reveal_tween = create_tween().set_parallel(true)
	reveal_tween.tween_property(panel, "modulate:a", 0.0, 0.14)
	reveal_tween.tween_property(panel, "scale", Vector2(0.96, 0.96), 0.14)
	reveal_tween.tween_property(trigger, "modulate:a", 1.0, 0.18)
	reveal_tween.chain().tween_callback(panel.hide)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		keyboard_navigation = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		keyboard_navigation = false


func _process(delta: float) -> void:
	if worker != null and not worker.is_alive():
		var result: int = worker.wait_to_finish()
		worker = null
		if result == 0:
			DirAccess.rename_absolute(converting_target + ".tmp.ogg", converting_target)
		else:
			failed.append(converting_source)
			push_warning("Could not prepare music: %s. FFmpeg must be available on PATH." % converting_source)
		_scan()
	scan_elapsed += delta
	if scan_elapsed >= 5.0:
		scan_elapsed = 0.0
		_scan()
	if not active:
		return
	var mouse := get_global_mouse_position()
	if trigger.get_global_rect().has_point(mouse):
		_reveal()
	if not panel.visible:
		return
	var focused := get_viewport().gui_get_focus_owner()
	_show_volume(menu_open and (title_clip.get_global_rect().has_point(mouse) or volume_dragging or (keyboard_navigation and volume_slider.has_focus())))
	if volume_dragging or panel.get_global_rect().has_point(mouse) or trigger.get_global_rect().has_point(mouse) or (keyboard_navigation and focused != null and (panel.is_ancestor_of(focused) or focused == trigger)):
		hide_elapsed = 0.0
	else:
		hide_elapsed += delta
		if hide_elapsed > 0.4:
			_dismiss()
	var overflow := maxf(0.0, song_title.size.x - title_clip.size.x)
	if overflow > 0.0 and not reduced_motion:
		scroll_elapsed += delta
		var travel := overflow / 30.0
		var phase := fmod(scroll_elapsed, travel * 2.0 + 3.0)
		song_title.position.x = -clampf(minf(phase - 1.5, travel * 2.0 + 1.5 - phase) * 30.0, 0.0, overflow)
	else:
		song_title.position.x = 0.0


func set_active(value: bool) -> void:
	active = value
	visible = value
	player.stream_paused = user_paused or not active
	if not active:
		_dismiss(true)


func toggle_pause() -> void:
	user_paused = not user_paused
	player.stream_paused = user_paused or not active
	_update_controls()


func play_next() -> void:
	if playlist.is_empty():
		return
	if history_index + 1 < history.size():
		history_index += 1
	else:
		if remaining.is_empty():
			remaining = playlist.duplicate()
			remaining.shuffle()
			if remaining.size() > 1 and not history.is_empty() and remaining.back() == history.back():
				var swap := remaining[0]
				remaining[0] = remaining[-1]
				remaining[-1] = swap
		history.append(remaining.pop_back())
		# Keep a bounded history for previous/next navigation across shuffles.
		if history.size() > 256:
			history.pop_front()
		history_index = history.size() - 1
	_play_current()


func play_previous() -> void:
	if history_index < 0:
		return
	history_index = maxi(0, history_index - 1)
	_play_current()


func _play_current() -> void:
	var path: String = playable_paths.get(history[history_index], "")
	match path.get_extension().to_lower():
		"ogg":
			player.stream = AudioStreamOggVorbis.load_from_file(path)
		"mp3":
			player.stream = AudioStreamMP3.load_from_file(path)
		"wav":
			player.stream = AudioStreamWAV.load_from_file(path)
	if player.stream == null:
		return
	# Tracks must finish so the shuffled playlist, rather than one song, loops.
	if player.stream is AudioStreamOggVorbis or player.stream is AudioStreamMP3:
		player.stream.loop = false
	elif player.stream is AudioStreamWAV:
		player.stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	player.play()
	player.stream_paused = user_paused or not active
	song_title.text = history[history_index].get_file().get_basename().replace("_", " ")
	song_title.size = song_title.get_minimum_size()
	song_title.position.x = 0
	scroll_elapsed = 0.0
	_update_controls()


func _update_controls() -> void:
	toggle.icon = icons["play"] if user_paused else icons["pause"]
	for button in [previous, toggle, next]:
		button.disabled = playlist.is_empty()
	if playlist.is_empty():
		song_title.text = "Preparing music…" if worker != null else "No songs available"


func reload_assets() -> void:
	player.stop()
	player.stream = null
	playable_paths.clear()
	failed.clear()
	_scan()
