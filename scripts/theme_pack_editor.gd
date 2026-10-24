extends Control

signal exit_requested
const EditorStyle = preload("res://scripts/asset_editor_style.gd")

var manager: ThemePacks
var draft: Dictionary = {}
var original: Dictionary = {}
var selected: Dictionary = {}
var group_filter := "All groups"
var game_choice := OptionButton.new()
var theme_choice := OptionButton.new()
var group_choice := OptionButton.new()
var grid := GridContainer.new()
var inspector := VBoxContainer.new()
var notice := Label.new()
var save_button: Button
var preview_card: GameCard
var invalid_label := false
var games: Array[String] = []
var packs: Array = []
var search := LineEdit.new()
var chooser := FileDialog.new()
var reduced_motion := false
var preview_audio := AudioStreamPlayer.new()
var preview_video: Control
var settings_store := GameSettingsStore.new()
var use_button: Button
var skin_status := Label.new()
var initial_game_id := ""
var initial_slot_id := ""
var definitions_root := "res://Games"
var loader: Thread
var loading_index := -1
var browse_count := Label.new()
var sort_choice := OptionButton.new()
var browser_scroll := ScrollContainer.new()
var workspace_scroll := ScrollContainer.new()
var thumbnails: Array[Dictionary] = []
var tile_buttons: Dictionary = {}
var tile_pending: Array = []
var duplicate_button: Button
var restore_button: Button
var discard_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); background.color = EditorStyle.BACKGROUND; background.mouse_filter = Control.MOUSE_FILTER_IGNORE; background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation", 10); margin.add_child(body)
	var bar := HBoxContainer.new(); body.add_child(bar)
	bar.add_child(_button("Return", func() -> void: request_leave(func() -> void: exit_requested.emit())))
	var title := EditorStyle.label("THEMES", 24, Color.WHITE); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bar.add_child(title)
	workspace_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; workspace_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_child(workspace_scroll)
	var workspace := VBoxContainer.new(); workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL; workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL; workspace.add_theme_constant_override("separation", 10); workspace_scroll.add_child(workspace)
	var controls := EditorStyle.panel(EditorStyle.TOOLBAR, 12); workspace.add_child(controls)
	var toolbar := HFlowContainer.new(); toolbar.add_theme_constant_override("h_separation", 12); controls.add_child(toolbar)
	var folders := DirAccess.get_directories_at(definitions_root); folders.sort()
	for id in folders:
		if not id.begins_with("_") and FileAccess.file_exists(definitions_root.path_join(id).path_join("theme-slots.json")):
			games.append(id); game_choice.add_item(id.capitalize())
	game_choice.custom_minimum_size.x = 150; game_choice.fit_to_longest_item = false; game_choice.clip_text = true
	EditorStyle.field(toolbar, "GAME", game_choice)
	game_choice.item_selected.connect(func(index: int) -> void: request_leave(func() -> void: _request_game(index)))
	theme_choice.custom_minimum_size.x = 150; theme_choice.fit_to_longest_item = false; theme_choice.clip_text = true
	EditorStyle.field(toolbar, "SKIN", theme_choice)
	theme_choice.item_selected.connect(func(index: int) -> void: request_leave(func() -> void: _apply_theme(str(packs[index].id))))
	var pack_actions := HBoxContainer.new(); pack_actions.size_flags_vertical = Control.SIZE_SHRINK_END; toolbar.add_child(pack_actions)
	duplicate_button = _button("Duplicate skin", _duplicate); pack_actions.add_child(duplicate_button)
	restore_button = _button("Restore Previous", _previous); pack_actions.add_child(restore_button)
	var split := SplitContainer.new(); split.size_flags_vertical = Control.SIZE_EXPAND_FILL; workspace.add_child(split)
	var browser := EditorStyle.panel(EditorStyle.BROWSER, 12); browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(browser)
	var browser_body := VBoxContainer.new(); browser_body.add_theme_constant_override("separation", 8); browser.add_child(browser_body)
	var browser_title := HBoxContainer.new(); browser_body.add_child(browser_title)
	var browser_label := EditorStyle.label("ASSET BROWSER", 13, EditorStyle.ACCENT); browser_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; browser_title.add_child(browser_label)
	browse_count.add_theme_font_size_override("font_size", 12); browser_title.add_child(browse_count)
	var filters := HFlowContainer.new(); filters.add_theme_constant_override("h_separation", 10); browser_body.add_child(filters)
	search.placeholder_text = "Search assets"; search.custom_minimum_size.x = 140; EditorStyle.field(filters, "SEARCH", search); search.text_changed.connect(func(_text: String) -> void: _populate())
	EditorStyle.field(filters, "GROUP", group_choice); group_choice.item_selected.connect(func(index: int) -> void: group_filter = group_choice.get_item_text(index); _populate())
	for caption in ["Name A–Z", "Name Z–A", "Group"]: sort_choice.add_item(caption)
	EditorStyle.field(filters, "SORT", sort_choice); sort_choice.item_selected.connect(func(_index: int) -> void: _populate())
	browser_body.add_child(HSeparator.new())
	browser_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; browser_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; browser_body.add_child(browser_scroll)
	grid.columns = 3; grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10); grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; browser_scroll.add_child(grid)
	var detail_panel := EditorStyle.panel(EditorStyle.INSPECTOR, 12); detail_panel.custom_minimum_size.x = 240; detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(detail_panel)
	var detail_body := VBoxContainer.new(); detail_body.add_theme_constant_override("separation", 8); detail_panel.add_child(detail_body)
	detail_body.add_child(EditorStyle.label("ASSET PREVIEW", 13, EditorStyle.ACCENT))
	detail_body.add_child(HSeparator.new())
	var detail_scroll := ScrollContainer.new(); detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; detail_body.add_child(detail_scroll)
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL; detail_scroll.add_child(inspector)
	split.resized.connect(func() -> void:
		split.vertical = size.x < 700
		browser.custom_minimum_size.y = 350 if split.vertical else 300
		detail_panel.custom_minimum_size.y = 300 if split.vertical else 260
		split.split_offset = 0 if split.vertical else int(size.x * 0.1)
	)
	browser_scroll.resized.connect(func() -> void: grid.columns = maxi(1, int((browser_scroll.size.x - 12) / 164)))
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.add_child(notice)
	var footer := HFlowContainer.new(); body.add_child(footer)
	save_button = _button("Save", _confirm_save); footer.add_child(save_button)
	discard_button = _button("Discard", func() -> void: _apply_theme(str(original.id))); footer.add_child(discard_button)
	use_button = _button("Use skin", _use_skin); footer.add_child(use_button)
	skin_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.add_child(skin_status)
	chooser.access = FileDialog.ACCESS_FILESYSTEM; chooser.file_mode = FileDialog.FILE_MODE_OPEN_FILE; chooser.use_native_dialog = true; add_child(chooser)
	chooser.file_selected.connect(_replace)
	add_child(preview_audio); preview_audio.bus = "Effects"
	if not games.is_empty(): _request_game(maxi(0, games.find(initial_game_id)))
	else:
		_set_loading(true)
		notice.text = "No games provide theme slots yet."


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new(); button.text = text; button.custom_minimum_size.y = 44; button.pressed.connect(callback); return button


