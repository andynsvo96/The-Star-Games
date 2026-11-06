class_name GameIllustratedGuide
extends VBoxContainer

# Static public examples. The enclosing phase dialog owns scrolling and Close.
var items: Array = []


func set_items(examples: Array) -> void:
	if items == examples:
		return
	items = examples.duplicate(true)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 24)
	for example in items:
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 8)
		add_child(section)
		var heading := Label.new()
		heading.text = str(example.get("heading", ""))
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		heading.add_theme_font_override("font", GameLook.interface_font(700))
		heading.add_theme_font_size_override("font_size", 21)
		section.add_child(heading)
		var picture := TextureRect.new()
		picture.texture = RuntimeAssets.texture(str(example.get("image", "")))
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size.y = 210
		picture.accessibility_name = str(example.get("description", ""))
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		section.add_child(picture)
		var detail := Label.new()
		detail.text = str(example.get("detail", ""))
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_font_override("font", GameLook.interface_font())
		detail.add_theme_font_size_override("font_size", 16)
		section.add_child(detail)
