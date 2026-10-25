class_name GameScreen
extends MarginContainer

# Common game chrome inherits the launcher's theme. Rules stay in the module.
signal exit_requested
signal board_space_changed
var content: VBoxContainer
var status: RichTextLabel
var scores: RichTextLabel
var title_label: Label
var instruction_label: Label
var back_button: Button
var background_media: Control
var content_scroll: ScrollContainer
var board_anchor: Control
var _centered: VBoxContainer
var _board_layout: Control
var _board_spacer: Control
var _replay_slot: MarginContainer
var _board_limit := -1.0
var _board_width_limit := -1.0
var _board_center_ratio := 0.5
var _board_center_heading := false
var _board_auxiliary: Control
var _board_reserve_auxiliary := false
var _board_wide_auxiliary := false
var _board_bottom_auxiliary := false
var _board_replay: Button
var _board_embedded_replay := false
var _board_details: VBoxContainer
var _details_actions: GridContainer
var _details_panels: GridContainer
var _details_toggles: Array[Button] = []
var _details_columns: Array[Control] = []
var _floating_details_layouts: Array[Callable] = []
var _compact_heading := false
var _status_plaque_width := 0.0
var _status_plaque_height := 56.0
var _table_header := false
var table_title_art: TextureRect
var _table_header_layer: Control
var _table_header_content: Control
var _table_header_fit: Callable
var _table_header_height := 60.0
var _table_header_action: Button
var _table_header_summary: Control


func available_size() -> Vector2:
	# Container minimums may temporarily exceed the window during layout. Use
	# the host root's bounds to decide wrapping, rather than that expanded size.
	return get_parent_control().size if get_parent_control() != null else get_viewport_rect().size


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 64 if side in ["top", "bottom"] else 24)
	content_scroll = ScrollContainer.new()
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# A permanent, balanced gutter prevents expanded sheets from shifting the board.
	content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	add_theme_constant_override("margin_right", maxi(0, 24 - int(content_scroll.get_v_scroll_bar().get_combined_minimum_size().x)))
	add_child(content_scroll)
	_centered = VBoxContainer.new()
	_centered.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_centered.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_centered.alignment = BoxContainer.ALIGNMENT_CENTER
	content_scroll.add_child(_centered)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_centered.add_child(content)
	back_button = Button.new()
	back_button.text = "BACK TO GAMES"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.pressed.connect(func() -> void: exit_requested.emit())
	content.add_child(back_button)


# Center the board, optionally including its heading for complete card tables.
# Reserving replay space prevents the board from moving when a game ends.
func center_board(board: Control, replay: Button, auxiliary: Control = null, center_ratio := 0.5, reserve_auxiliary := false, center_heading := false, wide_auxiliary := false, embedded_replay := false, bottom_auxiliary := false) -> void:
	_board_center_ratio = clampf(center_ratio, 0.3, 0.56)
	_board_center_heading = center_heading
	board_anchor = board
	_board_layout = board
	while _board_layout.get_parent() != content:
		_board_layout = _board_layout.get_parent_control()
	_replay_slot = MarginContainer.new()
	_board_embedded_replay = embedded_replay
	_replay_slot.custom_minimum_size.y = 0 if embedded_replay and board.is_ancestor_of(replay) else replay.get_combined_minimum_size().y
	if embedded_replay:
		# A table may keep its single replay button in the same persistent action
		# row as Settings/Results. Reserve that complete toolbar without covering
		# its controls with a second replay layer.
		content.add_child(_replay_slot)
		content.move_child(_replay_slot, _board_layout.get_index() + 1)
	else:
		var playfield := replay.get_parent()
		var replay_index := replay.get_index()
		playfield.add_child(_replay_slot)
		playfield.move_child(_replay_slot, replay_index)
		replay.reparent(_replay_slot)
	_board_replay = replay
	_board_auxiliary = auxiliary
	_board_reserve_auxiliary = reserve_auxiliary
	_board_wide_auxiliary = wide_auxiliary
	_board_bottom_auxiliary = bottom_auxiliary and wide_auxiliary and auxiliary != null
	if auxiliary != null:
		auxiliary.reparent(get_parent() if wide_auxiliary else _replay_slot)
	_centered.alignment = BoxContainer.ALIGNMENT_BEGIN
	_centered.add_theme_constant_override("separation", 0)
	_board_spacer = Control.new()
	_board_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_centered.add_child(_board_spacer)
	_centered.move_child(_board_spacer, 0)


func _board_top_margin() -> float:
	if _table_header:
		if _table_header_summary != null and available_size().x < 550: return _table_header_height + _table_header_summary.get_combined_minimum_size().y + 16
		return _table_header_height + 8.0
	return 64.0 if available_size().x < 700 else 16.0


func _board_header_height() -> float:
	var header_height := 0.0
	for child in content.get_children():
		if child == _board_layout:
			break
		if child is Control and child.visible:
			header_height += child.get_combined_minimum_size().y + content.get_theme_constant("separation")
	return header_height


func _board_center_y() -> float:
	# Card tables can center their heading and complete playfield together while
	# retaining the same replay reservation and responsive fitting as other games.
	if _board_bottom_auxiliary:
		var top := _board_top_margin() + _board_header_height()
		var bottom := maxf(top, available_size().y - 24 - _replay_slot.custom_minimum_size.y)
		return lerpf(top, bottom, _board_center_ratio)
	return available_size().y * _board_center_ratio + (_board_header_height() / 2 if _board_center_heading else 0.0)


func board_height_limit() -> float:
	if _board_layout == null:
		return available_size().y - 128.0
	var center := _board_center_y()
	var above := center - _board_top_margin() - _board_header_height()
	var action_height := _replay_slot.custom_minimum_size.y
	if _board_details != null:
		# Reserve replay height even while its row is hidden, without leaving a
		# horizontal hole between the options and history panels.
		action_height += _details_actions.get_combined_minimum_size().y + 8
	var below := available_size().y - center - 16.0 - action_height - 8.0
	return maxf(0.0, minf(above, below) * 2.0)


# Symmetric sidebars publish their remaining width before a board can force wrap.
func board_width_limit() -> float:
	return _board_width_limit if _board_width_limit >= 0 else maxf(0, available_size().x - 48)


