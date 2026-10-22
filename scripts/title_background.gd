extends Control

signal video_changed

const BLEND_SECONDS := 0.18
const SOURCE_DIR := "res://asset/splash_background"
const CACHE_DIR := "user://video_backgrounds"
const VIDEO_EXTENSIONS := ["mp4", "mov", "mkv", "webm", "avi", "m4v"]
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "bmp", "svg"]

var source_dir := SOURCE_DIR
var standby_image: Texture2D

var player := VideoStreamPlayer.new()
var picture := TextureRect.new()
var standby := VideoStreamPlayer.new()
var incoming := TextureRect.new()
var standby_path := ""
var standby_ready := false
var warming_up := false
var blending := false
var blend_elapsed := 0.0
var blend_duration := BLEND_SECONDS
var prepare_delay := 0.0
var playlist: Array[String] = []
var remaining: Array[String] = []
var last_video := ""
var failed: Array[String] = []
var scan_elapsed := 0.0
var waiting_for_frame := false
var freeze_motion := false
var preparer: Node


func _ready() -> void:
	preparer = get_node("/root/BackgroundPreparer")
	preparer.prepared.connect(_preparation_finished)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var backdrop := ColorRect.new()
	backdrop.color = Color("07102b")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	# Run after both decoders, so a prepared frame is ready before it is displayed.
	process_priority = 100
	for decoder in [player, standby]:
		decoder.expand = true
		decoder.volume = 0.0
		decoder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		decoder.position = Vector2(-2, -2)
		decoder.size = Vector2.ONE
		add_child(decoder)
	for surface in [picture, incoming]:
		surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		surface.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(surface)
	incoming.modulate.a = 0.0
	_scan()


func _process(delta: float) -> void:
	scan_elapsed += delta
	if scan_elapsed >= 5.0:
		scan_elapsed = 0.0
		_scan()
	if not visible:
		return
	if _is_image(last_video):
		return
	if waiting_for_frame and player.is_playing() and player.stream_position > 0.0:
		picture.texture = player.get_video_texture()
		waiting_for_frame = false
	if freeze_motion and not waiting_for_frame:
		player.paused = true
		standby.paused = true
		return
	if warming_up:
		# The standby decoder has consumed its initial zero-delta update. Pause it
		# on that decoded first frame; resuming now advances normally, without play().
		standby.paused = true
		warming_up = false
		standby_ready = true
	if blending:
		# Avoid the outgoing decoder's automatic end-of-file rewind on the
		# handoff frame. Its last image remains beneath the moving incoming clip.
		if not _is_image(last_video) and player.get_stream_length() - player.stream_position <= delta:
			player.paused = true
		blend_elapsed += delta
		incoming.modulate.a = minf(blend_elapsed / blend_duration, 1.0)
		if blend_elapsed >= blend_duration:
			_finish_transition()
	elif standby_ready:
		var time_left := player.get_stream_length() - player.stream_position
		if (not _is_image(last_video) and not player.is_playing()) or time_left <= BLEND_SECONDS:
			_begin_transition(maxf(time_left, 0.001))
	elif standby_path.is_empty():
		# Keep decoder setup away from the loop boundary itself.
		prepare_delay -= delta
		if prepare_delay <= 0.0:
			_prepare_next()


func set_active(active: bool) -> void:
	visible = active
	player.paused = not active or _is_image(last_video)
	standby.paused = not active or _is_image(standby_path) or (not warming_up and not blending)
	if active:
		_scan()
		if player.stream == null and not last_video.is_empty() and not _is_image(last_video):
			_play_next()


func _scan() -> void:
	var found: Array[String] = []
	var directories: Array[String] = [source_dir]
	if OS.has_feature("standalone"):
		directories.append(RuntimeAssets.root_folder().path_join("asset/splash_background"))
	for directory in directories:
		if not DirAccess.dir_exists_absolute(directory):
			continue
		var filenames := Array(DirAccess.get_files_at(directory))
		# Imported images may only have remapped resources in exported builds.
		if directory.begins_with("res://"):
			for filename in ResourceLoader.list_directory(directory):
				if not filenames.has(filename):
					filenames.append(filename)
		for filename: String in filenames:
			if filename.contains(".replacement."):
				continue
			var path := RuntimeAssets.source(directory.path_join(filename))
			var extension := path.get_extension().to_lower()
			if extension in IMAGE_EXTENSIONS and not failed.has(path):
				found.append(path)
			elif extension == "ogv":
				found.append(path)
			elif extension in VIDEO_EXTENSIONS:
				var signature := "%s:%s" % [path, FileAccess.get_modified_time(path)]
				var cached := CACHE_DIR.path_join(signature.sha256_text() + ".ogv")
				if FileAccess.file_exists(cached):
					found.append(cached)
				elif not failed.has(path):
					_start_conversion(path, cached)
	var unique := {}
	for source in found:
		unique[source] = true
	found.assign(unique.keys())
	found.sort()
	if found != playlist:
		playlist = found
		if not blending and not standby_path.is_empty() and standby_path != last_video and not playlist.has(standby_path):
			standby.paused = true
			standby_path = ""
			standby_ready = false
			warming_up = false
			standby_image = null
		remaining = remaining.filter(func(path: String) -> bool: return playlist.has(path))
		for path in playlist:
			if path != last_video and path != standby_path and not remaining.has(path):
				remaining.append(path)
		remaining.shuffle()
	if visible and last_video.is_empty() and not playlist.is_empty():
		_play_next()


