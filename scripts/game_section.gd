class_name GameSection
extends PanelContainer

# Shared navy section chrome for compact rosters, inventories and public feeds.
var heading := Label.new()
var summary := Label.new()
var content := VBoxContainer.new()
var header := GridContainer.new()
var caption := ""
var column := GridContainer.new()
var center_heading := false
var leading := Control.new()
var metric := HBoxContainer.new()
var summary_icon := TextureRect.new()
var inline_header := false
var header_action: Button

func set_header_action(button: Button) -> void:
	if is_instance_valid(header_action) and header_action.get_parent() == metric: metric.remove_child(header_action)
	header_action = button
	if button != null:
		metric.add_child(button); button.custom_minimum_size = Vector2(44,44); button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_layout_header()

func set_summary_metric(texture: Texture2D, value: Variant, description: String) -> void:
	summary_icon.texture = texture; summary_icon.visible = texture != null; summary.text = str(value); metric.accessibility_name = description
	summary.add_theme_font_size_override("font_size",13 if inline_header else 16)
	_layout_header()

func _layout_header() -> void:
	leading.visible = center_heading and not inline_header
	header.columns = 1 if inline_header else 3 if center_heading else 2
	leading.custom_minimum_size.x = metric.get_combined_minimum_size().x
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center_heading else HORIZONTAL_ALIGNMENT_LEFT

func set_inline_header(enabled: bool) -> void:
	inline_header = enabled; column.columns = 2 if enabled else 1
	summary.add_theme_font_size_override("font_size",13 if enabled and summary_icon.visible else 11 if enabled else 16 if summary_icon.visible else 13)
	_layout_header()

func _ready() -> void:
	add_theme_stylebox_override("panel",GameLook.section_sheet())
	column.columns = 1; column.add_theme_constant_override("h_separation",0); column.add_theme_constant_override("v_separation",0); add_child(column)
	var top := PanelContainer.new(); top.custom_minimum_size.y = 44; top.add_theme_stylebox_override("panel",GameLook.section_header_sheet()); column.add_child(top)
	header.columns = 2; header.size_flags_vertical = Control.SIZE_SHRINK_CENTER; header.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_theme_constant_override("h_separation",8); header.add_theme_constant_override("v_separation",0); top.add_child(header); header.add_child(leading)
	heading.text = caption; heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; heading.add_theme_font_size_override("font_size",19); heading.add_theme_color_override("font_color",GameLook.CREAM); heading.add_theme_font_override("font",GameLook.interface_font()); header.add_child(heading)
	var bold := FontVariation.new(); bold.base_font = GameLook.interface_font(); bold.variation_embolden = .6; heading.add_theme_font_override("font",bold)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	metric.alignment = BoxContainer.ALIGNMENT_CENTER; metric.size_flags_vertical = Control.SIZE_SHRINK_CENTER; metric.add_theme_constant_override("separation",4); header.add_child(metric)
	summary_icon.custom_minimum_size = Vector2(20,22); summary_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; summary_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; summary_icon.hide(); metric.add_child(summary_icon)
	summary.add_theme_font_size_override("font_size",13); summary.add_theme_color_override("font_color",GameLook.CREAM); summary.add_theme_font_override("font",GameLook.interface_font()); summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; metric.add_child(summary)
	top.visible = not caption.is_empty()
	var inset := MarginContainer.new(); inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL; column.add_child(inset)
	for side in ["left","right","top","bottom"]: inset.add_theme_constant_override("margin_"+side,8)
	content.add_theme_constant_override("separation",4); inset.add_child(content)
	resized.connect(_layout_header); _layout_header()