func _process(_delta: float) -> void:
	for layout in _floating_details_layouts: layout.call()
	if board_anchor == null:
		return
	if _compact_heading:
		var font := status.get_theme_font("normal_font")
		var width := _status_plaque_width if _status_plaque_width > 0 else font.get_string_size(status.get_parsed_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 32
		status.custom_minimum_size.x = minf(maxf(180, width), minf(520, available_size().x - 64))
	var replay_height := 0.0 if _board_embedded_replay and board_anchor.is_ancestor_of(_board_replay) else _board_replay.get_combined_minimum_size().y
	if _board_auxiliary != null and (_board_auxiliary.visible or _board_reserve_auxiliary):
		replay_height = maxf(replay_height, _board_auxiliary.get_combined_minimum_size().y)
	_replay_slot.custom_minimum_size.y = replay_height
	if _board_wide_auxiliary and _board_auxiliary != null:
		# A viewport-wide toolbar retains the same centered-board/replay reserve,
		# without widening the playfield or forcing its sidebars to wrap.
		_board_auxiliary.position = Vector2(24, available_size().y - 16 - replay_height if _board_bottom_auxiliary else _replay_slot.global_position.y - get_parent_control().global_position.y)
		_board_auxiliary.size = Vector2(maxf(0, available_size().x - 48), replay_height)
	if _board_details != null:
		_layout_board_details()
	if get_theme_constant("margin_top") != int(_board_top_margin()):
		add_theme_constant_override("margin_top", int(_board_top_margin()))
	if get_theme_constant("margin_bottom") != 16:
		add_theme_constant_override("margin_bottom", 16)
	# Reserve two status lines on narrow screens so shorter result text does not
	# resize the board while a winning piece is still animating.
	var status_height := 64.0 if available_size().x < 700 else 0.0
	if _table_header: status_height = 44.0
	if _compact_heading:
		status_height = _status_plaque_height
	if not is_equal_approx(status.custom_minimum_size.y, status_height):
		status.custom_minimum_size.y = status_height
	var limit := board_height_limit()
	if not is_equal_approx(limit, _board_limit):
		_board_limit = limit
		board_space_changed.emit()
	var board_offset := board_anchor.get_global_rect().get_center().y - content.global_position.y
	var leading := maxf(0.0, _board_center_y() - _board_top_margin() - board_offset)
	if not is_equal_approx(leading, _board_spacer.custom_minimum_size.y):
		_board_spacer.custom_minimum_size.y = leading


func configure(title: String, _instructions := "") -> void:
	title_label = add_text(title, 32)
	# Retain the legacy property without displaying an instruction subtitle.
	instruction_label = add_text("")
	instruction_label.hide()
	scores = add_formatted_text(content, true)
	status = add_formatted_text(content, true)
	back_button.reparent(get_parent())
	back_button.position = Vector2(24, 24)


# An opt-in table header keeps shared navigation/status outside centered fields.
func use_table_header(title_art: Texture2D = null, centered_title := false, left_title := false) -> void:
	_table_header = true
	_table_header_height = 88.0 if centered_title else 60.0
	var header := PanelContainer.new()
	# Header chrome must not intercept the sibling Back button underneath it.
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.theme = theme
	var header_style: StyleBox = GameLook.casino_frame() if get_theme_constant("casino", "GamePalette") == 1 else GameLook.modern_table_sheet()
	header_style.set_content_margin_all(4)
	header.add_theme_stylebox_override("panel", header_style)
	get_parent().add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 0; header.offset_bottom = _table_header_height
	var layer := Control.new(); layer.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.custom_minimum_size.y = _table_header_height - 8; header.add_child(layer)
	_table_header_layer = layer
	title_label.reparent(layer); title_label.text = title_label.text.to_upper(); title_label.autowrap_mode = TextServer.AUTOWRAP_OFF; title_label.clip_text = true
	title_label.add_theme_color_override("font_color", Color("ffd447"))
	if title_art != null:
		title_label.hide(); table_title_art = TextureRect.new(); table_title_art.texture = title_art; table_title_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; table_title_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; layer.add_child(table_title_art)
	status.reparent(layer); status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.custom_minimum_size.y = 44
	status.fit_content = false; status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("normal_font_size", 17)
	status.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	status.add_theme_color_override("default_color", Color("e5f4ff"))
	back_button.text = "‹"; back_button.accessibility_name = "Back to Games"; back_button.position = Vector2(12, 8); back_button.custom_minimum_size = Vector2(44, 44); back_button.size = Vector2(44, 44)
	# The opaque header is a later sibling. Keep navigation above its artwork.
	back_button.z_index = 2
	GameLook.action(back_button, false)
	var fit := func() -> void:
		var width := layer.size.x
		var compact := width < (1100 if _table_header_content != null else 800)
		# Equal left/right reserves center status against the complete viewport.
		var reserve := 120.0 if width < 700 else 220.0
		if _table_header_content != null: reserve = 60.0 if width < 700 else 100.0 if compact else 220.0
		var header_content := _table_header_content if _table_header_content != null else status
		var left_reserve := 64.0 if _table_header_content != null and compact else reserve
		var right_reserve := 112.0 if _table_header_content != null and compact else reserve
		header_content.position = Vector2(left_reserve, 0); header_content.size = Vector2(maxf(0, width - left_reserve - right_reserve), layer.size.y)
		title_label.position = Vector2(66, 0); title_label.size = Vector2(140, layer.size.y); title_label.visible = title_art == null and not compact
		if table_title_art != null:
			table_title_art.position = Vector2(66, 0); table_title_art.size = Vector2(140, layer.size.y)
			table_title_art.visible = not compact
		var title_size := 16 if compact else 24
		while title_size > 10 and title_label.get_theme_font("font").get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > 140: title_size -= 1
		title_label.add_theme_font_size_override("font_size", title_size)
		status.add_theme_font_size_override("normal_font_size", 13 if compact else 17)
		status.visible = _table_header_content == null
		if centered_title:
			var title_width := maxf(0, width - 232)
			title_label.position = Vector2(116, 0); title_label.size = Vector2(title_width, 36)
			title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; title_label.visible = title_art == null
			var centered_size := 24
			while centered_size > 11 and title_label.get_theme_font("font").get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, centered_size).x > title_width: centered_size -= 1
			title_label.add_theme_font_size_override("font_size", centered_size)
			var track_width := minf(720, maxf(0, width - 40))
			header_content.position = Vector2((width - track_width) / 2, 38); header_content.size = Vector2(track_width, 42)
		elif left_title:
			var stacked := width < 760
			_table_header_height = 104.0 if stacked else 60.0
			header.offset_bottom = _table_header_height; layer.custom_minimum_size.y = _table_header_height - 8
			var title_width := maxf(0, width - 184) if stacked else 230.0
			title_label.position = Vector2(66, 0); title_label.size = Vector2(title_width, 36 if stacked else 52)
			title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT; title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; title_label.visible = title_art == null
			var left_size := 20 if stacked else 22
			while left_size > 11 and title_label.get_theme_font("font").get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, left_size).x > title_width: left_size -= 1
			title_label.add_theme_font_size_override("font_size", left_size)
			header_content.position = Vector2(12 if stacked else 312, 56 if stacked else 4)
			header_content.size = Vector2(maxf(0, width - (24 if stacked else 444)), 40 if stacked else 42)
		if _table_header_action != null:
			_table_header_action.position = Vector2(maxf(60, width - 108), 4); _table_header_action.size = Vector2(44, 44)
		if _table_header_summary != null:
			_table_header_summary.position = Vector2(16, _table_header_height + 8)
			_table_header_summary.size = Vector2(width - 24 if width < 550 else minf(232, maxf(146, width * .23)), _table_header_summary.get_combined_minimum_size().y)
	_table_header_fit = fit
	layer.resized.connect(fit); resized.connect(fit); fit.call_deferred()


# Replace only the table's status area; navigation and title keep shared fitting.
func set_table_header_content(control: Control) -> void:
	if _table_header_layer == null: return
	_table_header_content = control
	if control.get_parent() == null: _table_header_layer.add_child(control)
	else: control.reparent(_table_header_layer)
	status.hide(); _table_header_fit.call_deferred()


func set_table_header_action(button: Button) -> void:
	if _table_header_layer == null: return
	_table_header_action = button
	if button.get_parent() == null: _table_header_layer.add_child(button)
	else: button.reparent(_table_header_layer)
	button.custom_minimum_size = Vector2(44, 44)
	_table_header_fit.call_deferred()


func set_table_header_summary(control: Control) -> void:
	if _table_header_layer == null: return
	_table_header_summary = control
	if control.get_parent() == null: get_parent().add_child(control)
	else: control.reparent(get_parent())
	control.minimum_size_changed.connect(_table_header_fit)
	_table_header_fit.call_deferred()


# Shared opt-in theme and background hook; artwork remains module-owned.
func use_playful_style(background: Variant = null, presentation := "") -> void:
	theme = GameLook.make_theme(presentation)
	back_button.theme = theme
	content.add_theme_constant_override("separation", 6)
	if background is String and not background.is_empty():
		background_media = preload("res://scripts/game_background.gd").new()
		background_media.source_stem = background
		background_media.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		get_parent().add_child(background_media)
		get_parent().move_child(background_media, get_index())
	elif background is Texture2D:
		var art := TextureRect.new()
		art.texture = background
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		get_parent().add_child(art)
		get_parent().move_child(art, get_index())
	else:
		var backdrop := ColorRect.new()
		backdrop.color = Color("70cdf2")
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		get_parent().add_child(backdrop)
		get_parent().move_child(backdrop, get_index())
	status.add_theme_stylebox_override("normal", GameLook.box(theme.get_color("status", "GamePalette"), theme.get_color("status_edge", "GamePalette"), 10 if presentation in ["naval", "covert"] else 18, 2))
	if presentation == "card-table":
		var frame := Panel.new(); frame.mouse_filter = Control.MOUSE_FILTER_IGNORE; frame.add_theme_stylebox_override("panel", GameLook.card_table_frame())
		get_parent().add_child(frame); get_parent().move_child(frame, get_index()); frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if presentation == "garden":
		status.add_theme_stylebox_override("normal", GameLook.carved_surface())
		status.add_theme_color_override("default_color", Color("fff0cf"))
	if presentation == "admiral":
		var score_surface := GameLook.box(theme.get_color("panel", "GamePalette"), theme.get_color("panel_edge", "GamePalette"), 7, 1)
		score_surface.content_margin_top = 0
		score_surface.content_margin_bottom = 0
		scores.add_theme_stylebox_override("normal", score_surface)
	instruction_label.add_theme_color_override("font_color", GameLook.INK)
	instruction_label.add_theme_color_override("font_outline_color", Color("fff4cf"))
	instruction_label.add_theme_constant_override("outline_size", 5)


func add_wordmark(words: Array[String], colors: Array[Color], prominent := false) -> void:
	title_label.hide()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(row)
	content.move_child(row, title_label.get_index())
	for index in words.size():
		var label := Label.new()
		var display_font := SystemFont.new()
		display_font.font_names = PackedStringArray(["Arial Black", "Arial Rounded MT Bold", "Arial"])
		display_font.font_weight = 900
		var story := get_theme_constant("story", "GamePalette") == 1
		if story:
			display_font.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])
		label.add_theme_font_override("font", display_font)
		label.text = words[index]
		label.add_theme_color_override("font_color", colors[index % colors.size()])
		label.add_theme_color_override("font_outline_color", Color("382538"))
		label.add_theme_constant_override("outline_size", 3 if story else 12)
		label.add_theme_color_override("font_shadow_color", Color("382538"))
		label.add_theme_constant_override("shadow_offset_y", 2 if story else 6)
		row.add_child(label)
		var adapt := func() -> void: label.add_theme_font_size_override("font_size", int(clampf(minf(available_size().x / (10.0 if prominent else 18.0), available_size().y * (0.12 if prominent else 0.08)), 26, 96 if prominent else 64)))
		resized.connect(adapt)
		get_parent_control().resized.connect(adapt)
		adapt.call_deferred()


