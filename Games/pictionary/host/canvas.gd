extends Control

const Rules = preload("res://Games/pictionary/host/rules.gd")
var strokes: Array = []
var hint := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func set_drawing(value: Array, text: String) -> void:
	strokes = value
	hint = text
	queue_redraw()


func paper_rect() -> Rect2:
	return Rect2(Vector2(6, 6), size - Vector2(12, 12))


func _draw() -> void:
	draw_style_box(GameLook.drawing_sheet(), Rect2(Vector2.ZERO, size))
	var paper := paper_rect()
	draw_rect(paper, Color(Rules.INKS[-1]))
	var origin := paper.position + Vector2(0, paper.size.y * 0.1)
	var area := Vector2(paper.size.x, paper.size.y * 0.9)
	for stroke in strokes:
		var color := Color(Rules.INKS[int(stroke.color)])
		var widths: Array = Rules.ERASER_WIDTHS if int(stroke.color) == 7 else Rules.WIDTHS
		var width := float(widths[int(stroke.width)]) * area.x / 1000.0
		var previous := Vector2.ZERO
		for index in stroke.points.size():
			var point: Array = stroke.points[index]
			var position := origin + Vector2(float(point[0]) / 1000.0, float(point[1]) / 700.0) * area
			draw_circle(position, width * 0.5, color)
			if index > 0:
				draw_line(previous, position, color, width, true)
			previous = position
	if not hint.is_empty():
		var font := get_theme_font("font", "Label")
		var font_size := int(clampf(paper.size.x / maxf(14, hint.length()) * 1.05, 8, minf(28, paper.size.y * 0.085)))
		var text_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, paper.position + Vector2((paper.size.x - text_width) / 2, paper.size.y * 0.085), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(Rules.INKS[0]))
