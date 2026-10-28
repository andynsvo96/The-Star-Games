class_name GameCostRow
extends HFlowContainer

# A literal, inspectable material requirement per icon. No input authority.
const DESATURATE := "shader_type canvas_item; void fragment(){ vec4 c=COLOR; float g=dot(c.rgb,vec3(.299,.587,.114)); COLOR=vec4(vec3(g),c.a*.65); }"
var dark := false
var highlight_counts := false

func set_items(items: Array) -> void:
	for child in get_children(): remove_child(child); child.queue_free()
	alignment = FlowContainer.ALIGNMENT_CENTER; add_theme_constant_override("h_separation",6)
	for item: Dictionary in items:
		var detailed: bool = item.has("owned") and item.has("required")
		var destination: Node = self
		if detailed:
			var panel := PanelContainer.new(); panel.custom_minimum_size.x = 112
			panel.add_theme_stylebox_override("panel",GameLook.modern_table_sheet() if dark else GameLook.card_table_sheet()); add_child(panel)
			var column := VBoxContainer.new(); column.alignment = BoxContainer.ALIGNMENT_CENTER; column.add_theme_constant_override("separation",3); panel.add_child(column); destination = column
			panel.accessibility_name = "%s: have %d, need %d" % [item.label,int(item.owned),int(item.required)]
		var image := TextureRect.new(); image.texture = item.texture; image.custom_minimum_size = Vector2(32,48); image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if detailed: image.custom_minimum_size = Vector2(48,54)
		image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		image.accessibility_name = str(item.label)+(" available" if item.get("available",false) else " missing")
		if not item.get("available",false):
			var shader := Shader.new(); shader.code = DESATURATE; var material := ShaderMaterial.new(); material.shader = shader; image.material = material
		destination.add_child(image)
		if detailed:
			for row in [[str(item.label),13],["%d / %d" % [int(item.owned),int(item.required)],22],["Ready" if int(item.owned) >= int(item.required) else "Need %d more" % (int(item.required)-int(item.owned)),12]]:
				var label := Label.new(); label.text = str(row[0]); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size",int(row[1])); label.add_theme_color_override("font_color",GameLook.CREAM if dark else GameLook.SCROLL_INK); destination.add_child(label)
				if highlight_counts and int(row[1]) == 22:
					var covered: bool = int(item.owned) >= int(item.required)
					label.add_theme_color_override("font_color",Color("91ffc8") if covered and dark else Color("ff98ac") if dark else Color("197f52") if covered else Color("ac284b"))
