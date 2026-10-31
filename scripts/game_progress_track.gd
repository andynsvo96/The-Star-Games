class_name GameProgressTrack
extends Control

# Public, static progress with two independent strength/count markers.
var progress := 0
var steps := 7
var approaching := 0
var defending := 0
var marker_texture: Texture2D
var goal_texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _get_minimum_size() -> Vector2: return Vector2(180, 62)


func set_progress(value: int, total: int, incoming: int, defense: int, description: String) -> void:
	accessibility_name = description
	var count := maxi(1, total); var next := clampi(value, 0, count)
	if progress == next and steps == count and approaching == incoming and defending == defense: return
	progress = next; steps = count; approaching = incoming; defending = defense; queue_redraw()


func _draw() -> void:
	var cream := GameLook.CREAM
	var gold := GameLook.GOLD
	var line := get_theme_color("panel_edge", "GamePalette")
	var start := Vector2(25, size.y / 2); var finish := Vector2(size.x - 25, start.y)
	draw_line(start, finish, line, 3, true)
	for index in range(steps + 1):
		var at := start.lerp(finish, float(index) / steps)
		draw_circle(at, 4, gold if index < progress else cream.darkened(.35), true, -1, true)
	var moving := start.lerp(finish, float(progress) / steps)
	# Keep the two count markers separate near the destination.
	moving.x = minf(moving.x,finish.x-48)
	_marker(moving, marker_texture, approaching, gold)
	_marker(finish, goal_texture, defending, cream)


func _marker(at: Vector2, texture: Texture2D, value: int, color: Color) -> void:
	var bounds := Rect2(at - Vector2(22, 25), Vector2(44, 50))
	draw_style_box(GameLook.box(GameLook.section_sheet().bg_color, color, 18, 2), bounds)
	if texture != null: GameLook.draw_texture_contained(self, texture, Rect2(at - Vector2(15, 23), Vector2(30, 23)))
	GameLook.draw_table_text(self, str(value), at + Vector2(-18, 17), 36, 17, color, true)
