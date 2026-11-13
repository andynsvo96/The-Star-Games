class_name GamePieceTray
extends VBoxContainer

# Reusable five-slot stock selector. The module supplies legality and ownership.
signal piece_selected(key: int)
var caption: Label
var buttons: Array[Button] = []
var items: Array = []
var selected := -1
var row: GridContainer


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	get_parent_control().resized.connect(_fit_width)
	add_theme_constant_override("separation", 4)
	caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_override("font", GameLook.interface_font(700))
	caption.add_theme_font_size_override("font_size", 13)
	add_child(caption)
	var fill := caption.get_theme_color("panel", "GamePalette")
	var backing := GameLook.box(fill, Color.TRANSPARENT, 4, 0)
	backing.set_content_margin_all(0)
	backing.shadow_size = 0
	caption.add_theme_stylebox_override("normal", backing)
	caption.add_theme_color_override("font_color", GameLook.readable_text_color(caption.get_theme_color("font_color"), fill))
	row = GridContainer.new()
	row.columns = 5
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	add_child(row)
	for index in 5:
		var button := Button.new()
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
		GameLook.board_action(button)
		button.custom_minimum_size = Vector2(44, 60)
		for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
			var style := button.get_theme_stylebox(state).duplicate()
			style.set_content_margin_all(4)
			button.add_theme_stylebox_override(state, style)
		var content := VBoxContainer.new(); content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 0)
		button.add_child(content); content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_top = 3; content.offset_bottom = -3
		var icon := TextureRect.new(); icon.custom_minimum_size.y = 30; icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.mouse_filter = Control.MOUSE_FILTER_IGNORE; content.add_child(icon)
		var count := Label.new(); count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; count.add_theme_font_override("font", GameLook.interface_font(700)); count.add_theme_font_size_override("font_size", 13); count.mouse_filter = Control.MOUSE_FILTER_IGNORE; content.add_child(count)
		button.set_meta("tray_icon", icon); button.set_meta("tray_count", count)
		button.pressed.connect(func() -> void: if index < items.size(): piece_selected.emit(int(items[index].get("key", index))))
		buttons.append(button)
	_fit_width.call_deferred()


func _fit_width() -> void:
	if not is_inside_tree(): return
	var width := maxf(44, minf(420, minf(get_viewport_rect().size.x - 48, get_parent_control().size.x)))
	custom_minimum_size.x = width
	row.columns = clampi(int((width + 4) / 48), 1, 5)


func set_items(value: Array, selection := -1, title := "Your reserve") -> void:
	items = value
	selected = selection
	var total := 0
	var choice := ""
	for index in buttons.size():
		var button := buttons[index]
		button.visible = index < items.size()
		if not button.visible: continue
		var item: Dictionary = items[index]
		var count := int(item.get("count", 0))
		total += count
		button.get_meta("tray_icon").texture = item.get("texture")
		button.get_meta("tray_count").text = "×%d" % count
		button.disabled = not item.get("enabled", false) or count == 0
		button.get_meta("tray_count").add_theme_color_override("font_color", GameLook.DISABLED_INK if button.disabled else button.get_theme_color("font_color"))
		button.get_meta("tray_icon").modulate.a = .45 if count == 0 else 1.0
		var active: bool = int(item.get("key", index)) == selected
		button.set_pressed_no_signal(active)
		button.accessibility_name = "%s, %d in reserve%s" % [item.get("label", "Piece"), count, ", selected" if active else ""]
		if active: choice = str(item.get("label", "Piece"))
	caption.text = title + (" · " + choice + " selected" if not choice.is_empty() else " · Empty" if total == 0 else "")
