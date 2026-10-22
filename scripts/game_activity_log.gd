class_name GameActivityLog
extends PanelContainer

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
var applied_font_size := -1

func _ready() -> void:
	clip_contents = true; accessibility_name = "Activity history"
	var style := GameLook.modern_table_sheet(); style.content_margin_left = 7; style.content_margin_right = 7; style.content_margin_top = 6; style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 4); add_child(column)
	heading.text = "Activity"; heading.add_theme_font_size_override("font_size", 12); heading.clip_text = true; column.add_child(heading)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_child(scroll)
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL; entries.add_theme_constant_override("separation", 6); scroll.add_child(entries)
	heading.visible = show_heading
	resized.connect(func() -> void: heading.visible = show_heading and size.x >= 72)

func set_entries(items: Array, reduced := false, paused := false) -> void:
	for animation in animations:
		if animation.is_valid():
			if reduced:
				animation.kill()
				for label in entries.get_children(): label.modulate.a = 1
			elif paused: animation.pause()
			elif not animation.is_running(): animation.play()
	var key := JSON.stringify(items)
	if key == signature and applied_font_size == entry_font_size: return
	for animation in animations:
		if animation.is_valid(): animation.kill()
	animations.clear()
	var animate := initialized and not reduced and not paused and not items.is_empty()
	initialized = true; signature = key; applied_font_size = entry_font_size
	for child in entries.get_children(): entries.remove_child(child); child.queue_free()
	if items.is_empty():
		var empty := Label.new(); empty.text = "No activity yet"; empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; empty.add_theme_font_size_override("font_size", maxi(10, entry_font_size - 1)); entries.add_child(empty)
	for index in items.size():
		var label := Label.new(); label.text = str(items[index].text); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.add_theme_font_size_override("font_size", entry_font_size); entries.add_child(label)
		if bold_latest and index == 0:
			var emphasis := FontVariation.new(); emphasis.base_font = label.get_theme_font("font"); emphasis.variation_embolden = .8
			label.add_theme_font_override("font", emphasis)
		if index == 0 and animate:
			label.modulate.a = 0; var animation := create_tween(); animation.tween_property(label, "modulate:a", 1.0, 0.35); animations.append(animation)
			animation.finished.connect(func() -> void: animations.erase(animation), CONNECT_ONE_SHOT)
	scroll.scroll_vertical = 0
