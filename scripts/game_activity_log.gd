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

func _ready() -> void:
	clip_contents = true; accessibility_name = "Activity history"
	focus_mode = Control.FOCUS_ALL if expandable else Control.FOCUS_NONE
	gui_input.connect(func(event: InputEvent) -> void:
		if expandable and (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed or event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER,KEY_SPACE]):
			expand_requested.emit(); accept_event()
	)
	var style := GameLook.card_table_sheet() if paper else GameLook.modern_table_sheet(); style.content_margin_left = 12 if paper else 7; style.content_margin_right = 12 if paper else 7; style.content_margin_top = 10 if paper else 6; style.content_margin_bottom = 10 if paper else 6
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 4); add_child(column)
	heading.text = "History" if paper else "Activity"; heading.add_theme_font_size_override("font_size", 17 if paper else 12); heading.add_theme_color_override("font_color",GameLook.SCROLL_INK if paper else GameLook.CREAM); heading.clip_text = true; column.add_child(heading)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_child(scroll)
	if expandable:
		scroll.mouse_filter = Control.MOUSE_FILTER_PASS; scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		entries.mouse_filter = Control.MOUSE_FILTER_PASS
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL; entries.add_theme_constant_override("separation", 6); scroll.add_child(entries)
	heading.visible = show_heading
	resized.connect(func() -> void: heading.visible = show_heading and size.x >= 72)

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
	for index in items.size():
		if separators and index > 0:
			var rule := HSeparator.new(); var line := StyleBoxLine.new(); line.color = Color(GameLook.SCROLL_INK if paper else GameLook.CREAM,.16); line.thickness = 1; rule.add_theme_stylebox_override("separator",line); rule.mouse_filter = Control.MOUSE_FILTER_IGNORE; entries.add_child(rule)
		var label: Control
		if not items[index].get("parts",[]).is_empty():
			var rich := RichTextLabel.new(); rich.fit_content = true; rich.scroll_active = false; rich.bbcode_enabled = false
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
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE; label.accessibility_name = str(items[index].text); entries.add_child(label)
		if bold_latest and index == 0:
			var emphasis := FontVariation.new(); emphasis.base_font = label.get_theme_font("normal_font" if label is RichTextLabel else "font"); emphasis.variation_embolden = .8
			label.add_theme_font_override("normal_font" if label is RichTextLabel else "font", emphasis)
		if index == 0 and animate:
			label.modulate.a = 0; var animation := create_tween(); animation.tween_property(label, "modulate:a", 1.0, 0.35); animations.append(animation)
			animation.finished.connect(func() -> void: animations.erase(animation), CONNECT_ONE_SHOT)
	scroll.scroll_vertical = 0
