extends PanelContainer

# Opt-in dossier paper layers share the panel's nine-slice texture and theme.
func _draw() -> void:
	var front := get_theme_stylebox("panel")
	if not front is StyleBoxTexture:
		return
	var rear: StyleBoxTexture = front.duplicate()
	rear.modulate_color = Color("bca27b")
	draw_set_transform(Vector2(-3, -5), -0.012)
	draw_style_box(rear, Rect2(Vector2.ZERO, size))
	draw_set_transform(Vector2(4, -2), 0.009)
	draw_style_box(rear, Rect2(Vector2.ZERO, size))
	draw_set_transform(Vector2.ZERO)
	draw_style_box(front, Rect2(Vector2.ZERO, size))
