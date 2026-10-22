class_name GameActionRow
extends Container

# A stable, single-line toolbar. Text fits the available width; controls never wrap.
var preferred_font_size := 16
var row_height := 44.0
var fit_icons := false


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(queue_sort)
	child_order_changed.connect(queue_sort)


func _get_minimum_size() -> Vector2:
	return Vector2(0, row_height)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN: _fit()


func _fit() -> void:
	var buttons: Array[Button] = []
	for child in get_children():
		if child is Button and child.visible: buttons.append(child)
	if buttons.is_empty(): return
	var gap := 8.0 if size.x >= 700 else 4.0
	var available := maxf(0, size.x - gap * (buttons.size() - 1))
	var font_size := preferred_font_size
	var widths: Array[float] = []
	var total := 0.0
	while true:
		widths.clear(); total = 0
		for button in buttons:
			var width := maxf(44, button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 24)
			if fit_icons and button.icon != null:
				var limit := button.get_theme_constant("icon_max_width")
				var icon_width := minf(button.icon.get_width(), limit if limit > 0 else row_height - 8)
				width += icon_width + button.get_theme_constant("h_separation")
			widths.append(width); total += width
		if total <= available or font_size <= 11: break
		font_size -= 1
	var scale := minf(1, available / maxf(1, total))
	var left := maxf(0, (size.x - total * scale - gap * (buttons.size() - 1)) / 2)
	for index in buttons.size():
		var button := buttons[index]
		if not button.has_meta("action_row_fitted"):
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				var surface := button.get_theme_stylebox(state).duplicate() as StyleBox
				surface.content_margin_left = 8; surface.content_margin_right = 8
				surface.content_margin_top = 4; surface.content_margin_bottom = 4
				button.add_theme_stylebox_override(state, surface)
			button.set_meta("action_row_fitted", true)
		button.clip_text = true; button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.accessibility_name = button.text; button.custom_minimum_size = Vector2(0, row_height)
		button.add_theme_font_size_override("font_size", font_size)
		button.position = Vector2(left, 0); button.size = Vector2(widths[index] * scale, row_height)
		left += widths[index] * scale + gap
