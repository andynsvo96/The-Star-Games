class_name GamePhaseTrack
extends Control

# Static snapshot-driven phase feedback; no gameplay or timer ownership.
var steps: Array[String] = ["First", "Second"]
var current_index := 0
var compact := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _get_minimum_size() -> Vector2: return Vector2(steps.size() * 32 if compact else maxi(240, steps.size() * 48), 42 if compact else 58)


func set_current(index: int) -> void:
	accessibility_name = "Current stage: " + (steps[index] if index >= 0 and index < steps.size() else "")
	if current_index == index: return
	current_index = index
	queue_redraw()


func _draw() -> void:
	if steps.is_empty(): return
	var text := get_theme_color("font_color", "Label")
	var muted := text.darkened(.35)
	var active := get_theme_color("gold", "GamePalette")
	var width := size.x / steps.size()
	var offset := -12.0 if compact else 0.0
	if not compact: GameLook.draw_table_text(self, "CURRENT STAGE", Vector2(0, 12), size.x, 11, text, true)
	draw_line(Vector2(width / 2, 28 + offset), Vector2(size.x - width / 2, 28 + offset), muted, 1)
	for index in steps.size():
		var point := Vector2(width * (index + .5), 28 + offset)
		draw_circle(point, 6 if index == current_index else 4, active if index == current_index else get_theme_color("panel", "GamePalette"))
		draw_arc(point, 6 if index == current_index else 4, 0, TAU, 24, active if index == current_index else muted, 1, true)
		GameLook.draw_table_text(self, steps[index], Vector2(width * index, 52 + offset), width, 12, active if index == current_index else muted, true)