func _load_game(index: int) -> void:
	_cancel_loading()
	_set_game(index, ThemePacks.new(games[index], definitions_root))
	_load_theme("default")


func _set_game(index: int, next_manager: ThemePacks) -> void:
	game_choice.select(index); manager = next_manager; group_choice.clear(); group_choice.add_item("All groups")
	var groups: Array = []
	for slot in manager.slots:
		if not groups.has(slot.group): groups.append(slot.group); group_choice.add_item(slot.group)
	group_filter = "All groups"
	search.set_block_signals(true); search.clear(); search.set_block_signals(false)


func _request_game(index: int) -> void:
	if loader != null or index < 0 or index >= games.size(): return
	suspend_previews()
	loading_index = index
	_set_loading(true)
	notice.text = "Loading skins…"
	var id := games[index]
	var definitions := definitions_root
	loader = Thread.new()
	# Validation can decode media or invoke FFmpeg. Keep it off the UI thread.
	loader.start(func() -> Dictionary:
		var next_manager := ThemePacks.new(id, definitions)
		return {"manager": next_manager, "packs": next_manager.list_packs()}
	)


func _set_loading(busy: bool) -> void:
	for control in [game_choice, theme_choice, group_choice, sort_choice, duplicate_button, restore_button, save_button, discard_button, use_button]:
		control.disabled = busy
	search.editable = not busy
	grid.visible = not busy
	inspector.visible = not busy