func add_card(parent: Control, presentation := "", artwork: Texture2D = null) -> VBoxContainer:
	var panel: PanelContainer = preload("res://scripts/game_paper_panel.gd").new() if presentation == "stacked" else PanelContainer.new()
	var fill := get_theme_color("panel", "GamePalette") if has_theme_color("panel", "GamePalette") else Color("fff4cff2")
	var edge := get_theme_color("panel_edge", "GamePalette") if has_theme_color("panel_edge", "GamePalette") else Color("c58d49")
	var paper := get_theme_constant("story", "GamePalette") == 1 or get_theme_constant("royal", "GamePalette") == 1 or presentation == "clipboard"
	panel.add_theme_stylebox_override("panel", GameLook.paper_sheet(presentation == "clipboard") if paper else GameLook.box(fill, edge))
	if paper:
		panel.theme = GameLook.paper_theme(theme)
		var adapt_paper := func() -> void:
			if presentation == "framed" and artwork != null:
				return
			var compact := available_size().y < 500
			if not panel.has_meta("compact_paper") or panel.get_meta("compact_paper") != compact:
				panel.set_meta("compact_paper", compact)
				panel.add_theme_stylebox_override("panel", GameLook.paper_sheet(presentation == "clipboard", compact))
		resized.connect(adapt_paper)
		adapt_paper.call_deferred()
	if presentation == "framed" and artwork != null:
		panel.add_theme_stylebox_override("panel", GameLook.artwork_sheet(artwork))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	if presentation == "clipboard":
		var paper_surface := PanelContainer.new()
		paper_surface.add_theme_stylebox_override("panel", GameLook.paper_sheet())
		panel.add_child(paper_surface)
		paper_surface.add_child(column)
	else:
		panel.add_child(column)
	column.set_meta("outer_panel", panel)
	if presentation == "clipboard":
		var clip := TextureRect.new()
		clip.texture = RuntimeAssets.texture("res://ui/playful/paper-clip.svg")
		clip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		clip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(clip)
		clip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		clip.offset_left = -96
		clip.offset_right = 96
		clip.offset_top = -28
		clip.offset_bottom = 36
		# Ignore the decoration when the panel container sorts its content.
		clip.set_as_top_level(true)
		var place := func() -> void:
			clip.global_position = Vector2(panel.get_global_rect().get_center().x - 96, panel.global_position.y - 28)
			clip.size = Vector2(192, 64)
		panel.resized.connect(place)
		panel.item_rect_changed.connect(place)
		_floating_details_layouts.append(place)
		place.call_deferred()
	return column


# Decorative rules frame a real, accessible label without adding a control.
func add_section_heading(parent: Control, caption: String, font_size := 22) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var heading: Label
	for index in 3:
		if index == 1:
			heading = add_sidebar_text(row, caption)
			heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			heading.autowrap_mode = TextServer.AUTOWRAP_OFF
			heading.add_theme_font_size_override("font_size", font_size)
		else:
			var rule := ColorRect.new()
			rule.color = Color("88735488")
			rule.custom_minimum_size = Vector2(12, 1)
			rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(rule)
	return heading


# A persistent paper note shares layout, typography and accessible plain text.
func add_sticky_note(parent: Control, caption: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", GameLook.sticky_note())
	parent.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := add_sidebar_text(column, caption)
	heading.custom_minimum_size.y = 28
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", GameLook.NOTE_INK)
	var text := add_sidebar_text(column, "")
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_color_override("font_color", GameLook.NOTE_INK)
	var adapt := func() -> void:
		var short := available_size().y < 500 and get_theme_constant("story", "GamePalette") == 1
		var style := GameLook.sticky_note()
		for side in [SIDE_TOP, SIDE_BOTTOM]:
			style.set_content_margin(side, 8 if short else 18)
		panel.add_theme_stylebox_override("panel", style)
		heading.custom_minimum_size.y = 20 if short else 28
		heading.add_theme_font_size_override("font_size", 16 if short else 22)
		text.add_theme_font_size_override("font_size", 12 if short else 16)
	resized.connect(adapt)
	adapt.call_deferred()
	return {"panel": panel, "content": column, "heading": heading, "text": text}


# Persistent phase dialogs reuse shared cards and scrolling. The game owns
# visibility and dismissal; launcher navigation stays reachable above the shade.
func add_phase_dialog(fit_contents := false, full_screen := false, compact := false, dismissible := false, maximum_width := 0.0) -> Dictionary:
	var overlay := Control.new()
	overlay.theme = theme
	overlay.z_index = 1
	get_parent().add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color("171022bb")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	if dismissible:
		shade.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed: overlay.hide(); shade.accept_event())
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", GameLook.box(get_theme_color("panel", "GamePalette"), get_theme_color("panel_edge", "GamePalette")))
	if get_theme_constant("story", "GamePalette") == 1:
		panel.theme = GameLook.paper_theme(theme)
		panel.add_theme_stylebox_override("panel", GameLook.paper_sheet())
	overlay.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := add_sidebar_text(column, "")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22 if compact else 28)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	var actions := VBoxContainer.new()
	column.add_child(actions)
	var fit := func() -> void:
		if not is_inside_tree(): return
		var bounds := available_size().min(get_viewport_rect().size)
		var width := maxf(0, bounds.x - 32) if full_screen else minf(520 if compact else 700, maxf(0, bounds.x - 32))
		var width_limit := float(panel.get_meta("maximum_width", maximum_width))
		if width_limit > 0: width = minf(width, width_limit)
		var height := maxf(0, bounds.y - 112) if full_screen else minf(560, maxf(0, bounds.y - 112))
		# Set width first so wrapped names and team rows can settle before fitting.
		panel.size.x = width
		if fit_contents:
			var chrome_height := panel.get_combined_minimum_size().y - scroll.get_combined_minimum_size().y
			height = minf(height, chrome_height + body.get_combined_minimum_size().y)
		panel.size = Vector2(width, height)
		panel.position = Vector2((bounds.x - width) / 2.0, 80 + (bounds.y - 96 - height) / 2.0)
	get_parent_control().resized.connect(fit)
	# Wrapped headings can lower their minimum only after the new width settles.
	panel.minimum_size_changed.connect(func() -> void: fit.call_deferred())
	if fit_contents:
		body.minimum_size_changed.connect(func() -> void: fit.call_deferred())
	overlay.visibility_changed.connect(func() -> void:
		if overlay.visible:
			get_parent().move_child(overlay, get_parent().get_child_count() - 1)
			get_parent().move_child(back_button, get_parent().get_child_count() - 1)
			fit.call_deferred())
	fit.call_deferred()
	back_button.z_index = 2
	overlay.hide()
	return {"overlay": overlay, "heading": heading, "body": body, "actions": actions, "scroll": scroll, "panel": panel, "shade": shade}


func set_phase_dialog_width(dialog: Dictionary, maximum_width: float) -> void:
	dialog.panel.set_meta("maximum_width", maximum_width)
	dialog.panel.minimum_size_changed.emit()


# Additive result hooks retain the phase dialog's sizing, scrolling and navigation.
func set_phase_dialog_tone(dialog: Dictionary, tone := "") -> void:
	if tone.is_empty():
		dialog.overlay.theme = theme
		dialog.panel.theme = null
		dialog.panel.add_theme_stylebox_override("panel", GameLook.box(get_theme_color("panel", "GamePalette"), get_theme_color("panel_edge", "GamePalette")))
		if get_theme_constant("story", "GamePalette") == 1:
			dialog.panel.theme = GameLook.paper_theme(theme)
			dialog.panel.add_theme_stylebox_override("panel", GameLook.paper_sheet())
		dialog.shade.color = Color("171022bb")
		dialog.heading.remove_theme_color_override("font_color")
		return
	var colors := GameLook.result_colors(tone)
	var result_theme: Theme = theme.duplicate()
	result_theme.set_color("font_color", "Label", colors.ink)
	result_theme.set_color("default_color", "RichTextLabel", colors.ink)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill: Color = colors.fill.lerp(colors.edge, 0.28 if state == "hover" else 0.12)
		result_theme.set_stylebox(state, "GamePrimaryButton", GameLook.box(fill, colors.edge, 10, 2))
		result_theme.set_color("font_" + ("color" if state == "normal" else state + "_color"), "GamePrimaryButton", colors.ink)
	dialog.overlay.theme = result_theme
	dialog.panel.theme = result_theme
	var style := GameLook.box(colors.fill, colors.edge, 18, 2)
	style.shadow_color = colors.edge * Color(1, 1, 1, 0.22)
	style.shadow_size = 16
	dialog.panel.add_theme_stylebox_override("panel", style)
	dialog.shade.color = colors.shade
	dialog.heading.add_theme_color_override("font_color", colors.accent)


func add_team_reveal(parent: Control) -> HFlowContainer:
	var lineup := HFlowContainer.new()
	lineup.alignment = FlowContainer.ALIGNMENT_CENTER
	lineup.add_theme_constant_override("h_separation", 12)
	lineup.add_theme_constant_override("v_separation", 12)
	parent.add_child(lineup)
	lineup.resized.connect(func() -> void:
		if lineup.get_meta("assembly", false):
			fit_assembly_reveal(lineup))
	return lineup


