class_name GameSelectionRing
extends Control

var color := Color("ffde55"):
	set(value):
		if color == value: return
		color = value
		queue_redraw()

var capture := false:
	set(value):
		if capture == value: return
		capture = value
		queue_redraw()

# Shared static piece selection cue; never captures pointer or keyboard input.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var edge := minf(size.x, size.y)
	var radius := edge * (0.46 if capture else 0.41)
	var center := size / 2.0
	var ink := Color("ff9d7d") if capture else color
	draw_arc(center, radius, 0, TAU, 64, Color(ink, .2), 9, true)
	draw_arc(center, radius, 0, TAU, 64, ink, 3, true)
	draw_arc(center, maxf(0, radius - 3), 0, TAU, 64, ink.lerp(Color.WHITE,.65), 1, true)
	if capture:
		var badge := Vector2(size.x * .82, size.y * .18)
		var unit := maxf(5, edge * .14)
		draw_circle(badge, unit, Color("70332b"))
		draw_arc(badge, unit, 0, TAU, 32, ink, 1, true)
		# Crossed blades and guards keep the meaning visible without color or motion.
		for direction in [-1, 1]:
			draw_line(badge + Vector2(-.55 * direction, .55) * unit, badge + Vector2(.55 * direction, -.55) * unit, Color("fff4df"), maxf(1, unit * .2), true)
			draw_line(badge + Vector2(-.55 * direction, .05) * unit, badge + Vector2(-.05 * direction, .55) * unit, ink, maxf(1, unit * .16), true)
