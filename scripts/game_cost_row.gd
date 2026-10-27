class_name GameCostRow
extends HFlowContainer

# A literal, inspectable material requirement per icon. No input authority.
const DESATURATE := "shader_type canvas_item; void fragment(){ vec4 c=texture(TEXTURE,UV)*COLOR; float g=dot(c.rgb,vec3(.299,.587,.114)); COLOR=vec4(vec3(g),c.a*.55); }"

func set_items(items: Array) -> void:
	for child in get_children(): remove_child(child); child.queue_free()
	alignment = FlowContainer.ALIGNMENT_CENTER; add_theme_constant_override("h_separation",6)
	for item: Dictionary in items:
		var image := TextureRect.new(); image.texture = item.texture; image.custom_minimum_size = Vector2(32,48); image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.accessibility_name = str(item.label)+(" available" if item.get("available",false) else " missing")
		if not item.get("available",false):
			var shader := Shader.new(); shader.code = DESATURATE; var material := ShaderMaterial.new(); material.shader = shader; image.material = material
		add_child(image)
