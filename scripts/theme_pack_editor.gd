extends Control

signal exit_requested
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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); background.color = Color("101114"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var body := VBoxContainer.new(); margin.add_child(body)
	var bar := HFlowContainer.new(); body.add_child(bar)
	bar.add_child(_button("Return", func() -> void: request_leave(func() -> void: exit_requested.emit())))
	var title := Label.new(); title.text = "ASSET EDITOR · THEMES"; title.add_theme_font_size_override("font_size", 24); bar.add_child(title)
	for id in DirAccess.get_directories_at("res://Games"):
		if not id.begins_with("_") and FileAccess.file_exists("res://Games/%s/theme-slots.json" % id):
			games.append(id); game_choice.add_item(id.capitalize())
	bar.add_child(game_choice)
	game_choice.item_selected.connect(func(index: int) -> void: request_leave(func() -> void: _load_game(index)))
	var toolbar := HFlowContainer.new(); body.add_child(toolbar)
	toolbar.add_child(theme_choice); theme_choice.item_selected.connect(func(index: int) -> void: request_leave(func() -> void: _load_theme(str(packs[index].id))))
	toolbar.add_child(_button("Duplicate theme", _duplicate))
	toolbar.add_child(_button("Restore Previous", _previous))
	toolbar.add_child(group_choice); group_choice.item_selected.connect(func(index: int) -> void: group_filter = group_choice.get_item_text(index); _populate())
	search.placeholder_text = "Search assets"; search.custom_minimum_size.x = 170; toolbar.add_child(search); search.text_changed.connect(func(_text: String) -> void: _populate())
	var split := SplitContainer.new(); split.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_child(split)
	var scroll := ScrollContainer.new(); scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; split.add_child(scroll)
	grid.columns = 3; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(grid)
	var detail_scroll := ScrollContainer.new(); detail_scroll.custom_minimum_size.x = 250; detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL; detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; split.add_child(detail_scroll)
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL; detail_scroll.add_child(inspector)
	split.resized.connect(func() -> void:
		grid.columns = 1 if size.x < 850 else 3; split.vertical = size.x < 700
		scroll.custom_minimum_size.y = 140 if split.vertical else 0
		detail_scroll.custom_minimum_size.y = 180 if split.vertical else 0
		split.split_offset = 0 if split.vertical else int(size.x * 0.15)
	)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.add_child(notice)
	var footer := HFlowContainer.new(); body.add_child(footer)
	save_button = _button("Save", _confirm_save); footer.add_child(save_button)
	footer.add_child(_button("Discard", func() -> void: _load_theme(str(original.id))))
	chooser.access = FileDialog.ACCESS_FILESYSTEM; chooser.file_mode = FileDialog.FILE_MODE_OPEN_FILE; chooser.use_native_dialog = true; add_child(chooser)
	chooser.file_selected.connect(_replace)
	add_child(preview_audio); preview_audio.bus = "Effects"
	if not games.is_empty(): _load_game(0)
	else: notice.text = "No games provide theme slots yet."


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new(); button.text = text; button.custom_minimum_size.y = 44; button.pressed.connect(callback); return button


func _load_game(index: int) -> void:
	game_choice.select(index); manager = ThemePacks.new(games[index]); group_choice.clear(); group_choice.add_item("All groups")
	var groups: Array = []
	for slot in manager.slots:
		if not groups.has(slot.group): groups.append(slot.group); group_choice.add_item(slot.group)
	group_filter = "All groups"; _load_theme("default")


func _load_theme(id: String) -> void:
	packs = manager.list_packs(); theme_choice.clear()
	for pack in packs: theme_choice.add_item(pack.name + (" · Built in" if pack.id == "default" else ""))
	original = manager.load_pack(id)
	if original.is_empty(): original = manager.load_pack("default")
	draft = original.duplicate(true)
	for index in packs.size():
		if packs[index].id == draft.id: theme_choice.select(index)
	selected = {}; invalid_label = false; _populate(); _inspect(); _changed()


func _source(slot: Dictionary) -> String:
	var relative: String = draft.assets.get(slot.id, slot.path)
	var external := RuntimeAssets.root_folder().path_join(relative)
	return external if FileAccess.file_exists(external) else "res://" + relative


func _populate() -> void:
	for child in grid.get_children(): child.queue_free()
	for slot in manager.slots:
		if group_filter != "All groups" and slot.group != group_filter: continue
		if not search.text.is_empty() and not (str(slot.label) + str(slot.group)).to_lower().contains(search.text.to_lower()): continue
		var column := VBoxContainer.new(); grid.add_child(column)
		var pick := _button(str(slot.label), func() -> void: selected = slot; _inspect())
		column.add_child(pick)
		if slot.kind == "image" and slot.has("preview"):
			var face := GameCard.new(); face.card = slot.preview.duplicate(true); face.card.display_name = manager.display_name(slot.id, slot.label, draft); face.texture = GameCard.artwork(_source(slot)); face.accent = Color(slot.preview.color); face.custom_minimum_size = Vector2(112, 165); face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; column.add_child(face)
		var status := Label.new(); status.text = "Inherited from Default" if draft.id != "default" and not draft.assets.has(slot.id) and not draft.labels.has(slot.id) else str(slot.group); status.add_theme_font_size_override("font_size", 12); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(status)


func _inspect() -> void:
	preview_audio.stop()
	preview_card = null
	if is_instance_valid(preview_video): preview_video.set_active(false); preview_video.queue_free(); preview_video = null
	for child in inspector.get_children(): child.queue_free()
	if selected.is_empty(): return
	var heading := Label.new(); heading.text = str(selected.label); heading.add_theme_font_size_override("font_size", 22); heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; inspector.add_child(heading)
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
	inspector.add_child(_button("Preview table / phone", _preview))
	inspector.add_child(_button("Preview all cards", _gallery))
	var help := Label.new(); help.text = "Names and artwork can change. Values, property groups and rules stay fixed."; help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; inspector.add_child(help)


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
	save_button.disabled = invalid_label or draft == original or draft.get("id", "default") == "default"
	if invalid_label: notice.text = "A display name is required."
	if draft.get("id") == "default": notice.text = "Default is protected. Duplicate it to create a theme such as Philadelphia."


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
	discard.pressed.connect(func() -> void: draft = original.duplicate(true); dialog.queue_free(); action.call())
	dialog.confirmed.connect(func() -> void: dialog.queue_free(); _confirm_save(action))
	dialog.canceled.connect(func() -> void:
		game_choice.select(games.find(manager.game_id))
		for index in packs.size():
			if packs[index].id == draft.id: theme_choice.select(index)
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
	preview_audio.stop()
	if is_instance_valid(preview_video): preview_video.set_active(false)
