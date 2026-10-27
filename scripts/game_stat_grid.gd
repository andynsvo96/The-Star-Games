class_name GameStatGrid
extends GridContainer

# Public presentation only. Callers filter private values before supplying them.
var values: Array[Label] = []
var icons: Array[TextureRect] = []
var captions: Array[Label] = []
var maximum_columns := 3

func _ready() -> void:
	columns = 3; size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("h_separation",8); add_theme_constant_override("v_separation",8)
	resized.connect(_fit)

func set_metrics(metrics: Array) -> void:
	while values.size() < metrics.size():
		var panel := PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; panel.custom_minimum_size = Vector2(124,70)
		var style := GameLook.card_table_sheet(); style.set_content_margin_all(9); panel.add_theme_stylebox_override("panel",style); add_child(panel)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation",8); panel.add_child(row)
		var icon := TextureRect.new(); icon.custom_minimum_size = Vector2(30,32); icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; row.add_child(icon); icons.append(icon)
		icon.draw.connect(_draw_highlight.bind(icon))
		var column := VBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; column.add_theme_constant_override("separation",0); row.add_child(column)
		var value := Label.new(); value.add_theme_font_size_override("font_size",24); value.add_theme_color_override("font_color",GameLook.SCROLL_INK); column.add_child(value); values.append(value)
		var caption := Label.new(); caption.add_theme_font_size_override("font_size",11); caption.add_theme_color_override("font_color",GameLook.SCROLL_INK); caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(caption); captions.append(caption)
	for index in values.size():
		get_child(index).visible = index < metrics.size()
		if index >= metrics.size(): continue
		var metric: Dictionary = metrics[index]
		values[index].text = str(metric.value); captions[index].text = str(metric.label); icons[index].texture = metric.get("texture")
		icons[index].set_meta("highlighted",bool(metric.get("highlighted",false))); icons[index].queue_redraw()
		get_child(index).accessibility_name = str(metric.label)+": "+str(metric.value)
	_fit()

func _fit() -> void:
	columns = 4 if maximum_columns >= 4 and size.x >= 560 else 3 if size.x >= 410 else 2 if size.x >= 260 else 1

func _draw_highlight(icon: TextureRect) -> void:
	if icon.get_meta("highlighted",false): icon.draw_style_box(GameLook.box(Color("ffe49a22"),Color("dfa823"),4,2),Rect2(Vector2.ZERO,icon.size))
