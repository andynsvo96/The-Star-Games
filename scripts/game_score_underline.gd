extends Control

# A reserved line keeps the name panel still when the active turn changes.
var player: Control
var active := false


func _init() -> void:
	custom_minimum_size.y = 3
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if not active or player == null or str(player.get("text")).is_empty():
		return
	var formatted := player is RichTextLabel
	var text: String = (player as RichTextLabel).get_parsed_text() if formatted else str(player.get("text"))
	var font := player.get_theme_font("normal_font" if formatted else "font")
	var font_size := player.get_theme_font_size("normal_font_size" if formatted else "font_size")
	var width := minf(size.x, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var start := (size.x - width) / 2.0
	if player.get("horizontal_alignment") == HORIZONTAL_ALIGNMENT_LEFT:
		start = 0
	elif player.get("horizontal_alignment") == HORIZONTAL_ALIGNMENT_RIGHT:
		start = size.x - width
	draw_line(Vector2(start, 1), Vector2(start + width, 1), player.get_theme_color("default_color" if formatted else "font_color"), 2, true)
