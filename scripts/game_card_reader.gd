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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); z_index = 20
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new(); backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE; backdrop.color = Color("001728e6"); add_child(backdrop); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new(); add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 10); margin.add_child(column)
	var header := HBoxContainer.new(); column.add_child(header)
	top_back.theme = theme; top_back.text = "Back"; top_back.add_theme_font_size_override("font_size", 14); GameLook.action(top_back, false); header.add_child(top_back); top_back.pressed.connect(close)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; heading.add_theme_font_size_override("font_size", 18); heading.add_theme_color_override("font_color", Color("fff4d9")); header.add_child(heading)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 16); column.add_child(subtitle); subtitle.hide()
	flip.theme = theme; flip.icon = RuntimeAssets.texture("res://ui/playful/control-rotate.svg"); flip.custom_minimum_size = Vector2(44, 44); flip.accessibility_name = "Flip to back"; GameLook.action(flip, false); add_child(flip); flip.pressed.connect(_flip)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL; stage.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; column.add_child(stage)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; center.size_flags_vertical = Control.SIZE_EXPAND_FILL; stage.add_child(center); center.add_child(composition)
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
	if shown_id != int(data.get("id", -1)):
		_cancel_rotation(); card.rotation = 0; rotation_side = 0
	shown_id = int(data.get("id", -1)); rotate_row.hide()
	preview.hide()
	pages.clear(); heading.text = str(data.get("display_name", data.get("name", ""))); top_back.hide(); flip.hide(); action_scroll.show()
	subtitle.text = ""; subtitle.hide()
	card.card = data.duplicate(true); card.texture = texture; card.accent = tint; card.queue_redraw()
	card.accessibility_name = heading.text; card.accessibility_description = str(data.get("detail", ""))
	set_actions(commands); show(); _fit.call_deferred()


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


func show_reference(front: Texture2D, back: Texture2D, fit_to_view := false) -> void:
	fit_reference = fit_to_view
	_cancel_rotation(); shown_id = -1; card.rotation = 0; rotate_row.hide()
	preview.hide()
	subtitle.text = ""; subtitle.hide()
	pages.assign([front, back]); page = 0; heading.text = ""; top_back.show(); flip.show(); action_scroll.hide()
	card.card = {"layout": "deal", "kind": "reference"}; card.texture = front; card.queue_redraw(); flip.accessibility_name = "Flip to back"
	card.accessibility_name = "Quick Start Rules"; card.accessibility_description = ""
	show(); _fit.call_deferred()


func _flip() -> void:
	if pages.size() != 2: return
	page = 1 - page; card.texture = pages[page]; card.queue_redraw(); flip.accessibility_name = "Flip to back" if page == 0 else "Flip to front"; stage.scroll_vertical = 0
	card.accessibility_name = "Quick Start Rules" if page == 0 else "Essential Rules"
	_fit.call_deferred()


func _fit() -> void:
	if not is_inside_tree(): return
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
	for control in [card, preview, top_back, flip, rotate_button, rotate_label] + actions.get_children():
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point): return true
	return false


func _input(event: InputEvent) -> void:
	if not visible: return
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
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: close(); get_viewport().set_input_as_handled()