# Reflow public assembly identities after a resize without publishing new state.
func fit_assembly_reveal(lineup: HFlowContainer) -> void:
	var bounds := available_size()
	var count := lineup.get_child_count()
	var columns := mini(count, 4 if bounds.x < 700 else 8)
	if columns == 0:
		return
	var width := maxf(0, bounds.x - 64)
	var short_view := bounds.y < 500
	var gap := 8 if short_view or bounds.x < 700 else 16
	lineup.add_theme_constant_override("h_separation", gap)
	var preferred_width := 72 if short_view or bounds.x < 700 else 112 if count <= 8 else 84
	var member_width := maxf(36, minf(preferred_width, floorf((width - (columns - 1) * gap) / columns)))
	var avatar_height := 32 if short_view else (42 if count > 8 else 60) if bounds.x < 700 else 96 if count <= 8 else 60
	lineup.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lineup.custom_minimum_size.x = member_width * columns + (columns - 1) * gap
	for member in lineup.get_children():
		member.custom_minimum_size.x = member_width
		var avatar: TextureRect = member.get_child(0)
		avatar.custom_minimum_size = Vector2(member_width, avatar_height)
		var name: Control = member.get_child(1)
		name.custom_minimum_size.x = member_width
		name.add_theme_font_size_override("normal_font_size" if name is RichTextLabel else "font_size", 11 if short_view else 12 if count > 8 else 14 if bounds.x < 700 else 18)


func set_team_reveal(lineup: HFlowContainer, roster: Array, tone := "success", compact := false, show_eliminated := false, assembly := false) -> void:
	lineup.set_meta("assembly", assembly)
	lineup.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if assembly else Control.SIZE_FILL
	if not assembly:
		lineup.custom_minimum_size.x = 0
	for child in lineup.get_children():
		lineup.remove_child(child)
		child.queue_free()
	var colors := GameLook.result_colors(tone)
	lineup.add_theme_constant_override("h_separation", 8 if compact else 12)
	lineup.add_theme_constant_override("v_separation", 6 if compact else 12)
	var member_width := 40 if compact else (160 if roster.size() == 1 else 80)
	var avatar_height := 40 if compact else (180 if roster.size() == 1 else 96)
	if assembly:
		member_width = 72
		avatar_height = 60
	for player in roster:
		var eliminated := show_eliminated and not bool(player.get("alive", true))
		var member := VBoxContainer.new()
		member.set_meta("eliminated", eliminated)
		member.custom_minimum_size.x = member_width
		lineup.add_child(member)
		var avatar := TextureRect.new()
		avatar.texture = RuntimeAssets.texture("res://ui/playful/tombstone.svg" if eliminated else "res://ui/playful/assembly-avatar.svg" if assembly else "res://web/avatar-%d.svg" % clampi(int(player.get("pose", 0)), 0, 5))
		avatar.self_modulate = Color.WHITE if eliminated else Color(str(player.get("color", "#58d6ff")))
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.custom_minimum_size = Vector2(member_width, avatar_height)
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		member.add_child(avatar)
		var halo := TextureRect.new()
		halo.texture = RuntimeAssets.texture("res://ui/playful/team-halo.svg")
		halo.modulate = colors.edge
		halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		halo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		halo.show_behind_parent = true
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.add_child(halo)
		halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if assembly and not eliminated:
			var detail := TextureRect.new()
			detail.texture = RuntimeAssets.texture("res://ui/playful/assembly-avatar-detail.svg")
			detail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			detail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
			avatar.add_child(detail)
			detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var name: Control
		if show_eliminated:
			var formatted := add_formatted_text(member, true)
			set_text_parts(formatted, [{"text": str(player.get("display_name", "Player")), "strikethrough": eliminated}])
			name = formatted
		else:
			var plain := Label.new()
			plain.text = str(player.get("display_name", "Player"))
			plain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			plain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			member.add_child(plain)
			name = plain
		name.custom_minimum_size.x = member_width
		name.add_theme_font_size_override("normal_font_size" if show_eliminated else "font_size", 12 if compact else (20 if roster.size() == 1 else 14))
		name.add_theme_color_override("default_color" if show_eliminated else "font_color", player.get("name_color", colors.accent if tone == "danger" else colors.ink))
		if assembly:
			name.add_theme_color_override("font_outline_color", Color("211519"))
			name.add_theme_constant_override("outline_size", 3)
	if assembly:
		fit_assembly_reveal.call_deferred(lineup)


# Plain session totals keep names and wins readable without a decorative card.
func add_session_score(parent: Control, formatted_name := false, stacked := false) -> Dictionary:
	var content_column := VBoxContainer.new()
	parent.add_child(content_column)
	var row: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
	content_column.add_child(row)
	var name_column := VBoxContainer.new()
	name_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_column.add_theme_constant_override("separation", 1)
	row.add_child(name_column)
	var player = add_formatted_text(name_column) if formatted_name else add_sidebar_text(name_column, "")
	if formatted_name:
		player.add_theme_font_size_override("normal_font_size", get_theme_font_size("font_size", "Label"))
	var underline := preload("res://scripts/game_score_underline.gd").new()
	underline.player = player
	name_column.add_child(underline)
	var score := Label.new()
	score.text = "0 WINS"
	score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(score)
	return {"player": player, "score": score, "content": content_column, "underline": underline, "row": row}


# Optional public asset plaque. Rules, collections and allotted height stay local.
func add_asset_score(parent: Control, artwork: Texture2D, identity: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", GameLook.asset_player_sheet(identity))
	parent.add_child(panel)
	panel.draw.connect(func() -> void: panel.draw_style_box(GameLook.party_sheen(), Rect2(Vector2.ZERO, panel.size).grow(-2)))
	var content := VBoxContainer.new(); content.add_theme_constant_override("separation", 5); panel.add_child(content)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); content.add_child(row)
	var token := TextureRect.new(); token.texture = artwork
	token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	token.custom_minimum_size = Vector2(52, 52); token.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(token)
	var values := VBoxContainer.new(); values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	values.add_theme_constant_override("separation", 0); row.add_child(values)
	var card := add_session_score(values, false, true)
	card.player.autowrap_mode = TextServer.AUTOWRAP_OFF; card.player.clip_text = true
	card.player.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.player.add_theme_color_override("font_color", GameLook.readable_text_color(identity, Color("061d30")))
	card.player.add_theme_font_override("font", GameLook.party_font(get_theme_default_font()))
	var balance := HBoxContainer.new(); balance.add_theme_constant_override("separation", 6); values.add_child(balance)
	var cash := TextureRect.new(); cash.texture = RuntimeAssets.texture("res://ui/playful/table-cash.svg")
	cash.custom_minimum_size = Vector2(24, 24); cash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; cash.mouse_filter = Control.MOUSE_FILTER_IGNORE; balance.add_child(cash)
	card.score.reparent(balance)
	card.score.add_theme_color_override("font_color", Color("ffe7a3"))
	card.score.add_theme_font_override("font", GameLook.party_font(get_theme_default_font()))
	var wealth := Label.new(); wealth.clip_text = true; wealth.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	wealth.add_theme_color_override("font_color", Color("b6d6e8")); content.add_child(wealth)
	card.merge({"panel":panel, "content":content, "row":row, "values":values, "balance":balance, "token":token, "icon":cash, "wealth":wealth, "identity":identity, "presentation":"asset", "active":false, "compact":false}, true)
	fit_asset_score(card, false)
	return card


func fit_asset_score(card: Dictionary, compact: bool, roomy := false) -> void:
	card.compact = compact
	card.panel.add_theme_stylebox_override("panel", GameLook.asset_player_sheet(card.identity, card.active, compact))
	card.content.add_theme_constant_override("separation", 2 if compact else 3)
	var balance_parent: Control = card.row if compact else card.values
	if card.balance.get_parent() != balance_parent: card.balance.reparent(balance_parent)
	card.token.visible = not compact
	card.token.custom_minimum_size = Vector2(60, 60) if roomy else Vector2(44, 44)
	card.icon.custom_minimum_size = Vector2(16, 14) if compact else Vector2(24, 24)
	card.player.add_theme_font_size_override("font_size", 11 if compact else 18 if roomy else 15)
	card.score.add_theme_font_size_override("font_size", 12 if compact else 28 if roomy else 24)
	card.wealth.visible = not compact; card.wealth.add_theme_font_size_override("font_size", 11)


# Place next to a player's name. The module owns expiry and authoritative text.
func add_speech_bubble(parent: Control) -> Dictionary:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", GameLook.speech_bubble())
	parent.add_child(panel)
	var label := add_sidebar_text(panel, "")
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 15)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.draw.connect(func() -> void:
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
		var points := PackedVector2Array([Vector2(1, 7), Vector2(-6, 12), Vector2(1, 17)])
		panel.draw_colored_polygon(points, style.bg_color)
		panel.draw_polyline(points, style.border_color, 1.0, true))
	panel.hide()
	return {"panel": panel, "label": label}


func add_score_speech_bubble(card: Dictionary) -> Dictionary:
	var bubble := add_speech_bubble(card.row)
	card.row.move_child(bubble.panel, 1)
	bubble.panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.player.get_parent_control().size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.row.add_child(spacer)
	card.row.move_child(spacer, 2)
	var targets := {"row": card.row, "player": card.player, "score": card.score}
	var surfaces := {"panel": bubble.panel, "label": bubble.label}
	var fit := func() -> void: _fit_score_speech_bubble(targets, surfaces)
	bubble["fit"] = fit
	bubble["name"] = card.player
	bubble["score"] = card.score
	card.row.resized.connect(fit)
	bubble.panel.visibility_changed.connect(fit)
	fit.call_deferred()
	return bubble


