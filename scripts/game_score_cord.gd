extends Control

# Draw behind the shared screen so the suspension never covers game controls.
var hanger: Control
var accent := Color.WHITE
var chains := false
var CHAIN = RuntimeAssets.texture("res://ui/playful/iron-chain.svg")
var previous := Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	if not is_instance_valid(hanger):
		queue_free()
		return
	var rect := hanger.get_global_rect()
	if rect != previous:
		previous = rect
		queue_redraw()
	visible = hanger.is_visible_in_tree()

func _draw() -> void:
	if not is_instance_valid(hanger):
		return
	var rect := hanger.get_global_rect()
	if chains:
		for offset in [0.18, 0.82]:
			var end := get_global_transform().affine_inverse() * Vector2(rect.position.x + rect.size.x * offset, rect.end.y)
			var start_y := maxf(0, end.y - 46) if size.x < 852 else 0.0
			var y := start_y
			while y < end.y:
				var height := minf(28, end.y - y)
				draw_texture_rect_region(CHAIN, Rect2(end.x - 8, y, 16, height), Rect2(0, 0, 16, height))
				y += 28
			if size.x < 852:
				draw_style_box(GameLook.box(Color("505a61"), Color("252c32"), 3, 1), Rect2(end.x - 14, start_y - 3, 28, 6))
		return
	var end := get_global_transform().affine_inverse() * Vector2(rect.get_center().x, rect.position.y + 15)
	var narrow := get_viewport_rect().size.x < 852
	var start := Vector2(end.x, maxf(0, end.y - 42) if narrow else 0.0)
	draw_line(start + Vector2(2, 0), end + Vector2(2, 0), accent.darkened(0.45), 7, true)
	draw_line(start, end, accent, 5, true)
	draw_line(start - Vector2(1, 0), end - Vector2(1, 0), accent.lightened(0.55), 1, true)
	if narrow:
		draw_style_box(GameLook.box(accent, accent.darkened(0.45), 4, 2), Rect2(start - Vector2(11, 4), Vector2(22, 8)))