func _cancel_loading() -> void:
	if loader != null:
		loader.wait_to_finish()
		loader = null
		loading_index = -1
		_set_loading(false)


func _process(_delta: float) -> void:
	if loader != null and not loader.is_alive():
		var result: Dictionary = loader.wait_to_finish()
		loader = null
		_set_game(loading_index, result.manager)
		loading_index = -1
		packs = result.packs
		_set_loading(false)
		var accepted := str(settings_store.load_settings(manager.game_id, {"theme": "default"}).theme)
		_apply_theme(accepted)
		if games.has(initial_game_id) and initial_game_id != manager.game_id:
			var next_index := games.find(initial_game_id)
			initial_game_id = ""
			_request_game(next_index)
			return
		initial_game_id = ""
		_focus_slot(initial_slot_id)
		initial_slot_id = ""
	if not is_visible_in_tree() or loader != null: return
	var tile_budget := Time.get_ticks_msec() + 3
	for index in mini(8, tile_pending.size()):
		_append_tile(tile_pending.pop_front())
		if Time.get_ticks_msec() >= tile_budget: break
	# Only decode a visible thumbnail per frame, instead of loading entire decks.
	for index in thumbnails.size():
		var job: Dictionary = thumbnails[index]
		if not is_instance_valid(job.target): continue
		if not job.target.get_global_rect().intersects(browser_scroll.get_global_rect()): continue
		thumbnails.remove_at(index)
		if job.slot.has("preview"):
			var face := GameCard.new(); face.card = job.slot.preview.duplicate(true); face.card.display_name = manager.display_name(job.slot.id, job.slot.label, draft); face.texture = GameCard.artwork(_source(job.slot)); face.accent = Color(job.slot.preview.color); face.mouse_filter = Control.MOUSE_FILTER_IGNORE; job.target.add_child(face); face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		else:
			var image := TextureRect.new(); image.texture = RuntimeAssets.texture(_source(job.slot)); image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.mouse_filter = Control.MOUSE_FILTER_IGNORE; job.target.add_child(image); image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		break


func open_asset(game_id: String, slot_id: String) -> void:
	if loader != null:
		initial_game_id = game_id
		initial_slot_id = slot_id
		return
	if not game_id.is_empty() and games.has(game_id) and (manager == null or manager.game_id != game_id):
		initial_slot_id = slot_id
		_request_game(games.find(game_id))
	else:
		_focus_slot(slot_id)
		_inspect()
		_changed()


func _focus_slot(id: String) -> void:
	if manager == null or id.is_empty(): return
	for slot in manager.slots:
		if slot.id == id:
			selected = slot
			_inspect()
			_mark_selection()
			return


func _load_theme(id: String) -> void:
	_cancel_loading()
	_set_loading(false)
	packs = manager.list_packs()
	_apply_theme(id)


func _apply_theme(id: String) -> void:
	notice.text = ""
	theme_choice.clear()
	for pack in packs: theme_choice.add_item(pack.name)
	original = {}
	for pack in packs:
		if pack.id == id: original = pack.duplicate(true)
	if original.is_empty() and not packs.is_empty(): original = packs[0].duplicate(true)
	draft = original.duplicate(true)
	for index in packs.size():
		if packs[index].id == draft.id: theme_choice.select(index)
	selected = {}; invalid_label = false; _populate(); _inspect(); _changed()


func _source(slot: Dictionary) -> String:
	var relative: String = draft.assets.get(slot.id, slot.path)
	var external := RuntimeAssets.root_folder().path_join(relative)
	return external if FileAccess.file_exists(external) else "res://" + relative


func _populate() -> void:
	thumbnails.clear()
	tile_pending.clear()
	tile_buttons.clear()
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	if manager == null or draft.is_empty(): return
	var slots: Array = manager.slots.filter(func(slot: Dictionary) -> bool:
		return (group_filter == "All groups" or slot.group == group_filter) and (search.text.is_empty() or (str(slot.label) + " " + str(slot.group) + " " + manager.display_name(slot.id, slot.label, draft)).to_lower().contains(search.text.to_lower()))
	)
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := str(a.label).to_lower(); var right := str(b.label).to_lower()
		if sort_choice.selected == 2 and a.group != b.group: return str(a.group) < str(b.group)
		return left.naturalnocasecmp_to(right) > 0 if sort_choice.selected == 1 else left.naturalnocasecmp_to(right) < 0
	)
	browse_count.text = "%d / %d" % [slots.size(), manager.slots.size()]
	tile_pending = slots
	if slots.is_empty(): grid.add_child(EditorStyle.label("No assets match these filters."))
	_mark_selection()