func _fit_score_speech_bubble(card: Dictionary, bubble: Dictionary) -> void:
	if card.row.size.x <= 0:
		return
	var gap: int = card.row.get_theme_constant("separation")
	var available := maxf(1, card.row.size.x - card.score.get_combined_minimum_size().x - gap * (3 if bubble.panel.visible else 2))
	var font: Font = card.player.get_theme_font("font")
	var font_size: int = card.player.get_theme_font_size("font_size")
	var natural := font.get_string_size(card.player.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var name_width := minf(natural, available * 0.45 if bubble.panel.visible else available)
	if not is_equal_approx(card.player.custom_minimum_size.x, name_width):
		card.player.custom_minimum_size.x = name_width
	var style: StyleBox = bubble.panel.get_theme_stylebox("panel")
	var insets := style.get_minimum_size().x
	var bubble_font: Font = bubble.label.get_theme_font("font")
	var bubble_size: int = bubble.label.get_theme_font_size("font_size")
	var text_width := bubble_font.get_string_size(bubble.label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, bubble_size).x
	var width := maxf(1, minf(text_width, available - name_width - insets))
	if not is_equal_approx(bubble.label.custom_minimum_size.x, width):
		bubble.label.custom_minimum_size.x = width


func set_speech_bubble(bubble: Dictionary, text: String, quality := "wrong") -> void:
	var names_changed: bool = bubble.has("name") and (bubble.get("layout_name", "") != bubble.name.text or bubble.get("layout_score", "") != bubble.score.text)
	if names_changed:
		bubble["layout_name"] = bubble.name.text
		bubble["layout_score"] = bubble.score.text
	if bubble.label.text != text or bubble.panel.get_meta("quality", "") != quality or names_changed:
		bubble.label.text = text
		bubble.label.add_theme_color_override("font_color", GameLook.guess_color(quality))
		bubble.panel.add_theme_stylebox_override("panel", GameLook.speech_bubble(quality))
		bubble.panel.set_meta("quality", quality)
		bubble.panel.queue_redraw()
		if bubble.has("fit"):
			bubble.fit.call_deferred()
	bubble.panel.visible = not text.is_empty()


# Options and history stay adjacent; replay has its own reserved row.
# Sheets expand below the actions, keeping replay reachable and the board fixed.
func add_board_details(captions: Array[String]) -> Array[VBoxContainer]:
	assert(_replay_slot != null and captions.size() == 2)
	_board_details = VBoxContainer.new()
	_board_details.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var parent := _replay_slot.get_parent()
	var index := _replay_slot.get_index()
	parent.add_child(_board_details)
	parent.move_child(_board_details, index)
	board_anchor.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_details_actions = GridContainer.new()
	_details_actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_details_actions.columns = 2
	_details_actions.add_theme_constant_override("h_separation", 12)
	_board_details.add_child(_details_actions)
	_replay_slot.reparent(_board_details)
	_replay_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_details_panels = GridContainer.new()
	# Keep each two-column row compact even when a sibling action needs more width.
	_details_panels.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_details_panels.columns = 2
	_details_panels.add_theme_constant_override("h_separation", 12)
	_board_details.add_child(_details_panels)
	_details_panels.hide()
	var bodies: Array[VBoxContainer] = []
	for caption in captions:
		var toggle := Button.new()
		toggle.text = caption + " +"
		toggle.toggle_mode = true
		toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details_actions.add_child(toggle)
		_details_toggles.append(toggle)
		var column := VBoxContainer.new()
		_details_panels.add_child(column)
		_details_columns.append(column)
		var body := add_card(column)
		var panel := body.get_parent_control()
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size.y = 220
		panel.hide()
		bodies.append(body)
		toggle.toggled.connect(func(open: bool) -> void:
			panel.visible = open
			toggle.text = caption + (" -" if open else " +")
			_details_panels.visible = _details_toggles.any(func(button: Button) -> bool: return button.button_pressed)
		)
	_layout_board_details()
	return bodies


func _layout_board_details() -> void:
	var width := minf(620, maxf(0, available_size().x - 48))
	var setup_actions := _board_auxiliary != null and _board_auxiliary.visible
	var narrow := available_size().x < 700 or setup_actions
	_replay_slot.visible = _board_replay.visible or setup_actions
	var action_index := 0 if setup_actions else 1
	if _replay_slot.get_index() != action_index:
		_board_details.move_child(_replay_slot, action_index)
	_details_panels.columns = 1 if narrow else 2
	_board_details.custom_minimum_size.x = width
	var column_width := (width - 12) / 2
	for toggle in _details_toggles:
		toggle.custom_minimum_size.x = column_width
	for column in _details_columns:
		column.custom_minimum_size.x = width if narrow else column_width


# Optional corner disclosures leave board centering and replay space unchanged.
# Reuse themed buttons/panels; narrow screens open one readable sheet at a time.
func add_corner_details(captions: Array[String], placement := Callable(), compact := false, fit_settings := false, roomy_controls := false, top_right := false, modal_settings := false, icon_only := false) -> Array[VBoxContainer]:
	assert(captions.size() in [1, 2])
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.theme = theme
	if compact:
		layer.theme = theme.duplicate()
		layer.theme.default_font_size = 14
		for type in ["Label", "RichTextLabel"]:
			for font in ["font_size", "normal_font_size", "bold_font_size"]:
				layer.theme.set_font_size(font, type, 14)
	get_parent().add_child(layer)
	var settings_backdrop := ColorRect.new()
	settings_backdrop.color = Color(0,0,0,.65)
	settings_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_backdrop.hide()
	layer.add_child(settings_backdrop)
	var settings_header := HBoxContainer.new()
	settings_header.hide()
	var buttons: Array[Button] = []
	var sheets: Array[PanelContainer] = []
	var bodies: Array[VBoxContainer] = []
	var navigation_order := {"index": -1}
	for index in captions.size():
		var button := Button.new()
		button.text = captions[index] + " +"
		button.accessibility_name = captions[index]
		button.toggle_mode = true
		layer.add_child(button)
		if theme.get_constant("garden", "GamePalette") == 1:
			GameLook.illustrated_control(button, RuntimeAssets.texture("res://ui/playful/control-%s.svg" % ("settings" if index == 0 else "history")), false, true, roomy_controls)
		buttons.append(button)
		var sheet := PanelContainer.new()
		sheet.add_theme_stylebox_override("panel", GameLook.box(theme.get_color("panel", "GamePalette"), theme.get_color("panel_edge", "GamePalette")))
		layer.add_child(sheet)
		sheet.hide()
		sheets.append(sheet)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		if fit_settings and index == 0: scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sheet.add_child(scroll)
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(body)
		bodies.append(body)
		if index == 0: body.add_child(settings_header)
		body.set_meta("toggle_button", button)
		if (fit_settings or modal_settings) and index == 0:
			var heading := add_sidebar_text(settings_header, captions[0])
			heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var close := Button.new()
			close.text = "CLOSE"
			settings_header.add_child(close)
			GameLook.compact_control(close)
			if modal_settings: close.custom_minimum_size = Vector2(64, 44)
			var escape := InputEventKey.new()
			escape.keycode = KEY_ESCAPE
			close.shortcut = Shortcut.new()
			close.shortcut.events = [escape]
			close.pressed.connect(func() -> void: buttons[0].button_pressed = false)
		button.toggled.connect(func(open: bool) -> void:
			sheet.visible = open
			button.text = _corner_detail_caption(captions[index], open)
			if index == 0 and not open:
				settings_backdrop.hide()
				if int(navigation_order.index) >= 0:
					get_parent().move_child(back_button, mini(int(navigation_order.index), get_parent().get_child_count() - 1))
					navigation_order.index = -1
			if open and (available_size().x < 700 or (placement.is_valid() and placement.call().has_area())):
				if captions.size() > 1: buttons[1 - index].button_pressed = false
		)
	settings_backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed: buttons[0].button_pressed = false
	)
	var fit_settings_sheet := func(bounds: Vector2, free_height: float) -> void:
		var minimum := sheets[0].get_combined_minimum_size()
		if settings_header.visible: minimum.y -= settings_header.get_combined_minimum_size().y + bodies[0].get_theme_constant("separation")
		var modal: bool = modal_settings or minimum.y > free_height
		settings_header.visible = modal
		var was_open := settings_backdrop.visible
		settings_backdrop.visible = modal and sheets[0].visible
		for button in buttons: button.visible = not settings_backdrop.visible
		if settings_backdrop.visible and not was_open:
			# Keep the same return target reachable above the blocking settings layer.
			navigation_order.index = back_button.get_index()
			get_parent().move_child(back_button, get_parent().get_child_count() - 1)
			settings_header.get_child(1).grab_focus()
		sheets[0].z_index = 1 if modal else 0
		if modal:
			if modal_settings:
				var content_size := bodies[0].get_combined_minimum_size() + Vector2(32, 32)
				sheets[0].size = Vector2(minf(maxf(360, content_size.x), bounds.x - 32), minf(content_size.y, bounds.y - 40))
			else: sheets[0].size = sheets[0].get_combined_minimum_size()
			sheets[0].position = (bounds - sheets[0].size) / 2
	var adapt := func() -> void:
		var bounds := available_size()
		if top_right:
			for index in captions.size():
				var button: Button = buttons[index]; GameLook.compact_control(button, true)
				button.accessibility_name = captions[index]
				var narrow := icon_only or bounds.x < (1100 if _table_header_content != null else 700); var button_width := 44.0 if narrow else 150.0
				button.text = "⚙" if narrow else _corner_detail_caption(captions[index], button.button_pressed)
				if icon_only:
					button.text = ""
					button.icon = RuntimeAssets.texture("res://ui/playful/table-settings.svg")
					button.expand_icon = true
					button.add_theme_constant_override("icon_max_width", 26)
					for state in ["normal", "hover", "pressed", "disabled"]:
						var surface := GameLook.box(theme.get_color("panel", "GamePalette"), theme.get_color("panel_edge", "GamePalette"), 24, 1)
						surface.set_content_margin_all(8)
						button.add_theme_stylebox_override(state, surface)
				if _table_header_content != null or icon_only: button.add_theme_font_size_override("font_size", 24 if narrow else 12)
				button.custom_minimum_size = Vector2(button_width, 44 if icon_only else 36); button.size = button.custom_minimum_size; button.position = Vector2(bounds.x - 60 - button_width, 12)
				var sheet: PanelContainer = sheets[index]; sheet.size = Vector2(minf(320, bounds.x - 32), minf(440, bounds.y - 86)); sheet.position = Vector2(maxf(16, bounds.x - sheet.size.x - 60), 58)
			if modal_settings: fit_settings_sheet.call(bounds, 0)
			return
		var area: Rect2 = placement.call() if placement.is_valid() else Rect2()
		if area.has_area():
			var button_width := (area.size.x - 12 * (captions.size() - 1)) / captions.size()
			var button_height := 0.0
			var short := compact or area.size.y < 180
			for index in captions.size():
				GameLook.compact_control(buttons[index], short)
				buttons[index].text = captions[index] + (" -" if buttons[index].button_pressed else " +") if short else _corner_detail_caption(captions[index], buttons[index].button_pressed, button_width < 210)
				buttons[index].custom_minimum_size = Vector2(button_width, 36)
				buttons[index].size = buttons[index].get_combined_minimum_size()
				buttons[index].position = area.position + Vector2(index * (button_width + 12),0)
				button_height = maxf(button_height,buttons[index].size.y)
			for index in captions.size():
				var sheet := sheets[index]
				sheet.size = Vector2(area.size.x,maxf(36,area.size.y - button_height - 8))
				sheet.position = area.position + Vector2(0,button_height + 8)
				if fit_settings and index == 0:
					sheet.size = sheet.get_combined_minimum_size()
					sheet.position.x = clampf(area.get_center().x - sheet.size.x / 2, 12, maxf(12,bounds.x - sheet.size.x - 12))
					sheet.position.y = minf(sheet.position.y,bounds.y - sheet.size.y - 12)
			if fit_settings or modal_settings: fit_settings_sheet.call(bounds,area.size.y - button_height - 8)
			return
		var width := minf(250 if compact else 320, maxf(180, bounds.x - 48))
		var button_width := minf(230 if roomy_controls else (170 if compact else 210), (bounds.x - 60) / 2)
		for index in captions.size():
			GameLook.compact_control(buttons[index], compact)
			buttons[index].text = _corner_detail_caption(captions[index], buttons[index].button_pressed)
			buttons[index].custom_minimum_size = Vector2(button_width, 60 if roomy_controls else 36)
			buttons[index].size = buttons[index].get_combined_minimum_size()
			buttons[index].position = Vector2((bounds.x - buttons[index].size.x) / 2 if captions.size() == 1 else 24 if index == 0 else bounds.x - 24 - buttons[index].size.x, bounds.y - 18 - buttons[index].size.y)
			sheets[index].size = Vector2(width, minf(240 if compact else 420, maxf(100, bounds.y - buttons[index].size.y - 130)))
			if fit_settings and index == 0: sheets[index].size = sheets[index].get_combined_minimum_size()
			sheets[index].position = Vector2((bounds.x - width) / 2 if captions.size() == 1 else 24 if index == 0 else bounds.x - 24 - width, buttons[index].position.y - sheets[index].size.y - 8)
		if fit_settings or modal_settings: fit_settings_sheet.call(bounds,buttons[0].position.y - 130)
		if captions.size() > 1 and bounds.x < 700 and buttons[0].button_pressed and buttons[1].button_pressed:
			buttons[0].button_pressed = false
	layer.resized.connect(adapt)
	for button in buttons: button.toggled.connect(func(_open: bool) -> void: adapt.call_deferred())
	for body in bodies: body.minimum_size_changed.connect(func() -> void: adapt.call_deferred())
	if placement.is_valid(): _floating_details_layouts.append(adapt)
	adapt.call_deferred()
	return bodies


