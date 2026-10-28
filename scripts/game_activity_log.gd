class_name GameActivityLog
extends PanelContainer

signal expand_requested

# A bounded public activity feed. Callers supply plain text, newest first.
var scroll := ScrollContainer.new()
var entries := VBoxContainer.new()
var heading := Label.new()
var signature := ""
var animations: Array[Tween] = []
var initialized := false
var show_heading := true
var bold_latest := false
var entry_font_size := 11
var paper := false
var applied_font_size := -1
var applied_separators := false
var applied_bold_latest := false
var maximum_entries := 0
var separators := false
var expandable := false
var sectioned := false
var dense := false
var compact_text := false
var show_all := Button.new()
var header := HBoxContainer.new()
var body_font: Font

func set_dense(enabled: bool) -> void:
	if dense == enabled: return
	dense = enabled
	entries.add_theme_constant_override("separation",3 if enabled else 6)

func _ready() -> void:
	clip_contents = true; accessibility_name = "Activity history"
	if compact_text or sectioned:
		body_font = GameLook.interface_font()
	focus_mode = Control.FOCUS_ALL if expandable else Control.FOCUS_NONE
	gui_input.connect(func(event: InputEvent) -> void:
		if expandable and (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed or event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER,KEY_SPACE]):
			expand_requested.emit(); accept_event()
	)
	var style := GameLook.card_table_sheet() if paper else GameLook.modern_table_sheet(); style.content_margin_left = 12 if paper else 7; style.content_margin_right = 12 if paper else 7; style.content_margin_top = 10 if paper else 6; style.content_margin_bottom = 10 if paper else 6
	if sectioned:
		style = GameLook.section_sheet()
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 4); add_child(column)
	var header_parent: Node = column
	if sectioned:
		var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel",GameLook.section_header_sheet()); column.add_child(panel); header_parent = panel
	header.add_theme_constant_override("separation",8); header_parent.add_child(header)
	heading.text = "History" if paper else "Activity"; heading.add_theme_font_size_override("font_size",19 if sectioned else 17 if paper else 12); heading.add_theme_color_override("font_color",GameLook.SCROLL_INK if paper else GameLook.CREAM); heading.clip_text = true; heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(heading)
	if body_font != null:
		heading.add_theme_font_override("font",body_font)
		var bold := FontVariation.new(); bold.base_font = body_font; bold.variation_embolden = .6; heading.add_theme_font_override("font",bold)
	show_all.text = "Show All"; show_all.flat = true; show_all.custom_minimum_size = Vector2(70,44); show_all.add_theme_font_size_override("font_size",13); show_all.tooltip_text = ""; show_all.visible = sectioned and expandable; show_all.pressed.connect(func() -> void: expand_requested.emit()); header.add_child(show_all)
	if body_font != null: show_all.add_theme_font_override("font",body_font)
	var body := MarginContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_child(body)
	for side in ["left","right","top","bottom"]: body.add_theme_constant_override("margin_"+side,10 if sectioned and side in ["left","right"] else 4 if sectioned else 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_child(scroll)
	if expandable:
		scroll.mouse_filter = Control.MOUSE_FILTER_PASS; scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		entries.mouse_filter = Control.MOUSE_FILTER_PASS
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL; entries.add_theme_constant_override("separation", 3 if dense else 6); scroll.add_child(entries)
	heading.visible = show_heading
	header.visible = show_heading
	resized.connect(func() -> void: header.visible = show_heading and size.x >= 72)

func set_entries(items: Array, reduced := false, paused := false) -> void:
	if maximum_entries > 0: items = items.slice(0,maximum_entries)
	for animation in animations:
		if animation.is_valid():
			if reduced:
				animation.kill()
				for label in entries.get_children(): label.modulate.a = 1
			elif paused: animation.pause()
			elif not animation.is_running(): animation.play()
	var key := JSON.stringify(items)
	if key == signature and applied_font_size == entry_font_size and applied_separators == separators and applied_bold_latest == bold_latest: return
	for animation in animations:
		if animation.is_valid(): animation.kill()
	animations.clear()
	var animate := initialized and not reduced and not paused and not items.is_empty()
	initialized = true; signature = key; applied_font_size = entry_font_size
	applied_separators = separators; applied_bold_latest = bold_latest
	for child in entries.get_children(): entries.remove_child(child); child.queue_free()
	if items.is_empty():
		var empty := Label.new(); empty.text = "No activity yet"; empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; empty.add_theme_font_size_override("font_size", maxi(10, entry_font_size - 1)); empty.add_theme_color_override("font_color",GameLook.SCROLL_INK if paper else GameLook.CREAM); entries.add_child(empty)
		if body_font != null: empty.add_theme_font_override("font",body_font)
	for index in items.size():
		if separators and index > 0:
			var rule := HSeparator.new(); var line := StyleBoxLine.new(); line.color = Color(GameLook.SCROLL_INK if paper else GameLook.CREAM,.16); line.thickness = 1; rule.add_theme_stylebox_override("separator",line); rule.mouse_filter = Control.MOUSE_FILTER_IGNORE; entries.add_child(rule)
		var label: Control
		if not items[index].get("parts",[]).is_empty():
			var rich := RichTextLabel.new(); rich.fit_content = true; rich.scroll_active = false; rich.bbcode_enabled = false
			if body_font != null: rich.add_theme_font_override("normal_font",body_font)
			rich.add_theme_font_size_override("normal_font_size",entry_font_size); rich.add_theme_color_override("default_color",GameLook.SCROLL_INK if paper else GameLook.CREAM)
			for part: Dictionary in items[index].parts:
				if part.get("texture") is Texture2D: rich.add_image(part.texture,int(part.get("width",20)),int(part.get("height",26)),Color.WHITE,INLINE_ALIGNMENT_CENTER)
				else:
					if part.has("color"): rich.push_color(part.color if part.color is Color else Color(str(part.color)))
					rich.add_text(str(part.get("text","")))
					if part.has("color"): rich.pop()
			label = rich
		else:
			var plain := Label.new(); plain.text = str(items[index].text); plain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; plain.add_theme_font_size_override("font_size", entry_font_size); plain.add_theme_color_override("font_color",GameLook.SCROLL_INK if paper else GameLook.CREAM); label = plain
			if body_font != null: plain.add_theme_font_override("font",body_font)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE; label.accessibility_name = str(items[index].text); entries.add_child(label)
		if bold_latest and index == 0:
			var emphasis := FontVariation.new(); emphasis.base_font = label.get_theme_font("normal_font" if label is RichTextLabel else "font"); emphasis.variation_embolden = .8
			label.add_theme_font_override("normal_font" if label is RichTextLabel else "font", emphasis)
		if index == 0 and animate:
			label.modulate.a = 0; var animation := create_tween(); animation.tween_property(label, "modulate:a", 1.0, 0.35); animations.append(animation)
			animation.finished.connect(func() -> void: animations.erase(animation), CONNECT_ONE_SHOT)
	scroll.scroll_vertical = 0
