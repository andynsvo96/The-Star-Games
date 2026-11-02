class_name GameCanvasOverlay
extends Control

# A playfield-local blocking scrim. Modules own phase, privacy and input policy.
var heading: Label
var content: VBoxContainer
var panel: PanelContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color("071324b8")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	center.add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	heading = Label.new()
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font", GameLook.interface_font(700))
	heading.add_theme_font_size_override("font_size", 18)
	content.add_child(heading)
	resized.connect(_fit)
	hide()


func _fit() -> void:
	panel.custom_minimum_size.x = maxf(80, minf(340, size.x - 40))
	var blue := get_theme_constant("blue_studio", "GamePalette") == 1
	panel.add_theme_stylebox_override("panel", GameLook.modern_studio_sheet(blue))


func set_message(text: String) -> void:
	heading.text = text
	visible = not text.is_empty()
	_fit()
