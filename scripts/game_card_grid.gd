class_name GameCardGrid
extends Container

# Shared selectable card tiles and fixed spaces for missing properties.
signal card_pressed(card: Dictionary)
signal selection_changed(ids: Array)
signal choice_selected(card_id: String, index: int)
var fixed_columns := 0
var preferred_width := 108.0
var maximum_columns := 6
var maximum_height := 0.0
var selectable := false
var left_aligned := false
var center_vertically := false
var caption_lines := 1
var selected: Array = []
var locked := false
var entries: Array = []
var grid_height := 0.0

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("h_separation", 8); add_theme_constant_override("v_separation", 8)
	resized.connect(_fit)

func _get_minimum_size() -> Vector2:
	# Width belongs to the enclosing panel, so a previous wide grid cannot keep
	# a resized dialog wider than the viewport. Only the current rows set height.
	return Vector2(0, grid_height)

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN: _fit()

func set_items(items: Array) -> void:
	entries = items
	var caption_height := 22 if caption_lines <= 1 else 36
	for child in get_children(): remove_child(child); child.queue_free()
	for entry in items:
		var button := Button.new(); button.toggle_mode = selectable; button.disabled = locked or entry.get("disabled", false)
		button.set_meta("grid_entry", entry); button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if entry.get("placeholder", false):
			button.disabled = true; button.accessibility_name = "Missing property"
		else:
			var data: Dictionary = entry.card
			button.accessibility_name = str(data.get("display_name", data.get("name", "Card"))) + ("" if data.get("layout", "") in ["art","symbol"] else ", $%d " % data.get("value", 0)) + str(entry.get("caption", ""))
			if data.get("layout", "") == "symbol": button.accessibility_name += ". "+str(data.get("detail",""))+" "+str(data.get("foot",""))
			if data.get("layout", "") == "symbol" and data.get("back",false): button.accessibility_name = "Card back"
			if data.get("mortgaged", false): button.accessibility_name += ", mortgaged"
			elif not str(data.get("deed_state", {}).get("badge", "")).is_empty(): button.accessibility_name += ", " + str(data.deed_state.badge)
			var face := GameCard.new(); face.card = data; face.texture = entry.texture; face.accent = entry.get("tint", Color("17594d"))
			button.add_child(face); face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); face.offset_left = 5; face.offset_top = 5; face.offset_right = -5; face.offset_bottom = -5 - (caption_height if entry.has("caption") else 0)
			if entry.has("caption"):
				var label := Label.new(); label.text = str(entry.caption); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size", 12); label.clip_text = true; label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				if caption_lines > 1: label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.max_lines_visible = 2; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				button.add_child(label); label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); label.offset_top = -caption_height-2; label.offset_bottom = -3; label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if entry.has("inline_choice"):
				var options: Dictionary = entry.inline_choice
				var choice := OptionButton.new()
				choice.name = "InlineChoice"; choice.custom_minimum_size.y = 44
				choice.fit_to_longest_item = false; choice.clip_text = true
				choice.accessibility_name = str(options.get("label", "Card option"))
				for option: String in options.get("options", []): choice.add_item(option)
				choice.select(int(options.get("selected", 0)))
				choice.disabled = button.disabled; button.add_child(choice)
				GameLook.compact_control(choice, true)
				choice.item_selected.connect(func(index: int) -> void: choice_selected.emit(str(data.id), index))
			button.pressed.connect(func() -> void:
				if selectable:
					if selected.has(data.id): selected.erase(data.id)
					else: selected.append(data.id)
					set_selected(selected); selection_changed.emit(selected.duplicate())
				else: card_pressed.emit(data))
		add_child(button)
	set_selected(selected); _fit.call_deferred()

func set_selected(ids: Array) -> void:
	selected = ids.duplicate()
	for button: Button in get_children():
		var entry: Dictionary = button.get_meta("grid_entry")
		var on: bool = not entry.get("placeholder", false) and selected.has(entry.card.id)
		button.set_pressed_no_signal(on)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var surface := GameLook.box(Color("155b66") if on else Color("021b2c"), Color("ffe36c") if on else Color("27566b"), 7, 3 if on else 1)
			if get_theme_constant("casino", "GamePalette") == 1: surface = GameLook.casino_sheet(on)
			surface.set_content_margin_all(0); button.add_theme_stylebox_override(state, surface)

func _fit() -> void:
	var gap := float(get_theme_constant("h_separation"))
	var available := size.x
	var columns := fixed_columns if fixed_columns > 0 else clampi(int((available + gap) / (preferred_width + gap)), 1, mini(maximum_columns, maxi(1, entries.size())))
	var width := maxf(24, minf(preferred_width, (available - (columns - 1) * gap) / columns))
	var caption_height := (22.0 if caption_lines <= 1 else 36.0) if entries.any(func(entry: Dictionary) -> bool: return entry.has("caption")) else 0.0
	if maximum_height > 0 and not entries.is_empty():
		# Pick the largest face that fits both the panel's width and height.
		var best := 0.0
		for candidate in range(1, mini(maximum_columns, entries.size()) + 1):
			var rows := ceili(float(entries.size()) / candidate)
			var fitted := minf(preferred_width, minf((available - (candidate - 1) * gap) / candidate, ((maximum_height - maxi(0, rows - 1) * gap) / rows - caption_height) / 1.5))
			if fitted > best or is_equal_approx(fitted,best) and candidate > columns: best = fitted; columns = candidate
		width = maxf(4, best)
	var row_height := width * 1.5 + caption_height
	var left := 0.0 if left_aligned else maxf(0, (available - columns * width - (columns - 1) * gap) / 2)
	var rows := ceili(float(entries.size()) / columns)
	var height := rows * row_height + maxi(0, rows - 1) * gap
	var top := maxf(0,(size.y-height)/2) if center_vertically else 0.0
	for index in get_child_count():
		var button: Button = get_child(index)
		button.position = Vector2(left + (index % columns) * (width + gap), top + (index / columns) * (row_height + gap))
		button.size = Vector2(width, row_height)
		var inset := minf(5, width * .14)
		for child in button.get_children():
			if child is GameCard:
				child.offset_left = inset; child.offset_top = inset; child.offset_right = -inset
				child.offset_bottom = -inset - (caption_height if entries[index].has("caption") else 0)
			elif child is OptionButton and child.name == "InlineChoice":
				child.position = Vector2(inset + 5, row_height * .57)
				child.size = Vector2(maxf(44, width - inset * 2 - 10), 44)
	if not is_equal_approx(height, grid_height): grid_height = height; update_minimum_size()