func _is_image(path: String) -> bool:
	return path.get_extension().to_lower() in IMAGE_EXTENSIONS


func _load_image(path: String) -> Texture2D:
	if path.begins_with("res://") and ResourceLoader.exists(path, "Texture2D"):
		return RuntimeAssets.texture(path)
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		failed.append(path)
		playlist.erase(path)
		remaining.erase(path)
		push_warning("Skipping unreadable background image: %s" % path)
		return null
	return ImageTexture.create_from_image(image)


func _take_next() -> String:
	# Choose once per launch; subsequent playback only loops that selection.
	if not last_video.is_empty():
		return last_video
	if playlist.is_empty():
		return ""
	if remaining.is_empty():
		remaining.assign(playlist)
		remaining.shuffle()
		if remaining.size() > 1 and remaining.back() == last_video:
			var swap := remaining[0]
			remaining[0] = remaining[-1]
			remaining[-1] = swap
	return remaining.pop_back()


func _load_player(decoder: VideoStreamPlayer, path: String) -> void:
	# Reuse the existing decoder when looping the same file.
	if decoder.stream == null or decoder.stream.file != path:
		var stream := VideoStreamTheora.new()
		stream.file = path
		decoder.stream = stream
	else:
		decoder.stream_position = 0.0
	decoder.play()
	decoder.paused = not visible


func _play_next() -> void:
	if standby_ready:
		_begin_transition(BLEND_SECONDS)
		return
	if not last_video.is_empty():
		return
	last_video = _take_next()
	if last_video.is_empty():
		return
	if _is_image(last_video):
		picture.texture = _load_image(last_video)
		if picture.texture == null:
			last_video = ""
			return
		player.paused = true
	else:
		_load_player(player, last_video)
		waiting_for_frame = true
	prepare_delay = 0.25


func _prepare_next() -> void:
	# Still images remain selected for the entire session.
	if _is_image(last_video):
		return
	standby_path = _take_next()
	if standby_path.is_empty():
		return
	if _is_image(standby_path):
		standby_image = _load_image(standby_path)
		if standby_image == null:
			standby_path = ""
			return
		standby.paused = true
		standby_ready = true
	else:
		standby_image = null
		_load_player(standby, standby_path)
		warming_up = true


func _begin_transition(duration: float) -> void:
	if blending or not standby_ready:
		return
	blending = true
	blend_elapsed = 0.0
	blend_duration = minf(BLEND_SECONDS, duration)
	incoming.texture = standby_image if _is_image(standby_path) else standby.get_video_texture()
	incoming.modulate.a = 0.0
	standby.paused = not visible or _is_image(standby_path)


func _finish_transition() -> void:
	var outgoing := player
	player = standby
	standby = outgoing
	standby.paused = true
	picture.texture = incoming.texture
	incoming.modulate.a = 0.0
	incoming.texture = null
	last_video = standby_path
	standby_image = null
	standby_path = ""
	standby_ready = false
	blending = false
	prepare_delay = 0.25
	video_changed.emit()


func _start_conversion(source: String, target: String) -> void:
	if not preparer.prepare(source, target):
		failed.append(source)


func _preparation_finished(source: String, success: bool) -> void:
	if not success:
		failed.append(source)
	_scan()


func reload_assets() -> void:
	for decoder in [player, standby]:
		decoder.stop()
		decoder.stream = null
	last_video = ""
	standby_path = ""
	standby_ready = false
	warming_up = false
	blending = false
	waiting_for_frame = false
	playlist.clear()
	remaining.clear()
	failed.clear()
	picture.texture = null
	incoming.texture = null
	_scan()


func release_assets() -> void:
	# Release paused video file handles before the editor can overwrite sources.
	for decoder in [player, standby]:
		decoder.stop()
		decoder.stream = null
	standby_path = ""
	standby_ready = false
	warming_up = false
	blending = false
	waiting_for_frame = false
	incoming.texture = null
