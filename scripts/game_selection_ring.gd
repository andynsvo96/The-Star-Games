class_name GameSelectionRing
extends Control

# Shared static piece selection cue; never captures pointer or keyboard input.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.41
	var center := size / 2.0
	draw_arc(center, radius, 0, TAU, 64, Color("ffde5533"), 9, true)
	draw_arc(center, radius, 0, TAU, 64, Color("ffde55"), 3, true)
	draw_arc(center, maxf(0, radius - 3), 0, TAU, 64, Color("fff4cf"), 1, true)
