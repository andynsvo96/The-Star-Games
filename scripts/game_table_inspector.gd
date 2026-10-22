class_name GameTableInspector
extends PanelContainer

# Reusable public-card inspector. Callers supply semantic rows, never game rules.
signal card_pressed(card: Dictionary)
var heading := Label.new()
var summary := Label.new()
var body := VBoxContainer.new()
var cards := GameCardGrid.new()
var rows := VBoxContainer.new()
var scroll := ScrollContainer.new()
var entries: Array = []
var content_key := ""


func _ready() -> void:
	add_theme_stylebox_override("panel", GameLook.modern_table_sheet())
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 12); add_child(column)
	heading.add_theme_font_size_override("font_size", 20); heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(heading)
	summary.add_theme_color_override("font_color", Color("91e9b5")); summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(summary)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; column.add_child(scroll)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 14); scroll.add_child(body)
	body.add_child(cards); body.add_child(rows); cards.card_pressed.connect(func(card: Dictionary) -> void: card_pressed.emit(card))
	resized.connect(_fit_cards)
	scroll.resized.connect(_fit_cards)


func set_content(title: String, subtitle: String, items: Array, details: Array, key: String, slots := 0) -> void:
	if not is_node_ready(): await ready
	heading.text = title; summary.text = subtitle
	if key == content_key: return
	content_key = key; entries = items
	for child in rows.get_children(): rows.remove_child(child); child.queue_free()
	cards.fixed_columns = maxi(slots, maxi(1, items.size())); cards.set_items(items)
	for detail in details:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8)
		var label := Label.new(); label.text = str(detail[0]); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; label.add_theme_font_size_override("font_size", 14)
		var value := Label.new(); value.text = str(detail[1]); value.add_theme_color_override("font_color", Color("ffd447")); value.add_theme_font_size_override("font_size", 15)
		row.add_child(label); row.add_child(value); rows.add_child(row)
	_fit_cards.call_deferred()


func _fit_cards() -> void:
	var count := maxi(1, ceili(float(entries.size()) / maxi(1, cards.fixed_columns)))
	var available := maxf(54, scroll.size.y - rows.get_combined_minimum_size().y - 22)
	cards.preferred_width = minf(100, available / count / 1.5)
	cards._fit()