func _corner_detail_caption(caption: String, open: bool, compact := false) -> String:
	var split := caption.rfind(" ")
	if (compact or available_size().x < 700) and split > 0:
		caption = caption.left(split) + "\n" + caption.substr(split + 1)
	return caption + (" -" if open else " +")


func add_score_card(parent: Control, icon: Texture2D, accent := Color.TRANSPARENT, presentation := "") -> Dictionary:
	var scroll := presentation == "scroll"
	var wood := presentation == "wood"
	var ledger := presentation == "ledger"
	var ornate := presentation == "ornate"
	var hanging := wood or (accent.a > 0.0 and not scroll and not ledger and not ornate)
	if hanging:
		var holder := VBoxContainer.new()
		holder.add_theme_constant_override("separation", 0)
		parent.add_child(holder)
		var hanger := TextureRect.new()
		if not wood:
			hanger.texture = RuntimeAssets.texture("res://ui/playful/hanger.svg")
			hanger.modulate = accent
		hanger.custom_minimum_size.y = 26
		hanger.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hanger.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		holder.add_child(hanger)
		var cord := preload("res://scripts/game_score_cord.gd").new()
		cord.hanger = hanger
		cord.accent = accent
		cord.chains = wood
		get_parent().add_child(cord)
		get_parent().move_child(cord, get_index())
		parent = holder
	var panel := PanelContainer.new()
	var surface := GameLook.surface("score-ornate" if ornate else "score-ledger" if ledger else "score-wood" if wood else ("score-scroll" if scroll else ("score-hanging" if hanging else "score")))
	if ornate:
		for side in [SIDE_LEFT, SIDE_RIGHT]:
			surface.set_texture_margin(side, 32)
			surface.set_content_margin(side, 30)
		for side in [SIDE_TOP, SIDE_BOTTOM]:
			surface.set_texture_margin(side, 54)
			surface.set_content_margin(side, 60)
	if ledger:
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			surface.set_texture_margin(side, 32)
			surface.set_content_margin(side, 24)
	if scroll:
		for side in [SIDE_TOP, SIDE_BOTTOM]:
			surface.set_texture_margin(side, 38)
			surface.set_content_margin(side, 40)
		for side in [SIDE_LEFT, SIDE_RIGHT]:
			surface.set_texture_margin(side, 24)
			surface.set_content_margin(side, 30)
	if wood:
		for side in [SIDE_TOP, SIDE_BOTTOM]:
			surface.set_texture_margin(side, 32)
			surface.set_content_margin(side, 34)
		for side in [SIDE_LEFT, SIDE_RIGHT]:
			surface.set_texture_margin(side, 28)
			surface.set_content_margin(side, 24)
		panel.clip_contents = true
	elif hanging:
		surface.modulate_color = accent
	panel.add_theme_stylebox_override("panel", surface)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var picture := TextureRect.new()
	picture.texture = icon
	picture.custom_minimum_size = Vector2(0, 80)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(picture)
	picture.visible = icon != null and not hanging and not scroll and not ledger and not ornate
	var name_panel := PanelContainer.new()
	name_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	column.add_child(name_panel)
	var name_column := VBoxContainer.new()
	name_column.add_theme_constant_override("separation", 1)
	name_panel.add_child(name_column)
	var player := add_sidebar_text(name_column, "")
	player.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player.add_theme_color_override("font_color", Color.WHITE)
	player.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var underline := preload("res://scripts/game_score_underline.gd").new()
	underline.player = player
	name_column.add_child(underline)
	if hanging or scroll:
		name_panel.add_theme_stylebox_override("panel", GameLook.box(GameLook.CREAM, Color("713824"), 12, 2))
		player.add_theme_color_override("font_color", GameLook.INK)
		player.add_theme_font_size_override("font_size", 21)
		name_panel.custom_minimum_size.y = 52
	var score_panel := PanelContainer.new()
	if ornate:
		var divider := HSeparator.new()
		divider.set_meta("score_decoration", true)
		column.add_child(divider)
		var laurel := TextureRect.new()
		laurel.set_meta("score_decoration", true)
		laurel.texture = RuntimeAssets.texture("res://ui/playful/stat-wins.svg")
		laurel.custom_minimum_size = Vector2(0, 66)
		laurel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		laurel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		column.add_child(laurel)
	if hanging and get_theme_constant("classic", "GamePalette") == 1:
		var caption := add_sidebar_text(column, "WINS")
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 16)
		caption.add_theme_color_override("font_color", GameLook.CREAM)
	score_panel.add_theme_stylebox_override("panel", GameLook.box(Color("142b47"), Color("3f6390"), 12, 2))
	column.add_child(score_panel)
	var score := Label.new()
	score.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	score.text = "0"
	score_panel.add_child(score)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 42)
	score.add_theme_color_override("font_color", Color.WHITE)
	if scroll:
		name_panel.add_theme_stylebox_override("panel", GameLook.box(Color("fff4cf55"), accent.darkened(0.25), 8, 2))
		player.add_theme_color_override("font_color", GameLook.SCROLL_INK)
		score_panel.add_theme_stylebox_override("panel", GameLook.box(Color("dca95433"), Color("ac793c88"), 8, 1))
		score.add_theme_color_override("font_color", GameLook.SCROLL_INK)
	if wood:
		score_panel.add_theme_stylebox_override("panel", GameLook.box(GameLook.WOOD_INSET, GameLook.WOOD_EDGE, 8, 2))
		score.add_theme_color_override("font_color", GameLook.CREAM)
	if ledger:
		player.add_theme_color_override("font_color", GameLook.SCROLL_INK)
		player.add_theme_font_size_override("font_size", 21)
		score_panel.add_theme_stylebox_override("panel", GameLook.box(Color("dec49a44"), Color("bc945866"), 6, 1))
		score.add_theme_color_override("font_color", GameLook.SCROLL_INK)
		score.add_theme_font_size_override("font_size", 27)
	if ornate:
		player.add_theme_color_override("font_color", GameLook.SCROLL_INK)
		player.add_theme_font_size_override("font_size", 21)
		score_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		score.add_theme_color_override("font_color", GameLook.SCROLL_INK)
		score.add_theme_font_size_override("font_size", 23)
		column.add_theme_constant_override("separation", 10)
	return {"player": player, "score": score, "panel": panel, "content": column, "name_panel": name_panel, "score_panel": score_panel, "underline": underline, "presentation": presentation, "text_color": GameLook.SCROLL_INK if scroll or ledger or ornate else (GameLook.CREAM if wood else Color.WHITE)}


