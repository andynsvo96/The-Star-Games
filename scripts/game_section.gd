class_name GameSection
extends PanelContainer

# Shared navy section chrome for compact rosters, inventories and public feeds.
var heading := Label.new()
var summary := Label.new()
var content := VBoxContainer.new()
var header := GridContainer.new()
var caption := ""
var column := GridContainer.new()

func set_inline_header(enabled: bool) -> void:
	column.columns = 2 if enabled else 1; header.columns = 1 if enabled else 2
	summary.add_theme_font_size_override("font_size",11 if enabled else 13)

func _ready() -> void:
	add_theme_stylebox_override("panel",GameLook.section_sheet())
	column.columns = 1; column.add_theme_constant_override("h_separation",0); column.add_theme_constant_override("v_separation",0); add_child(column)
	var top := PanelContainer.new(); top.add_theme_stylebox_override("panel",GameLook.section_header_sheet()); column.add_child(top)
	header.columns = 2; header.custom_minimum_size.y = 44; header.add_theme_constant_override("h_separation",8); header.add_theme_constant_override("v_separation",0); top.add_child(header)
	heading.text = caption; heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; heading.add_theme_font_size_override("font_size",19); heading.add_theme_color_override("font_color",GameLook.CREAM); heading.add_theme_font_override("font",GameLook.interface_font()); header.add_child(heading)
	var bold := FontVariation.new(); bold.base_font = GameLook.interface_font(); bold.variation_embolden = .6; heading.add_theme_font_override("font",bold)
	summary.add_theme_font_size_override("font_size",13); summary.add_theme_color_override("font_color",GameLook.CREAM); summary.add_theme_font_override("font",GameLook.interface_font()); header.add_child(summary)
	top.visible = not caption.is_empty()
	var inset := MarginContainer.new(); inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL; column.add_child(inset)
	for side in ["left","right","top","bottom"]: inset.add_theme_constant_override("margin_"+side,8)
	content.add_theme_constant_override("separation",4); inset.add_child(content)