func _append_tile(slot: Dictionary) -> void:
	var pick := _button("", func() -> void: selected = slot; _inspect(); _mark_selection())
	pick.accessibility_name = str(slot.label)
	pick.custom_minimum_size = Vector2(150, 172)
	pick.toggle_mode = true
	pick.add_theme_stylebox_override("normal", EditorStyle.box(Color("22354a"), 10))
	pick.add_theme_stylebox_override("hover", EditorStyle.box(Color("2b4560"), 10))
	pick.add_theme_stylebox_override("pressed", EditorStyle.box(Color("315775"), 10))
	grid.add_child(pick)
	tile_buttons[slot.id] = pick
	var inset := MarginContainer.new(); inset.mouse_filter = Control.MOUSE_FILTER_IGNORE; pick.add_child(inset); inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: inset.add_theme_constant_override("margin_" + side, 10)
	var column := VBoxContainer.new(); column.mouse_filter = Control.MOUSE_FILTER_IGNORE; column.add_theme_constant_override("separation", 4); inset.add_child(column)
	var art := Control.new(); art.mouse_filter = Control.MOUSE_FILTER_IGNORE; art.custom_minimum_size.y = 72; art.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_child(art)
	if slot.kind == "audio":
		var sound := EditorStyle.label("AUDIO", 18, EditorStyle.ACCENT); sound.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; art.add_child(sound); sound.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	elif AssetStore.kind(_source(slot)) == "image":
		thumbnails.append({"slot": slot, "target": art})
	else:
		var video_label := EditorStyle.label("VIDEO", 18, EditorStyle.ACCENT); video_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; art.add_child(video_label); video_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var name_label := EditorStyle.label(manager.display_name(slot.id, slot.label, draft), 15, Color.WHITE); name_label.max_lines_visible = 2; name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; column.add_child(name_label)
	column.add_child(EditorStyle.label(str(slot.group), 12))
	var inherited: bool = draft.id != "default" and not draft.assets.has(slot.id) and not draft.labels.has(slot.id)
	column.add_child(EditorStyle.label("Default" if draft.id == "default" or inherited else "Custom", 11, EditorStyle.ACCENT))
	pick.set_pressed_no_signal(slot.id == selected.get("id", ""))


func _mark_selection() -> void:
	for id in tile_buttons:
		tile_buttons[id].set_pressed_no_signal(id == selected.get("id", ""))