# Icon counters inherit the score-card typography and keep content inside its frame.
func add_score_stat(card: Dictionary, icon: Texture2D, text: String) -> Label:
	var divider := HSeparator.new()
	card.content.add_child(divider)
	var picture := TextureRect.new()
	picture.texture = icon
	picture.custom_minimum_size = Vector2(0, 52)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.content.add_child(picture)
	var value := add_sidebar_text(card.content, text)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 20)
	value.add_theme_color_override("font_color", card.text_color)
	return value


# Dense multi-seat boards keep ornate cards inside the shared sidebar geometry.
# Apply after adding counters; other card presentations retain their usual layout.
func set_score_card_compact(card: Dictionary, compact: bool, minimal_decoration := false) -> void:
	if card.get("presentation", "") != "ornate" or (card.get("compact", false) == compact and card.get("minimal_decoration", false) == minimal_decoration):
		return
	card.compact = compact
	card.minimal_decoration = minimal_decoration
	var surface: StyleBoxTexture = card.panel.get_theme_stylebox("panel").duplicate()
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		surface.set_texture_margin(side, 18 if compact else 32)
		surface.set_content_margin(side, 24 if compact else 30)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		surface.set_texture_margin(side, 18 if compact else 54)
		surface.set_content_margin(side, (16 if minimal_decoration else 30) if compact else 60)
	card.panel.add_theme_stylebox_override("panel", surface)
	card.panel.clip_contents = compact
	card.content.add_theme_constant_override("separation", 3 if compact else 10)
	card.player.add_theme_font_size_override("font_size", 15 if compact else 21)
	card.score.add_theme_font_size_override("font_size", 16 if compact else 23)
	for child in card.content.get_children():
		if child.has_meta("score_decoration"):
			child.visible = not (compact and minimal_decoration)
		if child is TextureRect and child.visible:
			if not child.has_meta("score_original_height"):
				child.set_meta("score_original_height", child.custom_minimum_size.y)
			child.custom_minimum_size.y = 20 if compact else child.get_meta("score_original_height")
		elif child is Label:
			child.add_theme_font_size_override("font_size", 15 if compact else 20)


# Identity accents use the same shared surface as the score-card presentation.
func set_score_card_identity(card: Dictionary, identity: Color) -> void:
	if card.get("presentation", "") == "ornate":
		card.name_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		return
	var ledger: bool = card.get("presentation", "") == "ledger"
	var surface := GameLook.box(Color("fff1d933") if ledger else GameLook.CREAM, identity.darkened(0.25), 6 if ledger else 12, 1 if ledger else 2)
	card.name_panel.add_theme_stylebox_override("panel", surface)


func set_score_card_active(card: Dictionary, active: bool, prominent := false) -> void:
	if prominent and card.get("presentation", "") in ["ornate", "ledger"]:
		var highlight := GameLook.box(Color("ffe49a") if active else Color.TRANSPARENT, Color("b78330") if active else Color.TRANSPARENT, 6, 2)
		highlight.set_content_margin_all(4)
		card.name_panel.add_theme_stylebox_override("panel", highlight)
	card.underline.active = active
	card.underline.queue_redraw()
	if card.get("presentation", "") == "asset":
		card.active = active
		card.panel.add_theme_stylebox_override("panel", GameLook.asset_player_sheet(card.identity, active, card.compact))


# Optional illustrated heading keeps shared navigation above the artwork.
func add_title_art(texture: Texture2D, height := 120.0, prominent := false, compact := false) -> void:
	_compact_heading = compact
	if compact:
		# RichTextLabel otherwise measures a new message at its previous width for
		# one frame, briefly growing the heading and shrinking the centered board.
		status.fit_content = false
		status.custom_minimum_size.y = 56
		status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		for font_size in ["normal_font_size", "bold_font_size"]:
			status.add_theme_font_size_override(font_size, 17)
		var plaque := status.get_theme_stylebox("normal").duplicate() as StyleBox
		plaque.set_content_margin(SIDE_TOP, 7)
		plaque.set_content_margin(SIDE_BOTTOM, 7)
		status.add_theme_stylebox_override("normal", plaque)
	title_label.hide()
	var art := TextureRect.new()
	art.texture = texture
	art.custom_minimum_size.y = height
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(art)
	content.move_child(art, title_label.get_index())
	status.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var adapt := func() -> void:
		if not compact:
			status.custom_minimum_size.x = minf(600, maxf(200, available_size().x - 64))
		art.custom_minimum_size.y = minf(height, maxf(36.0 if compact else 64.0, available_size().y * (0.24 if prominent else 0.10 if compact else 0.14)))
		if compact and get_theme_constant("card_table", "GamePalette") == 1:
			var short := available_size().y < 500 and available_size().x >= 700
			art.custom_minimum_size.y = 26 if short else minf(height, 48)
			_status_plaque_height = 34 if short else 56 if available_size().x < 550 else 44
		if prominent and texture != null:
			var aspect := float(texture.get_width()) / maxf(1, texture.get_height())
			art.custom_minimum_size.y = minf(art.custom_minimum_size.y, maxf(0, available_size().x - 48) / aspect)
	resized.connect(adapt)
	get_parent_control().resized.connect(adapt)
	adapt.call_deferred()


func reserve_status_plaque(width: float, height: float) -> void:
	_status_plaque_width = maxf(0, width)
	_status_plaque_height = maxf(56, height)
	_compact_heading = true
	status.fit_content = false
	status.custom_minimum_size.y = _status_plaque_height


func add_details(parent: Control, caption: String, presentation := "", indicator := true) -> VBoxContainer:
	var scroll := presentation == "scroll"
	var sheet: PanelContainer
	var group := VBoxContainer.new()
	if scroll:
		sheet = PanelContainer.new()
		sheet.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		parent.add_child(sheet)
		sheet.add_child(group)
	else:
		parent.add_child(group)
	var toggle := Button.new()
	toggle.text = caption + (" +" if indicator else "")
	toggle.toggle_mode = true
	group.add_child(toggle)
	if scroll:
		GameLook.scroll_toggle(toggle, false)
	var body := VBoxContainer.new()
	body.set_meta("toggle_button", toggle)
	body.hide()
	group.add_child(body)
	toggle.toggled.connect(func(open: bool) -> void:
		body.visible = open
		toggle.text = caption + ((" -" if open else " +") if indicator else "")
		if scroll:
			sheet.add_theme_stylebox_override("panel", GameLook.scroll_sheet() if open else StyleBoxEmpty.new())
			GameLook.scroll_toggle(toggle, open)
	)
	return body


func add_text(value: String, font_size := 18) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	content.add_child(label)
	return label


# Optional reusable playfield/sidebar layout; wraps on narrow host windows.
func add_sidebar_layout() -> Dictionary:
	var layout := HFlowContainer.new()
	layout.add_theme_constant_override("h_separation", 24)
	layout.add_theme_constant_override("v_separation", 16)
	content.add_child(layout)
	var playfield := VBoxContainer.new()
	playfield.custom_minimum_size.x = 316
	playfield.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(playfield)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 280
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(sidebar)
	return {"playfield": playfield, "sidebar": sidebar}


