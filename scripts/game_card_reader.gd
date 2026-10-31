class_name GameCardReader
extends Control

# Reusable full-screen reading surface. Modules supply validated action callbacks.
signal closed
var card := GameCard.new()
var stage := ScrollContainer.new()
var center := CenterContainer.new()
var heading := Label.new()
var subtitle := Label.new()
var top_back := Button.new()
var flip := Button.new()
var actions := HFlowContainer.new()
var action_scroll := ScrollContainer.new()
var pages: Array[Texture2D] = []
var page := 0
var fit_reference := false
var rotate_row := HBoxContainer.new()
var rotate_button := Button.new()
var rotate_label := Label.new()
var rotation_callback := Callable()
var rotation_tween: Tween
var shown_id := -1
var rotation_side := 0
var composition := HBoxContainer.new()
var preview := GameActionPreview.new()
var outside_origin := Vector2.INF
var reference_menu := HBoxContainer.new()
var reference_group := OptionButton.new()
var reference_topic := OptionButton.new()
var reference_library: Array = []
var reference_header: HBoxContainer
var reference_column: VBoxContainer
var reference_selected: Dictionary = {}
var reference_wide := false
var reference_back_only := false
var gallery_groups: Array = []
var gallery_title := "Help"
var gallery_browse := false
var gallery_showing := false
var gallery_group := 0
var gallery_tabs := HFlowContainer.new()
var gallery_grid := GameCardGrid.new()
var gallery_inline := false
var reference_gallery := GameReferenceGallery.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); z_index = 20
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new(); backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE; backdrop.color = Color("001728e6"); add_child(backdrop); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new(); add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 10); margin.add_child(column)
	var header := HBoxContainer.new(); column.add_child(header)
	reference_column = column; reference_header = header
	reference_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_back.theme = theme; top_back.text = "Back"; top_back.add_theme_font_size_override("font_size", 14); GameLook.action(top_back, false); header.add_child(top_back); top_back.pressed.connect(_back)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; heading.add_theme_font_size_override("font_size", 18); heading.add_theme_color_override("font_color", Color("fff4d9")); header.add_child(heading)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 16); column.add_child(subtitle); subtitle.hide()
	column.add_child(reference_menu); reference_menu.add_theme_constant_override("separation", 8); reference_menu.hide()
	for choice: OptionButton in [reference_group, reference_topic]:
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL; choice.custom_minimum_size.y = 44
		choice.fit_to_longest_item = false; choice.clip_text = true; reference_menu.add_child(choice)
		GameLook.compact_control(choice, true)
		choice.custom_minimum_size.y = 44
	reference_group.accessibility_name = "Reference collection"; reference_topic.accessibility_name = "Reference topic"
	reference_group.item_selected.connect(func(_index: int) -> void: _reference_topics())
	reference_topic.item_selected.connect(func(_index: int) -> void: _reference_page())
	column.add_child(gallery_tabs); gallery_tabs.alignment = FlowContainer.ALIGNMENT_CENTER; gallery_tabs.hide()
	gallery_tabs.add_theme_constant_override("h_separation", 8); gallery_tabs.add_theme_constant_override("v_separation", 8)
	flip.theme = theme; flip.icon = RuntimeAssets.texture("res://ui/playful/control-rotate.svg"); flip.custom_minimum_size = Vector2(44, 44); flip.accessibility_name = "Flip to back"; GameLook.action(flip, false); add_child(flip); flip.pressed.connect(_flip)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL; stage.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; column.add_child(stage)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; center.size_flags_vertical = Control.SIZE_EXPAND_FILL; stage.add_child(center); center.add_child(composition)
	stage.add_child(gallery_grid); gallery_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL; gallery_grid.preferred_width = 240; gallery_grid.caption_lines = 2; gallery_grid.center_vertically = true; gallery_grid.hide()
	gallery_grid.card_pressed.connect(_open_gallery_page)
	stage.add_child(reference_gallery); reference_gallery.hide()
	composition.add_theme_constant_override("separation", 24); composition.add_child(card); card.size_flags_vertical = Control.SIZE_SHRINK_CENTER; composition.add_child(preview); preview.hide()
	card.item_rect_changed.connect(_place_flip)
	composition.item_rect_changed.connect(_place_flip)
	center.item_rect_changed.connect(_place_flip)
	rotate_row.alignment = BoxContainer.ALIGNMENT_CENTER; rotate_row.add_theme_constant_override("separation", 12); column.add_child(rotate_row)
	rotate_button.theme = theme; rotate_button.icon = RuntimeAssets.texture("res://ui/playful/control-rotate.svg"); rotate_button.custom_minimum_size = Vector2(48, 44); rotate_button.accessibility_name = "Rotate card"; GameLook.action(rotate_button, false); rotate_row.add_child(rotate_button)
	rotate_label.add_theme_color_override("font_color", Color("fff4d9")); rotate_label.add_theme_font_size_override("font_size", 14); rotate_row.add_child(rotate_label); rotate_row.hide()
	rotate_button.pressed.connect(func() -> void:
		if rotation_callback.is_valid(): rotation_callback.call())
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; column.add_child(action_scroll)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL; actions.alignment = FlowContainer.ALIGNMENT_CENTER; actions.add_theme_constant_override("h_separation", 10); actions.add_theme_constant_override("v_separation", 8); action_scroll.add_child(actions)
	resized.connect(_fit); stage.resized.connect(func() -> void: _fit.call_deferred()); actions.minimum_size_changed.connect(func() -> void: _fit.call_deferred()); hide()


