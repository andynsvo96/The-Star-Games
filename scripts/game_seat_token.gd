class_name GameSeatToken
extends Control

var seat := 1
var identity := Color("527bc3")


func _init() -> void:
	custom_minimum_size = Vector2(32, 32)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var radius := minf(size.x, size.y) / 2 - 2
	draw_circle(size / 2, radius, identity)
	draw_arc(size / 2, radius, 0, TAU, 40, Color("fff1d9"), 2, true)
	var font := get_theme_font("font", "Label")
	var caption := str(seat)
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	var baseline := (font.get_ascent(17) - font.get_descent(17)) / 2
	var point := size / 2 + Vector2(-width / 2, baseline)
	draw_string_outline(font, point, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 4, Color("171717"))
	draw_string(font, point, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