func _inspect() -> void:
	suspend_previews()
	preview_card = null
	for child in inspector.get_children():
		inspector.remove_child(child)
		child.queue_free()
	if selected.is_empty():
		inspector.add_child(EditorStyle.label("Select an asset", 22, Color.WHITE))
		inspector.add_child(EditorStyle.label("Choose artwork or audio in the browser to preview it and edit its skin."))
		return
	var heading := Label.new(); heading.text = str(selected.label); heading.add_theme_font_size_override("font_size", 22); heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; inspector.add_child(heading)
	inspector.add_child(EditorStyle.label(str(selected.path), 12))
	inspector.add_child(EditorStyle.label("Skin", 13, EditorStyle.ACCENT))
	inspector.add_child(EditorStyle.label("Skins: %s" % draft.name, 16, Color.WHITE))
	var source := _source(selected)
	var kind := AssetStore.kind(source)
	if kind == "image":
		if selected.has("preview"):
			preview_card = GameCard.new(); preview_card.card = selected.preview.duplicate(true); preview_card.card.display_name = manager.display_name(selected.id, selected.label, draft); preview_card.texture = GameCard.artwork(source); preview_card.accent = Color(selected.preview.color); preview_card.custom_minimum_size = Vector2(160,235); preview_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; inspector.add_child(preview_card)
		else:
			var image := TextureRect.new(); image.texture = RuntimeAssets.texture(source); image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.custom_minimum_size.y = 200; inspector.add_child(image)
	elif kind == "audio":
		preview_audio.stream = RuntimeAssets.audio(source); inspector.add_child(_button("Play audio", func() -> void: preview_audio.play()))
	elif kind == "video":
		var holder := Control.new(); holder.custom_minimum_size.y = 200; inspector.add_child(holder)
		preview_video = preload("res://scripts/game_background.gd").new(); preview_video.source_stem = source.get_basename(); preview_video.reduced_motion = reduced_motion; holder.add_child(preview_video); preview_video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); preview_video.set_active(true)
	if selected.has("display_name"):
		var label := Label.new(); label.text = "Display name"; inspector.add_child(label)
		var name := LineEdit.new(); name.max_length = 80; name.text = manager.display_name(selected.id, selected.display_name, draft); name.editable = draft.id != "default"; inspector.add_child(name)
		name.text_changed.connect(func(value: String) -> void:
			invalid_label = value.strip_edges().is_empty()
			if not value.strip_edges().is_empty(): draft.labels[selected.id] = value.strip_edges()
			if is_instance_valid(preview_card): preview_card.card.display_name = value; preview_card.queue_redraw()
			_changed())
	if selected.has("preview"):
		var rules := Label.new(); rules.text = ("$%d" if selected.preview.get("currency", "") == "USD" else "%dM") % int(selected.preview.value) + " · " + str(selected.preview.detail); rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; inspector.add_child(rules)
	var replace := _button("Replace artwork / sound", _choose); replace.disabled = draft.id == "default"; inspector.add_child(replace)
	var reset := _button("Use Default for this slot", func() -> void: draft.assets.erase(selected.id); draft.labels.erase(selected.id); _inspect(); _populate(); _changed()); reset.disabled = draft.id == "default"; inspector.add_child(reset)
	inspector.add_child(_button("Preview artwork / phone" if manager.preview_kind == "assets" else "Preview table / phone", _preview))
	if manager.preview_kind != "assets": inspector.add_child(_button("Preview all cards", _gallery))
	var help := Label.new(); help.text = "Skins change artwork and sounds. Game rules stay fixed."; help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; inspector.add_child(help)


func _preview() -> void:
	var dialog := AcceptDialog.new(); dialog.title = "Theme preview · " + str(draft.name)
	var tabs := TabContainer.new(); tabs.custom_minimum_size = Vector2(260,340); dialog.add_child(tabs)
	for mode in [false,true]:
		var sample := GameThemePreview.new(); sample.name = "Phone" if mode else "Table"; sample.configure(manager,draft,mode,reduced_motion,manager.presentation); tabs.add_child(sample)
	add_child(dialog); dialog.popup_centered(Vector2i(mini(740,int(size.x)-32),mini(480,int(size.y)-32))); dialog.confirmed.connect(dialog.queue_free)


func _gallery() -> void:
	var dialog := AcceptDialog.new(); dialog.title = "Theme preview · " + str(draft.name)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(260, 330); dialog.add_child(scroll)
	var row := HFlowContainer.new(); row.custom_minimum_size.x = 260; scroll.add_child(row)
	for slot in manager.slots:
		if not slot.has("preview"): continue
		var face := GameCard.new(); face.card = slot.preview.duplicate(true); face.card.display_name = manager.display_name(slot.id, slot.label, draft); face.texture = GameCard.artwork(_source(slot)); face.accent = Color(slot.preview.color); face.custom_minimum_size = Vector2(120, 180); row.add_child(face)
	add_child(dialog); dialog.popup_centered(Vector2i(mini(740, int(size.x) - 32), mini(480, int(size.y) - 32))); dialog.confirmed.connect(dialog.queue_free)


func _choose() -> void:
	var allowed: Array = BackgroundMedia.IMAGE_EXTENSIONS + BackgroundMedia.VIDEO_EXTENSIONS if selected.kind == "background" else RuntimeAssets.AUDIO_EXTENSIONS if selected.kind == "audio" else BackgroundMedia.IMAGE_EXTENSIONS
	chooser.filters = PackedStringArray([",".join(allowed.map(func(extension: String) -> String: return "*." + extension)) + ";Supported media"]); chooser.popup_centered_ratio(0.8)


func _replace(path: String) -> void:
	var result := manager.stage_media(draft, selected.id, path)
	notice.text = "Preview prepared. Save to commit this theme." if result.ok else result.error
	if result.ok: _inspect(); _populate(); _changed()


