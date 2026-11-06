class_name GameRoundResults
extends GridContainer

# Caller-supplied, public round metrics. This component never calculates awards.
var entries: Array = []


func _ready() -> void:
	add_theme_constant_override("h_separation", 12)
	add_theme_constant_override("v_separation", 12)
	resized.connect(_fit)


func set_results(players: Array) -> void:
	if entries == players:
		return
	entries = players.duplicate(true)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var background := get_theme_color("panel", "GamePalette")
	var edge := get_theme_color("panel_edge", "GamePalette")
	for entry in entries:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", GameLook.box(background, edge, 10, 2))
		add_child(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		panel.add_child(column)
		var header := HBoxContainer.new()
		column.add_child(header)
		var name_label := Label.new()
		name_label.text = str(entry.get("display_name", ""))
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_override("font", GameLook.interface_font(700))
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", GameLook.readable_text_color(Color(str(entry.get("color", "#527bc3"))), background))
		header.add_child(name_label)
		var crown := TextureRect.new()
		crown.texture = RuntimeAssets.texture("res://ui/playful/table-crown.svg") if entry.get("winner", false) else null
		crown.custom_minimum_size = Vector2(30, 30)
		crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crown.accessibility_name = "Winner" if entry.get("winner", false) else ""
		header.add_child(crown)
		var metrics := GridContainer.new()
		metrics.columns = 2
		metrics.add_theme_constant_override("h_separation", 12)
		metrics.add_theme_constant_override("v_separation", 8)
		column.add_child(metrics)
		for metric in entry.get("metrics", []):
			for index in 2:
				var label := Label.new()
				label.text = str(metric.get("label" if index == 0 else "value", ""))
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if index == 0 else HORIZONTAL_ALIGNMENT_RIGHT
				label.add_theme_font_override("font", GameLook.interface_font(400 if index == 0 else 700))
				label.add_theme_font_size_override("font_size", 15)
				metrics.add_child(label)
	_fit.call_deferred()


func _fit() -> void:
	columns = 2 if size.x >= 520 and entries.size() > 1 else 1
