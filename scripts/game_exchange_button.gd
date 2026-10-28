class_name GameExchangeButton
extends Button

# Bounded, literal exchange terms inside their actual confirmation target.
var content := VBoxContainer.new()
var action_label := "Exchange resources"
var signature := ""
var applied_disabled := -1

func _ready() -> void:
	tooltip_text = ""; text = ""; custom_minimum_size.y = 52
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE; content.add_theme_constant_override("separation",4); add_child(content)
	resized.connect(_layout)
	GameLook.outline_disabled(self)

func _layout() -> void:
	var height := content.get_combined_minimum_size().y
	custom_minimum_size.y = maxf(52,height+12); content.position = Vector2(8,(size.y-height)/2); content.size = Vector2(maxf(0,size.x-16),height)

func _draw() -> void:
	if applied_disabled == int(disabled): return
	applied_disabled = int(disabled)
	for label in content.find_children("*","Label",true,false): label.add_theme_color_override("font_color",Color("afbec7") if disabled else Color("97e891") if label.text == "✓" else GameLook.CREAM)
	for label in content.find_children("*","RichTextLabel",true,false): label.add_theme_color_override("default_color",Color("afbec7") if disabled else GameLook.CREAM)
	for picture in content.find_children("*","TextureRect",true,false): picture.modulate.a = .65 if disabled else 1.0

func set_exchanges(items: Array) -> void:
	var next := str(items)
	if next == signature: return
	signature = next; applied_disabled = -1
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	var descriptions := PackedStringArray([action_label])
	for item: Dictionary in items:
		var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_theme_constant_override("separation",6); content.add_child(row)
		var counts := RichTextLabel.new(); counts.fit_content = true; counts.scroll_active = false; counts.bbcode_enabled = false; counts.mouse_filter = Control.MOUSE_FILTER_IGNORE; counts.custom_minimum_size = Vector2(84 if int(item.rate) < int(item.get("default_rate",4)) else 60,26)
		counts.add_theme_font_override("normal_font",GameLook.interface_font()); counts.add_theme_font_size_override("normal_font_size",16); counts.add_theme_color_override("default_color",GameLook.CREAM); row.add_child(counts)
		counts.add_text("%d / " % int(item.owned))
		if int(item.rate) < int(item.get("default_rate",4)):
			counts.push_color(Color("ff8b96")); counts.push_strikethrough(); counts.add_text(str(item.get("default_rate",4))); counts.pop(); counts.pop(); counts.add_text(" "+str(item.rate))
		else: counts.add_text(str(item.rate))
		counts.custom_minimum_size.x = counts.get_theme_font("normal_font").get_string_size(counts.get_parsed_text(),HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+2
		for part in [{"texture":item.give_texture},{"text":"⚓" if item.get("port",false) else ""},{"text":"= 1"},{"texture":item.take_texture},{"text":"✓"}]:
			if part.has("texture"):
				var image := TextureRect.new(); image.texture = part.texture; image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.custom_minimum_size = Vector2(28,32); image.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(image)
			elif not str(part.text).is_empty():
				var label := Label.new(); label.text = part.text; label.mouse_filter = Control.MOUSE_FILTER_IGNORE; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; label.add_theme_font_override("font",GameLook.interface_font()); label.add_theme_font_size_override("font_size",18); label.add_theme_color_override("font_color",Color("97e891") if part.text == "✓" else GameLook.CREAM); row.add_child(label)
		descriptions.append(str(item.label))
	accessibility_name = ". ".join(descriptions); _layout.call_deferred()
