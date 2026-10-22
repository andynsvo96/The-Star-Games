class_name GameMediaView
extends VBoxContainer

signal playback_changed(playing: bool, position_seconds: float, muted: bool)
const IMAGES := ["png", "jpg", "jpeg", "webp", "bmp"]
var picture := TextureRect.new()
var player := VideoStreamPlayer.new()
var actions := GameActionRow.new()
var play_button := Button.new()
var mute_button := Button.new()
var notice := Label.new()
var source := ""
var descriptor: Dictionary = {}
var muted := true
var suspended := false
var pending_source := ""
var pending_target := ""
var preparer: Node


func _ready() -> void:
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size.y = 160
	picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(picture)
	player.expand = true
	player.bus = "Effects"
	player.volume = 0
	player.size = Vector2.ONE
	player.position = Vector2(-2, -2)
	var decoder := Control.new()
	decoder.clip_contents = true
	decoder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(decoder)
	decoder.add_child(player)
	player.finished.connect(func() -> void: play_button.text = "PLAY"; playback_changed.emit(false, player.stream_position, muted))
	add_child(actions)
	for button in [play_button, mute_button]:
		GameLook.table_action(button, "special")
		button.custom_minimum_size.y = 44
		actions.add_child(button)
	play_button.text = "PLAY"
	mute_button.text = "SOUND: OFF"
	play_button.pressed.connect(func() -> void:
		if suspended or player.stream == null: return
		if not player.is_playing(): player.paused = false; player.play()
		elif not player.paused: player.paused = true
		else: player.paused = false
		play_button.text = "PAUSE" if player.is_playing() and not player.paused else "PLAY"
		playback_changed.emit(player.is_playing() and not player.paused, player.stream_position, muted))
	mute_button.pressed.connect(func() -> void:
		muted = not muted
		player.volume = 0 if muted else 1
		mute_button.text = "SOUND: OFF" if muted else "SOUND: ON"
		playback_changed.emit(player.is_playing() and not player.paused, player.stream_position, muted))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(notice)
	preparer = get_node("/root/BackgroundPreparer")
	preparer.prepared.connect(_prepared)
	clear()


func _process(_delta: float) -> void:
	if player.stream != null and player.is_playing() and player.stream_position > 0:
		picture.texture = player.get_video_texture()
		picture.show()


func show_media(data: Variant) -> void:
	var next: Dictionary = data if data is Dictionary else {}
	if next == descriptor: return
	clear()
	descriptor = next.duplicate(true)
	if descriptor.is_empty(): return
	show()
	notice.text = str(descriptor.get("alt", ""))
	var sources: Array = descriptor.get("sources", [])
	for path in sources:
		if path.get_extension().to_lower() in IMAGES:
			picture.texture = RuntimeAssets.texture(path)
			picture.visible = picture.texture != null
			return
	if not descriptor.get("poster", "").is_empty():
		picture.texture = RuntimeAssets.texture(descriptor.poster)
		picture.visible = picture.texture != null
	for path in sources:
		if path.get_extension().to_lower() == "ogv": _load_video(path); return
	if sources.is_empty(): return
	pending_source = sources[0]
	pending_target = BackgroundMedia.cache_path(pending_source).replace("video_backgrounds/", "media_clips/")
	if FileAccess.file_exists(pending_target): _load_video(pending_target)
	elif preparer.prepare(pending_source, pending_target, "clip"):
		notice.text += "\nPreparing local video…"
	else: notice.text += "\nVideo needs an .ogv source on this host."


func _load_video(path: String) -> void:
	source = path
	var video := VideoStreamTheora.new()
	video.file = path
	player.stream = video
	player.show()
	picture.show()
	actions.show()
	play_button.disabled = suspended
	# User-controlled clips never autoplay, loop, or advance on reconnection.
	player.stop()


func _prepared(original: String, success: bool) -> void:
	if original != pending_source or descriptor.is_empty(): return
	if success: _load_video(pending_target); notice.text = str(descriptor.get("alt", ""))
	else: notice.text = str(descriptor.get("alt", "")) + "\nVideo unavailable. Supply .ogv or install FFmpeg on a desktop host."


func set_suspended(value: bool) -> void:
	if suspended == value: return
	suspended = value
	if value and player.is_playing() and not player.paused:
		player.paused = true
		play_button.text = "PLAY"
		playback_changed.emit(false, player.stream_position, muted)
	play_button.disabled = value
	mute_button.disabled = value


func clear() -> void:
	descriptor.clear()
	source = ""
	pending_source = ""
	pending_target = ""
	player.stop()
	player.stream = null
	player.paused = false
	play_button.text = "PLAY"
	player.hide()
	picture.texture = null
	picture.hide()
	actions.hide()
	hide()
