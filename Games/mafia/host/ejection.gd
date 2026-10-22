extends Control

# The white alignment types in behind a five-second flight and final hold.
var avatar: Texture2D
var message: Label
var player_color := Color.WHITE
var progress := 0.0
var reduced_motion := false


func _init() -> void:
	custom_minimum_size = Vector2(220, 164)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var backdrop := TextureRect.new()
	backdrop.texture = RuntimeAssets.texture("res://Games/mafia/art/ejection-space.svg")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.show_behind_parent = true
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message = Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.show_behind_parent = true
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.add_theme_color_override("font_color", Color.WHITE)
	message.add_theme_color_override("font_outline_color", Color("080c13"))
	message.add_theme_constant_override("outline_size", 3)
	add_child(message)
	message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(func() -> void: message.add_theme_font_size_override("font_size", 22 if size.x < 400 else 30))


func configure(player: Dictionary, reduced: bool, mafia: bool, reveal := true) -> void:
	avatar = RuntimeAssets.texture("res://web/avatar-%d.svg" % clampi(int(player.get("pose", 0)), 0, 5))
	player_color = Color(str(player.get("color", "#58d6ff")))
	reduced_motion = reduced
	message.offset_bottom = -68 if reduced else 0
	message.text = "%s %s." % [player.get("display_name", "Player"), ("is Mafia" if mafia else "is innocent") if reveal else "was voted out"]
	queue_redraw()


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	message.visible_characters = -1 if reduced_motion else int(ceil(message.get_total_character_count() * clampf((progress - 0.12) / 0.43, 0.0, 1.0)))
	queue_redraw()


func _draw() -> void:
	if avatar == null:
		return
	var flight := clampf(progress / (5.0 / 6.5), 0.0, 1.0)
	var x := size.x / 2.0 if reduced_motion else lerpf(-48, size.x + 48, flight)
	draw_set_transform(Vector2(x, size.y - 32 if reduced_motion else size.y / 2.0), 0.0 if reduced_motion else flight * TAU)
	draw_texture_rect(avatar, Rect2(-27, -32, 54, 64) if reduced_motion else Rect2(-40, -48, 80, 96), false, player_color)
