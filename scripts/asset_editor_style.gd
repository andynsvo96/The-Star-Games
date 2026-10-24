extends RefCounted

# Shared surfaces for the desktop media and skin editors.
const BACKGROUND := Color("10141c")
const TOOLBAR := Color("222936")
const BROWSER := Color("172638")
const INSPECTOR := Color("1b202b")
const MUTED := Color("aebed1")
const ACCENT := Color("82c4ff")


static func box(color: Color, inset := 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("3b4c63")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(inset)
	return style


static func panel(color: Color, inset := 14) -> PanelContainer:
	var result := PanelContainer.new()
	result.add_theme_stylebox_override("panel", box(color, inset))
	return result


static func label(text: String, font_size := 14, color := MUTED) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result


static func field(parent: Container, caption: String, control: Control) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	parent.add_child(column)
	column.add_child(label(caption, 12))
	column.add_child(control)
	control.custom_minimum_size.y = 44
