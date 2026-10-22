extends "res://scripts/title_background.gd"

var source_stem := ""
var phase_overlay := TextureRect.new()
var phase_tween: Tween
var phase_pending := false
var reduced_motion := false:
	set(value):
		reduced_motion = value
		freeze_motion = value
		if is_node_ready():
			if value:
				_clear_phase_transition()
			set_active(visible)


func _ready() -> void:
	super._ready()
	phase_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	phase_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	phase_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	phase_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(phase_overlay)
	phase_overlay.hide()


# Keep media resolution/playback shared when a game changes scenery by phase.
func transition_to(stem: String, animate := true) -> void:
	if stem == source_stem:
		return
	if is_instance_valid(phase_tween):
		phase_tween.kill()
	phase_pending = false
	var phase_animate := animate and not reduced_motion
	if is_node_ready() and phase_animate and picture.texture != null:
		var frame := picture.texture.get_image()
		if frame != null and not frame.is_empty():
			phase_overlay.texture = ImageTexture.create_from_image(frame)
			phase_overlay.modulate.a = 1.0
			phase_overlay.show()
			phase_pending = true
	else:
		phase_overlay.hide()
		phase_overlay.texture = null
	source_stem = stem
	if is_node_ready():
		picture.texture = null
		_scan()


func _process(delta: float) -> void:
	super._process(delta)
	if phase_pending and visible and picture.texture != null and not waiting_for_frame:
		phase_pending = false
		phase_tween = create_tween()
		phase_tween.tween_property(phase_overlay, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		phase_tween.tween_callback(_clear_phase_transition)


func _clear_phase_transition() -> void:
	if is_instance_valid(phase_tween):
		phase_tween.kill()
	phase_pending = false
	phase_overlay.hide()
	phase_overlay.texture = null


# Reuse the title's silent, covering player and prepared-loop crossfade.
func _scan() -> void:
	var selected := ""
	for source in BackgroundMedia.candidates(source_stem):
		if failed.has(source):
			continue
		var extension := source.get_extension().to_lower()
		if extension in BackgroundMedia.IMAGE_EXTENSIONS or extension == "ogv":
			selected = source
			break
		var cached := BackgroundMedia.cache_path(source)
		if FileAccess.file_exists(cached):
			selected = cached
			break
		_start_conversion(source, cached)
	# Display a same-name image while desktop video conversion is in progress.
	playlist.assign([selected] if not selected.is_empty() else [])
	if selected == last_video:
		return
	for decoder in [player, standby]:
		decoder.stop()
		decoder.stream = null
	last_video = ""
	standby_path = ""
	standby_ready = false
	warming_up = false
	blending = false
	waiting_for_frame = false
	incoming.texture = null
	incoming.modulate.a = 0.0
	if selected.is_empty():
		picture.texture = null
	remaining.assign(playlist)
	if visible:
		_play_next()


func set_active(active: bool) -> void:
	if not active:
		_clear_phase_transition()
	super.set_active(active)
	if reduced_motion and not waiting_for_frame:
		player.paused = true
		standby.paused = true