func show_card(data: Dictionary, texture: Texture2D, tint: Color, commands: Array = []) -> void:
	_clear_gallery(); reference_back_only = false
	reference_menu.hide(); reference_library.clear()
	reference_selected = {}; heading.show()
	if shown_id != int(data.get("id", -1)):
		_cancel_rotation(); card.rotation = 0; rotation_side = 0
	shown_id = int(data.get("id", -1)); rotate_row.hide()
	preview.hide()
	pages.clear(); heading.text = str(data.get("display_name", data.get("name", ""))); top_back.hide(); flip.hide(); action_scroll.show()
	subtitle.text = ""; subtitle.hide()
	card.card = data.duplicate(true); card.texture = texture; card.accent = tint; card.queue_redraw()
	card.accessibility_name = heading.text; card.accessibility_description = str(data.get("detail", ""))
	set_actions(commands); _show_reader(); _fit.call_deferred()


func set_subtitle(text: String, color := Color.WHITE) -> void:
	subtitle.text = text; subtitle.visible = not text.is_empty(); subtitle.add_theme_color_override("font_color", color)
	_fit.call_deferred()


func set_rotation_options(enabled: bool, side := 0, caption := "", callback := Callable(), reduced := false, animate := false) -> void:
	rotate_row.visible = enabled; rotation_callback = callback; rotate_label.text = caption
	if side != rotation_side:
		_cancel_rotation(); card.pivot_offset = card.size / 2
		rotation_side = side
		var target := card.rotation + PI
		if reduced or not animate: card.rotation = side * PI
		else:
			rotation_tween = create_tween()
			rotation_tween.tween_property(card, "rotation", target, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_fit.call_deferred()


func _cancel_rotation() -> void:
	if rotation_tween != null and rotation_tween.is_valid(): rotation_tween.kill()


func set_actions(commands: Array, back := Callable()) -> void:
	for child in actions.get_children(): actions.remove_child(child); child.queue_free()
	var list := [{"label": "Back", "callback": back if back.is_valid() else close}] + commands
	for command in list:
		var button := Button.new(); button.theme = theme; button.add_theme_font_size_override("font_size", 14); button.text = command.label; button.custom_minimum_size = Vector2(90, 44); button.pressed.connect(command.callback)
		if get_theme_constant("modern_table", "GamePalette") == 1: GameLook.table_action(button, str(command.get("kind", "bank" if command.label == "Back" else "play")))
		else: GameLook.action(button, command.label != "Back")
		button.disabled = command.get("disabled", false); actions.add_child(button)
	_fit.call_deferred()


func show_reference(front: Texture2D, back: Texture2D, fit_to_view := false, back_only := false) -> void:
	_clear_gallery(); reference_selected = {}
	_present_reference(front, back, fit_to_view, back_only)


func _show_reader() -> void:
	# Godot hit testing follows sibling order, including overlays opened earlier.
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	outside_origin = Vector2.INF; show()


func _present_reference(front: Texture2D, back: Texture2D, fit_to_view := false, back_only := false) -> void:
	reference_back_only = back_only; gallery_showing = false
	gallery_grid.hide(); reference_gallery.hide(); gallery_tabs.hide(); center.show()
	reference_menu.hide()
	fit_reference = fit_to_view
	_cancel_rotation(); shown_id = -1; card.rotation = 0; rotate_row.hide()
	preview.hide()
	subtitle.text = ""; subtitle.hide()
	pages.assign([front, back]); page = 0; heading.text = ""; top_back.show(); flip.show(); action_scroll.hide()
	card.card = {"layout": "deal", "kind": "reference"}; card.texture = front; card.queue_redraw(); flip.accessibility_name = "Flip to back"
	card.accessibility_name = "Quick Start Rules"; card.accessibility_description = ""
	_show_reader(); _fit.call_deferred()


# A fitted card gallery. Modules filter groups/pages to the current rules first.
# Optional collection buttons let setup screens browse the complete library.
func show_reference_gallery(groups: Array, title := "Help", browse := false, selected_group := 0, inline_flip := false) -> void:
	if groups.is_empty(): return
	reference_library.clear(); reference_selected = {}
	gallery_groups = groups.duplicate(); gallery_title = title; gallery_browse = browse
	gallery_inline = inline_flip
	gallery_group = clampi(selected_group, 0, groups.size() - 1)
	for child in gallery_tabs.get_children(): gallery_tabs.remove_child(child); child.queue_free()
	for index in groups.size():
		var button := Button.new(); button.theme = theme; button.text = str(groups[index].label); button.toggle_mode = true
		button.custom_minimum_size.y = 44; button.add_theme_font_size_override("font_size", 14)
		GameLook.action(button, false); gallery_tabs.add_child(button)
		button.pressed.connect(func() -> void: gallery_group = index; _present_gallery())
	_present_gallery()


func _present_gallery() -> void:
	_cancel_rotation(); shown_id = -1; reference_back_only = true; gallery_showing = true
	reference_selected = {}; pages.clear(); reference_menu.hide(); center.hide(); flip.hide(); rotate_row.hide(); action_scroll.hide()
	set_subtitle(""); heading.show(); heading.text = gallery_title; top_back.show()
	gallery_tabs.visible = gallery_browse and gallery_groups.size() > 1
	for index in gallery_tabs.get_child_count(): gallery_tabs.get_child(index).set_pressed_no_signal(index == gallery_group)
	var entries: Array = []
	var groups: Array = [gallery_groups[gallery_group]] if gallery_browse else gallery_groups
	for group: Dictionary in groups:
		for topic: Dictionary in group.pages:
			var label := str(group.label)+( " overview" if group.get("id","") != "base" else "") if str(topic.get("id", "")) == "overview" else str(topic.label)
			if gallery_inline:
				entries.append({"id":str(group.get("id",group.label))+"/"+str(topic.get("id",topic.label)),"label":str(topic.get("gallery_label",label)),"topic":topic})
				continue
			var front: Variant = topic.front
			entries.append({"card":{"id":str(group.get("id",group.label))+"/"+str(topic.get("id",topic.label)),"name":label,"layout":"art","reference":topic},"caption":label,"texture":GameCard.artwork(str(front)) if front is String else front})
	gallery_grid.visible = not gallery_inline; reference_gallery.visible = gallery_inline
	if gallery_inline:
		reference_gallery.wide = size.x >= 650 and size.y <= 540
		reference_gallery.set_items(entries)
	else: gallery_grid.set_items(entries)
	stage.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if gallery_inline else ScrollContainer.SCROLL_MODE_DISABLED
	stage.set_deferred("scroll_vertical",0)
	_show_reader(); _fit.call_deferred()


func _open_gallery_page(data: Dictionary) -> void:
	reference_wide = size.x >= 650 and size.y <= 540
	var topic: Dictionary = data.reference
	var faces := _reference_faces(topic, reference_wide)
	_present_reference(faces[0], faces[1], true, true)
	reference_selected = topic
	card.accessibility_name = str(data.name); card.accessibility_description = str(topic.get("description", ""))


func _clear_gallery() -> void:
	gallery_groups.clear(); gallery_showing = false; gallery_grid.hide(); reference_gallery.hide(); gallery_tabs.hide(); center.show()
	stage.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO


func _back() -> void:
	if not gallery_groups.is_empty() and not gallery_showing: _present_gallery()
	else: close()


# Optional offline reference library. Each group supplies labelled two-sided pages.
func show_reference_library(groups: Array, selected_group := 0, selected_topic := 0) -> void:
	if groups.is_empty(): return
	_clear_gallery()
	reference_library = groups.duplicate()
	reference_group.clear()
	for group: Dictionary in groups: reference_group.add_item(str(group.label))
	reference_group.select(clampi(selected_group, 0, groups.size() - 1))
	_reference_topics(selected_topic)


func _reference_topics(selected := 0) -> void:
	if reference_library.is_empty(): return
	reference_topic.clear()
	for topic: Dictionary in reference_library[reference_group.selected].pages: reference_topic.add_item(str(topic.label))
	reference_topic.select(clampi(selected, 0, reference_topic.item_count - 1))
	_reference_page()


func _reference_page() -> void:
	if reference_library.is_empty() or reference_topic.selected < 0: return
	var topic: Dictionary = reference_library[reference_group.selected].pages[reference_topic.selected]
	reference_selected = topic; reference_wide = size.x >= 650 and size.y <= 540
	var faces := _reference_faces(topic,reference_wide)
	_present_reference(faces[0], faces[1], true)
	reference_menu.show(); reference_topic.visible = reference_topic.item_count > 1
	card.accessibility_name = str(topic.label); card.accessibility_description = str(topic.get("description", ""))
	_layout_reference_menu()


func _reference_faces(topic: Dictionary, wide: bool) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	for side in ["front","back"]:
		var face: Variant = topic.get(side+"_wide",topic[side]) if wide else topic[side]
		result.append(GameCard.artwork(str(face)) if face is String else face)
	return result


func _layout_reference_menu() -> void:
	if not reference_menu.visible:
		heading.show(); _refresh_reference_orientation(); return
	var wide := size.x >= 650 and size.y <= 540
	var parent: Node = reference_header if wide else reference_column
	if reference_menu.get_parent() != parent:
		reference_menu.reparent(parent)
		if not wide: reference_column.move_child(reference_menu,2)
	heading.visible = not wide
	_refresh_reference_orientation()


func _refresh_reference_orientation() -> void:
	var wide := size.x >= 650 and size.y <= 540
	if wide != reference_wide and not reference_selected.is_empty():
		reference_wide = wide; pages.assign(_reference_faces(reference_selected,wide)); card.texture = pages[page]; card.queue_redraw()


func _flip() -> void:
	if pages.size() != 2: return
	page = 1 - page; card.texture = pages[page]; card.queue_redraw(); flip.accessibility_name = "Flip to back" if page == 0 else "Flip to front"; stage.scroll_vertical = 0
	card.accessibility_name = "Quick Start Rules" if page == 0 else "Essential Rules"
	_fit.call_deferred()


func _fit() -> void:
	if not is_inside_tree(): return
	_layout_reference_menu()
	if gallery_showing:
		if gallery_inline:
			reference_gallery.wide = size.x >= 650 and size.y <= 540
			reference_gallery.card_height_limit = maxf(1,stage.size.y-52); reference_gallery.queue_sort()
		else: gallery_grid.maximum_height = maxf(1,stage.size.y-8); gallery_grid.queue_sort()
		return
	action_scroll.custom_minimum_size.y = minf(180, actions.get_combined_minimum_size().y)
	var width := minf(maxf(0, size.x - 40), maxf(260, minf(500, stage.size.y * 2 / 3)))
	if not pages.is_empty(): width = minf(500, maxf(160, size.x - 72))
	if preview.visible:
		width = minf(300, minf(stage.size.y * 0.65, maxf(84, (size.x - 64) * 0.34)))
		preview.custom_minimum_size.x = minf(420, maxf(160, size.x - width - 80))
	var aspect := 2.0 / 3.0
	if not pages.is_empty() and pages[page] != null:
		var dimensions: Vector2 = pages[page].get_size()
		if dimensions.y > 0: aspect = dimensions.x / dimensions.y
		if aspect > 1: width = minf(880, maxf(160, size.x - 72))
		if fit_reference: width = maxf(1,minf(width,maxf(1,stage.size.y-40)*aspect))
	card.custom_minimum_size = Vector2(width, width / aspect)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if preview.visible else Control.SIZE_SHRINK_CENTER
	card.pivot_offset = card.size / 2
	_place_flip.call_deferred()


func _place_flip() -> void:
	if not is_inside_tree() or not flip.visible: return
	flip.size = Vector2(44, 44); flip.position = card.get_global_rect().position - get_global_rect().position + Vector2(maxf(0, card.size.x - 28), -16)


func _contains_focus(point: Vector2) -> bool:
	for control in [card, preview, top_back, flip, rotate_button, rotate_label, reference_menu] + actions.get_children():
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point): return true
	return false


func _input(event: InputEvent) -> void:
	if not visible: return
	if reference_back_only:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: outside_origin = event.position if not _contains_focus(event.position) else Vector2.INF
		else:
			if outside_origin.is_finite() and outside_origin.distance_to(event.position) < 8 and not _contains_focus(event.position): close(); get_viewport().set_input_as_handled()
			outside_origin = Vector2.INF
	elif event is InputEventScreenTouch:
		if event.pressed: outside_origin = event.position if not _contains_focus(event.position) else Vector2.INF
		else:
			if outside_origin.is_finite() and outside_origin.distance_to(event.position) < 8 and not _contains_focus(event.position): close(); get_viewport().set_input_as_handled()
			outside_origin = Vector2.INF


func set_preview(items: Array, index := 0, presentation := "default") -> void:
	preview.visible = not items.is_empty()
	if preview.visible: preview.set_options(items, index, presentation)
	_fit.call_deferred()


func close() -> void:
	_cancel_rotation(); shown_id = -1; outside_origin = Vector2.INF; hide(); closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and not reference_back_only and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: close(); get_viewport().set_input_as_handled()