func add_sidebar_text(sidebar: Control, value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(label)
	return label


# Labeled settings inherit the shared theme and fit narrow game layouts.
func add_choice_control(parent: Control, title: String, choices: Array[String], inline := false) -> OptionButton:
	var group: BoxContainer = HBoxContainer.new() if inline else VBoxContainer.new()
	parent.add_child(group)
	var label := add_sidebar_text(group, title)
	if inline:
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var choice := OptionButton.new()
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in choices:
		choice.add_item(item)
	group.add_child(choice)
	return choice


# A themed toggle has an explicit on/off label and standard keyboard behavior.
func add_toggle_control(parent: Control, title: String, enabled := true) -> Button:
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.set_meta("game_control_labels", [title + ": ON", title + ": OFF"])
	toggle.button_pressed = enabled
	toggle.text = title + (": ON" if enabled else ": OFF")
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.toggled.connect(func(on: bool) -> void: toggle.text = title + (": ON" if on else ": OFF"))
	parent.add_child(toggle)
	return toggle


# Custom numeric settings share the theme, label, and narrow-screen layout.
func add_number_control(parent: Control, title: String, minimum: float, maximum: float, step: float, value: float, suffix := "") -> SpinBox:
	var group := VBoxContainer.new()
	parent.add_child(group)
	add_sidebar_text(group, title)
	var input := SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.step = step
	input.value = value
	input.suffix = suffix
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.get_line_edit().virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	group.add_child(input)
	return input


func add_history_log(sidebar: VBoxContainer, parent_scrolling := false) -> RichTextLabel:
	var story := get_theme_constant("story", "GamePalette") == 1
	var heading := add_section_heading(sidebar, "HISTORY") if story else add_sidebar_text(sidebar, "HISTORY")
	if get_theme_constant("story", "GamePalette") == 1:
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.add_theme_font_size_override("font_size", 22)
	var log := RichTextLabel.new()
	log.custom_minimum_size = Vector2(0, 0 if parent_scrolling else 220)
	log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log.scroll_following = false
	log.fit_content = parent_scrolling
	log.scroll_active = not parent_scrolling
	log.bbcode_enabled = false
	sidebar.add_child(log)
	return log


# Social games share an asymmetric, responsive pair of columns and a utility dock.
# It centers the complete composition, rather than treating a timer as a board.
func add_social_layout(primary_ratio := 0.7) -> Dictionary:
	var center := CenterContainer.new()
	content.add_child(center)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	center.add_child(body)
	var columns := GridContainer.new()
	columns.columns = 2
	columns.add_theme_constant_override("h_separation", 16)
	columns.add_theme_constant_override("v_separation", 16)
	body.add_child(columns)
	var primary := VBoxContainer.new()
	var history := VBoxContainer.new()
	for column in [primary, history]:
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
	var footer := HFlowContainer.new()
	footer.alignment = FlowContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("h_separation", 12)
	footer.add_theme_constant_override("v_separation", 12)
	body.add_child(footer)
	var adapt := func() -> void:
		var bounds := available_size()
		var width := maxf(0, minf(1200, bounds.x - 48))
		var narrow := width < 660
		body.custom_minimum_size.x = width
		body.add_theme_constant_override("separation", 8 if bounds.y < 500 else 16)
		columns.columns = 1 if narrow else 2
		primary.custom_minimum_size.x = width if narrow else (width - 16) * clampf(primary_ratio, 0.5, 0.75)
		history.custom_minimum_size.x = width if narrow else (width - 16) - primary.custom_minimum_size.x
		if center.is_visible_in_tree():
			add_theme_constant_override("margin_top", 72 if bounds.x < 700 else 16)
			add_theme_constant_override("margin_bottom", 16)
	resized.connect(adapt)
	get_parent_control().resized.connect(adapt)
	center.visibility_changed.connect(adapt)
	adapt.call_deferred()
	return {"primary": primary, "history": history, "footer": footer, "columns": columns, "body": body, "root": center}


# Logs stay open, scroll inside their paper and preserve browsing on unchanged sync.
func set_history_text(log: RichTextLabel, value: String) -> void:
	if log.text != value:
		if log.has_meta("history_entries"):
			log.remove_meta("history_entries")
		log.text = value
		log.scroll_to_line(0)


# Public history headings are bold, with safe literal names and stable scrolling.
func set_history_entries(log: RichTextLabel, entries: Array) -> void:
	var key := JSON.stringify(entries)
	if log.get_meta("history_entries", "") == key:
		return
	var parts: Array = []
	for index in entries.size():
		if index > 0:
			parts.append({"text": "\n\n────────────────\n\n", "color": Color("88735488")})
		parts.append({"text": str(entries[index].heading), "bold": true, "font_size": 18 if available_size().x < 700 or available_size().y < 500 else 22})
		parts.append("\n" + str(entries[index].detail))
	set_text_parts(log, parts)
	log.set_meta("history_entries", key)
	log.scroll_to_line(0)


# Symmetric side columns keep the playfield on the screen's horizontal center.
func add_centered_layout(compact := false, center_sidebars := false, maximum_width := 940.0, minimum_playfield_width := 316.0) -> Dictionary:
	var layout := GridContainer.new()
	layout.columns = 3
	layout.add_theme_constant_override("h_separation", 24)
	layout.add_theme_constant_override("v_separation", 16)
	if compact:
		var center := CenterContainer.new()
		content.add_child(center)
		center.add_child(layout)
	else:
		content.add_child(layout)
	var left := VBoxContainer.new()
	var playfield := VBoxContainer.new()
	var right := VBoxContainer.new()
	var sidebar_spacers: Dictionary = {}
	for column in [left, playfield, right]:
		if center_sidebars and column != playfield:
			var spacer := Control.new()
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			column.add_child(spacer)
			sidebar_spacers[column] = spacer
		column.custom_minimum_size.x = (190 if compact else 220) if column != playfield else minimum_playfield_width
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		layout.add_child(column)
	var adapt := func() -> void:
		# Equal side widths center the board even when settings/names differ.
		var have_sidebars := false
		for column in [left, right]:
			for child in column.get_children():
				if child is Control and child.visible and child != sidebar_spacers.get(column): have_sidebars = true
		left.visible = have_sidebars; right.visible = have_sidebars
		var available_width := available_size().x - 48 - content_scroll.get_v_scroll_bar().get_combined_minimum_size().x
		var side_width := maxf(190 if compact else 220, maxf(left.get_minimum_size().x, right.get_minimum_size().x))
		left.custom_minimum_size.x = side_width
		right.custom_minimum_size.x = side_width
		var board_width := available_width - side_width * 2 - 48 if have_sidebars and available_width >= side_width * 2 + minimum_playfield_width + 48 else available_width
		if not is_equal_approx(_board_width_limit, board_width):
			_board_width_limit = board_width; board_space_changed.emit()
		var required_width := side_width * 2 + maxf(minimum_playfield_width, playfield.get_minimum_size().x) + 48
		var narrow := available_width < maxf(804 if minimum_playfield_width >= 316 else 0, required_width)
		for column in sidebar_spacers:
			var card_height := 0.0
			for child in column.get_children():
				if child != sidebar_spacers[column] and child is Control and child.visible:
					card_height += child.get_combined_minimum_size().y + column.get_theme_constant("separation")
			var board_height := board_anchor.get_combined_minimum_size().y if board_anchor != null else 0.0
			sidebar_spacers[column].custom_minimum_size.y = 0 if narrow else maxf(0, (board_height - card_height) / 2)
		if compact:
			layout.custom_minimum_size.x = minf(available_width, maximum_width) if maximum_width > 0 else available_width
		layout.columns = 1 if narrow or not have_sidebars else 3
		layout.move_child(playfield if narrow else left, 0)
		layout.move_child(right if narrow else playfield, 1)
		layout.move_child(left if narrow else right, 2)
	resized.connect(adapt)
	get_parent_control().resized.connect(adapt)
	# Expanded details can change a column's minimum width without a resize.
	for column in [left, playfield, right]:
		column.minimum_size_changed.connect(adapt, CONNECT_DEFERRED)
	adapt.call_deferred()
	return {"playfield": playfield, "left_sidebar": left, "sidebar": right}


func add_formatted_text(parent: Control, centered := false) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.fit_content = true
	label.scroll_active = false
	label.bbcode_enabled = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("normal_font_size", 18)
	parent.add_child(label)
	return label


# Explicit runs keep player names plain text, even if they contain BBCode.
func set_text_parts(label: RichTextLabel, parts: Array) -> void:
	label.clear()
	for part in parts:
		if part is Dictionary:
			if part.has("font_size"):
				label.push_font_size(int(part.font_size))
			if part.get("bold", false):
				label.push_bold()
			if part.has("color"):
				label.push_color(part.color)
			if part.get("strikethrough", false):
				label.push_strikethrough()
			label.add_text(str(part.text))
			if part.get("strikethrough", false):
				label.pop()
			if part.has("color"):
				label.pop()
			if part.get("bold", false):
				label.pop()
			if part.has("font_size"):
				label.pop()
		else:
			label.add_text(str(part))
