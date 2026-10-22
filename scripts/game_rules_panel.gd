class_name GameRulesPanel
extends PanelContainer

# Illustrated public rules. Compact views keep the same list behind one button.
signal layout_changed
var items: Array = []
var compact := false
var expanded := false
var heading: Button
var body: ScrollContainer
var rows: VBoxContainer
var divider: HSeparator
var maximum_height := 260.0
var visual_scale := 1.0
var text := ""


func _init() -> void:
	add_theme_stylebox_override("panel", GameLook.rules_sheet())
	accessibility_name = "Active rules and effects"
	draw.connect(func() -> void: draw_style_box(GameLook.party_sheen(), Rect2(Vector2.ZERO, size).grow(-1)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	add_child(column)
	heading = Button.new()
	heading.text = "ACTIVE RULES / EFFECTS"
	heading.icon = RuntimeAssets.texture("res://ui/playful/rules-star.svg")
	heading.expand_icon = true
	heading.add_theme_constant_override("icon_max_width", 24)
	heading.alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.custom_minimum_size.y = 32
	heading.add_theme_font_size_override("font_size", 14)
	for mode in ["normal", "hover", "pressed", "disabled"]:
		heading.add_theme_stylebox_override(mode, StyleBoxEmpty.new())
	heading.add_theme_stylebox_override("focus", GameLook.box(Color.TRANSPARENT, Color("ffe47b"), 6, 2))
	column.add_child(heading)
	heading.pressed.connect(func() -> void:
		if compact:
			expanded = not expanded
			_fit()
			layout_changed.emit()
	)
	divider = HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color("60718b88")
	line.thickness = 1
	divider.add_theme_stylebox_override("separator", line)
	column.add_child(divider)
	body = ScrollContainer.new()
	body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(body)
	var scrollbar := body.get_v_scroll_bar()
	var track := StyleBoxEmpty.new()
	track.content_margin_left = 3; track.content_margin_right = 3
	scrollbar.add_theme_stylebox_override("scroll", track)
	for mode in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var thumb := GameLook.box(Color("738eaf77") if mode == "grabber" else Color("9ab7d9b0"), Color.TRANSPARENT, 3, 0)
		thumb.set_content_margin_all(3)
		scrollbar.add_theme_stylebox_override(mode, thumb)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	body.add_child(rows)
	rows.minimum_size_changed.connect(func() -> void: _fit.call_deferred())


func set_items(next: Array) -> void:
	if next == items: return
	items = next.duplicate(true)
	var title_font := FontVariation.new()
	title_font.base_font = get_theme_default_font()
	title_font.variation_embolden = .6
	heading.add_theme_font_override("font", title_font)
	text = ""
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var section := ""
	for item: Dictionary in items:
		var next_section := str(item.get("section", ""))
		if not next_section.is_empty() and next_section != section:
			var caption := Label.new()
			caption.text = next_section.to_upper()
			caption.add_theme_font_override("font", title_font)
			caption.add_theme_color_override("font_color", Color("ffe47b"))
			rows.add_child(caption)
			text += next_section + "\n"
		section = next_section
		text += str(item.title) + " " + str(item.detail) + "\n"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		rows.add_child(row)
		var icon := TextureRect.new()
		icon.texture = RuntimeAssets.texture(str(item.icon))
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.add_theme_constant_override("separation", 0)
		row.add_child(copy)
		for key in ["title", "detail"]:
			var label := Label.new()
			label.text = str(item[key])
			label.add_theme_font_size_override("font_size", 14 if key == "title" else 11)
			if key == "title": label.add_theme_font_override("font", title_font)
			label.add_theme_color_override("font_color", Color("f3f6ff") if key == "title" else Color("bfd3e9"))
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			copy.add_child(label)
	_scale_rows()
	_fit.call_deferred()


func fit(width: float, height: float, small: bool, scale := 1.0) -> void:
	compact = small
	maximum_height = height
	if not is_equal_approx(visual_scale, scale):
		visual_scale = scale
		var style: StyleBoxFlat = get_theme_stylebox("panel")
		style.set_content_margin_all(12 * scale)
		style.content_margin_top = 5 * scale
		style.set_corner_radius_all(int(20 * scale))
		_scale_rows()
	custom_minimum_size.x = width
	size.x = width
	_fit()


func _scale_rows() -> void:
	rows.add_theme_constant_override("separation", int(6 * visual_scale))
	for row in rows.get_children():
		if row is Label:
			row.add_theme_font_size_override("font_size", int(12 * visual_scale))
			row.custom_minimum_size.y = 24 * visual_scale
			continue
		row.add_theme_constant_override("separation", int(10 * visual_scale))
		row.get_child(0).custom_minimum_size = Vector2.ONE * 36 * visual_scale
		var copy: VBoxContainer = row.get_child(1)
		copy.get_child(0).add_theme_font_size_override("font_size", int(14 * visual_scale))
		copy.get_child(1).add_theme_font_size_override("font_size", int(11 * visual_scale))


func _fit() -> void:
	body.visible = not compact or expanded
	divider.visible = body.visible
	heading.custom_minimum_size.y = (32 if not compact else 30) * visual_scale
	var caption := "RULES / EFFECTS" if compact and size.x < 240 else "ACTIVE RULES / EFFECTS"
	heading.text = caption + ("  -" if expanded else "  +") if compact else caption
	heading.add_theme_font_size_override("font_size", int((11 if compact and size.x < 240 else 14) * visual_scale))
	heading.add_theme_constant_override("icon_max_width", int((18 if compact and size.x < 240 else 24) * visual_scale))
	heading.focus_mode = Control.FOCUS_ALL if compact else Control.FOCUS_NONE
	heading.accessibility_name = "Active rules and effects" + (", collapse" if expanded else ", expand") if compact else "Active rules and effects"
	var room := maxf(40 * visual_scale, maximum_height - 60 * visual_scale)
	var content_height := 0.0
	for row: Control in rows.get_children():
		var next_height: float = content_height + (6 * visual_scale if content_height > 0 else 0) + row.get_combined_minimum_size().y
		content_height = minf(room, next_height)
		if content_height >= room: break
	body.custom_minimum_size.y = content_height if body.visible else 0.0
	custom_minimum_size.y = 0
	size.y = get_combined_minimum_size().y