func _changed() -> void:
	if manager == null or draft.is_empty():
		for button in [save_button, discard_button, use_button, duplicate_button, restore_button]: button.disabled = true
		notice.text = "No valid skins are available for this game."
		return
	save_button.disabled = invalid_label or draft == original or draft.get("id", "default") == "default"
	discard_button.disabled = draft == original
	restore_button.disabled = draft.get("id") == "default"
	var accepted: Dictionary = {}
	var accepted_id := str(settings_store.load_settings(manager.game_id, {"theme": "default"}).theme)
	for pack in packs:
		if pack.id == accepted_id: accepted = pack
	if accepted.is_empty() and not packs.is_empty(): accepted = packs[0]
	use_button.disabled = draft != original or draft.is_empty() or draft.get("id") == accepted.get("id")
	skin_status.text = "Selected skin: %s · Applies next game" % accepted.get("name", "Default")
	if invalid_label: notice.text = "A display name is required."
	if draft.get("id") == "default": notice.text = "The built-in skin is protected. Duplicate it to create your own skin."


func _use_skin() -> void:
	if use_button.disabled or manager.load_pack(str(original.get("id", ""))).is_empty(): return
	if settings_store.save_settings(manager.game_id, {"theme": original.id}):
		_changed(); notice.text = "%s selected for the next launch." % original.name
	else: notice.text = settings_store.last_error


func _duplicate() -> void:
	request_leave(func() -> void:
		var dialog := ConfirmationDialog.new(); dialog.title = "Duplicate theme"; dialog.dialog_text = "Name the new theme"
		var name := LineEdit.new(); name.placeholder_text = "Philadelphia"; name.max_length = 64; dialog.add_child(name)
		add_child(dialog); dialog.popup_centered(Vector2i(360, 160))
		dialog.confirmed.connect(func() -> void:
			var result := manager.duplicate_pack(str(draft.id), name.text)
			if result.ok: _load_theme(result.pack.id)
			else: notice.text = result.error
			dialog.queue_free())
	)


func _confirm_save(after := Callable()) -> void:
	if save_button.disabled: return
	var dialog := ConfirmationDialog.new(); dialog.title = "Save theme?"; dialog.dialog_text = "Save names and media for %s? The previous manifest is preserved in Backups. The active game keeps its current theme until a new game." % draft.name
	add_child(dialog); dialog.popup_centered(Vector2i(mini(560, int(size.x) - 24), 240))
	dialog.confirmed.connect(func() -> void:
		var result := manager.save_pack(draft)
		if result.ok:
			_load_theme(draft.id); notice.text = "Theme saved."
			if after.is_valid(): after.call()
		else: notice.text = result.error
		dialog.queue_free())


func request_leave(action: Callable) -> void:
	if draft == original: action.call(); return
	var dialog := ConfirmationDialog.new(); dialog.title = "Unsaved theme"; dialog.dialog_text = "Save the theme before leaving?"; dialog.ok_button_text = "Save…"; dialog.cancel_button_text = "Cancel"
	var discard := dialog.add_button("Discard", false, "discard")
	discard.pressed.connect(func() -> void: _apply_theme(str(original.id)); dialog.queue_free(); action.call())
	dialog.confirmed.connect(func() -> void: dialog.queue_free(); _confirm_save(action))
	dialog.canceled.connect(func() -> void:
		game_choice.select(games.find(manager.game_id))
		for index in packs.size():
			if packs[index].id == draft.id: theme_choice.select(index)
		dialog.queue_free()
	)
	add_child(dialog); dialog.popup_centered(Vector2i(mini(500, int(size.x) - 24), 210))


func _previous() -> void:
	if draft.get("id") == "default": return
	var directory := RuntimeAssets.root_folder().path_join("Backups")
	if not DirAccess.dir_exists_absolute(directory): return
	var folders := DirAccess.get_directories_at(directory); folders.sort(); folders.reverse()
	for folder in folders:
		var path := directory.path_join(folder).path_join("Games/%s/themes/%s/theme.json" % [manager.game_id, draft.id])
		if FileAccess.file_exists(path):
			var pack: Variant = ThemePacks._read(path)
			if pack is Dictionary: draft = pack; _inspect(); _populate(); _changed(); notice.text = "Previous theme staged. Save to restore it."
			return


func _exit_tree() -> void:
	_cancel_loading()
	suspend_previews()


func suspend_previews() -> void:
	preview_audio.stop()
	if is_instance_valid(preview_video):
		preview_video.set_active(false)
		preview_video.queue_free()
		preview_video = null
