extends Control

# Module-owned landing preview; the host's disabled cells are the input gate.
var cells: Array[Button] = []
var target := -1
var icon: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func show_target(cell: int, texture: Texture2D) -> void:
	target = cell
	icon = texture
	queue_redraw()


func _draw() -> void:
	if target < 0 or cells.size() != 42 or icon == null:
		return
	var top := cells[target % 7].get_global_rect()
	var landing := cells[target].get_global_rect()
	top.position -= global_position
	landing.position -= global_position
	draw_rect(Rect2(Vector2(top.position.x, 0), Vector2(top.size.x, size.y)), Color("ffffff16"))
	draw_texture_rect(icon, landing.grow(-3), false, Color(1, 1, 1, 0.35))
	var x := top.get_center().x
	draw_colored_polygon(PackedVector2Array([Vector2(x - 5, -12), Vector2(x + 5, -12), Vector2(x, -3)]), Color("fff4cf"))
