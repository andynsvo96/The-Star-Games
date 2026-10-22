extends Control

# Coordinates occupy the wood frame, leaving all 64 playing squares clear.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var font := get_theme_font("font", "Label")
	var font_size := int(clampf(size.x / 32, 8, 12))
	var ascent := font.get_ascent(font_size)
	for index in 8:
		var file := String.chr(97 + index)
		var rank := str(8 - index)
		var x := size.x * (index + 0.5) / 8
		var y := size.y * (index + 0.5) / 8 + ascent / 2
		var file_width := font.get_string_size(file, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var rank_width := font.get_string_size(rank, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		for baseline in [-3.0, size.y + ascent + 2]:
			draw_string(font, Vector2(x - file_width / 2, baseline), file, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, GameLook.CREAM)
		for center_x in [-8.0, size.x + 8]:
			draw_string(font, Vector2(center_x - rank_width / 2, y), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, GameLook.CREAM)
