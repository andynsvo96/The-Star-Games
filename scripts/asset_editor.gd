extends Control

signal exit_requested
signal asset_saved(path: String)
signal quit_requested

const EditorStyle = preload("res://scripts/asset_editor_style.gd")

class AssetTree extends Tree:
	func _get_tooltip(_at_position: Vector2) -> String:
		return ""

var store := AssetStore.new()
var game_settings_store := GameSettingsStore.new()
var reduced_motion := false
var selected: Dictionary = {}
var pending: Dictionary = {}
var worker: Thread
var audio_preview_source := ""
var audio_preview_target := ""
var after_save: Callable
var tree := AssetTree.new()
var search := LineEdit.new()
var heading := Label.new()
var details := Label.new()
var notice := Label.new()
var preview := PanelContainer.new()
var picture := TextureRect.new()
var audio := AudioStreamPlayer.new()
var video: Control
var replace_button: Button
var save_button: Button
var discard_button: Button
var restore_button: Button
var play_button: Button
var chooser: FileDialog
var folders: Dictionary = {}
var theme_editor: Control
var content: MarginContainer
var skins := Label.new()
var skin_section: PanelContainer
var skin_button: Button
var themes_button: Button
var categories: Array[Dictionary] = []
var category_cache: Dictionary = {}
var dirty_categories: Dictionary = {}
var collapsed_folders: Dictionary = {}
var scan_queue: Array[String] = []
var scanner: Thread
var loading_category := ""
var tree_pending: Array[Dictionary] = []
var rebuilding_tree := false
var populate_scheduled := false
var expand_all_sections := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	content = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var body := VBoxContainer.new()
	margin.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	header.add_child(_button("← Return", request_exit))
	var title := Label.new()
	title.text = "ASSET EDITOR"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(title)
	themes_button = _button("Themes", _open_themes)
	header.add_child(themes_button)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.resized.connect(func() -> void:
		split.split_offset = int(clampf(split.size.x * 0.27, 130, 340) - split.size.x * 0.5)
		preview.custom_minimum_size.y = clampf(size.y * 0.42, 140, 350)
	)
	body.add_child(split)
	var browser := EditorStyle.panel(EditorStyle.BROWSER, 10)
	browser.custom_minimum_size.x = 130
	browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(browser)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	browser.add_child(left)
	left.add_child(EditorStyle.label("ASSET BROWSER", 12, EditorStyle.ACCENT))
	search.placeholder_text = "Search loaded assets"
	search.text_changed.connect(func(_value: String) -> void: _populate())
	left.add_child(search)
	var sections := HFlowContainer.new()
	left.add_child(sections)
	sections.add_child(_button("Collapse All", func() -> void: _set_sections_collapsed(true)))
	sections.add_child(_button("Expand All", func() -> void: _set_sections_collapsed(false)))
	var browser_help := EditorStyle.label("Expand a category to load its assets.", 12, EditorStyle.ACCENT)
	browser_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(browser_help)
	tree.hide_root = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.add_theme_stylebox_override("panel", EditorStyle.box(Color("111c2a"), 4))
	tree.item_selected.connect(_select_item)
	tree.item_collapsed.connect(_section_toggled)
	left.add_child(tree)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 140
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(right)
	heading.text = "Select an asset"
	heading.add_theme_font_size_override("font_size", 22)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(heading)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(details)
	skin_section = EditorStyle.panel(EditorStyle.TOOLBAR, 12)
	right.add_child(skin_section)
	var skin_body := VBoxContainer.new()
	skin_body.add_theme_constant_override("separation", 6)
	skin_section.add_child(skin_body)
	skin_body.add_child(EditorStyle.label("Skin", 13, EditorStyle.ACCENT))
	skins.text = "Skins: Default"
	skins.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skin_body.add_child(skins)
	skin_button = _button("Edit skins in Themes", _edit_skin)
	skin_body.add_child(skin_button)
	preview.custom_minimum_size.y = 260
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(preview)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.add_child(picture)
	play_button = _button("Play audio", _toggle_audio)
	play_button.hide()
	right.add_child(play_button)
	var actions := HFlowContainer.new()
	right.add_child(actions)
	replace_button = _button("Replace", _choose)
	restore_button = _button("Restore Previous", _restore)
	save_button = _button("Save", _confirm_save)
	discard_button = _button("Discard", _discard)
	for button in [replace_button, restore_button, save_button, discard_button]:
		actions.add_child(button)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(notice)
	var help := Label.new()
	help.text = "Save asks for confirmation. Previous versions are kept in Backups at the Star Games root."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(help)
	add_child(audio)
	audio.bus = "Effects"
	audio.finished.connect(func() -> void: play_button.text = "Play audio")
	get_node("/root/BackgroundPreparer").prepared.connect(func(path: String, success: bool) -> void:
		if path == audio_preview_source and not success:
			audio_preview_target = ""
			_notice("Could not prepare this music preview. Install FFmpeg or choose a WAV, OGG, or MP3 replacement.", true)
	)
	categories = store.categories()
	# Resolve the small replacement index before background category scans use it.
	RuntimeAssets.replacements()
	_populate()
	_update_actions()


func _populate() -> void:
	populate_scheduled = false
	rebuilding_tree = true
	for key: String in folders:
		collapsed_folders[key] = folders[key].collapsed
	tree_pending.clear()
	tree.clear()
	folders.clear()
	var root_item := tree.create_item()
	var query := search.text.strip_edges().to_lower()
	for category in categories:
		var id := str(category.id)
		var folder := tree.create_item(root_item)
		folder.set_text(0, str(category.label))
		folder.set_metadata(0, id)
		folder.set_selectable(0, false)
		folder.collapsed = bool(collapsed_folders.get(id, true))
		folders[id] = folder
		var matches: Array[Dictionary] = []
		if category_cache.has(id) and not folder.collapsed:
			for entry: Dictionary in category_cache[id]:
				if query.is_empty() or str(entry.path).to_lower().contains(query):
					matches.append(entry)
		if not matches.is_empty():
			tree_pending.append_array(matches)
		else:
			var hint := tree.create_item(folder)
			hint.set_selectable(0, false)
			if not category_cache.has(id):
				hint.set_text(0, "Loading assets…" if id == loading_category or scan_queue.has(id) else "Expand to load assets")
			else:
				hint.set_text(0, "%d assets" % category_cache[id].size() if folder.collapsed else "No matching assets" if not query.is_empty() else "No assets found")
	rebuilding_tree = false


func _append_entry(entry: Dictionary) -> void:
	var category := str(entry.category)
	var parent: TreeItem = folders[category]
	var parts := str(entry.path).split("/")
	var key := category
	var start := 2 if str(entry.path).begins_with(category + "/") else 0
	for index in range(start, parts.size() - 1):
		key += "/" + parts[index]
		if not folders.has(key):
			var folder := tree.create_item(parent)
			folder.set_text(0, parts[index])
			folder.set_metadata(0, key)
			folder.set_selectable(0, false)
			folder.collapsed = bool(collapsed_folders.get(key, not expand_all_sections))
			folders[key] = folder
		parent = folders[key]
	var item := tree.create_item(parent)
	item.set_text(0, parts[-1])
	item.set_metadata(0, entry)
	if not selected.is_empty() and selected.path == entry.path and selected.get("category", category) == category:
		item.select(0)


func _schedule_populate() -> void:
	if not populate_scheduled:
		populate_scheduled = true
		_populate.call_deferred()


func _section_toggled(item: TreeItem) -> void:
	if rebuilding_tree or not item.get_metadata(0) is String:
		return
	var id := str(item.get_metadata(0))
	collapsed_folders[id] = item.collapsed
	if not categories.any(func(category: Dictionary) -> bool: return category.id == id):
		return
	if item.collapsed:
		scan_queue.erase(id)
	else:
		_request_category(id)
	_schedule_populate()


func _request_category(id: String) -> void:
	if id == loading_category or scan_queue.has(id):
		return
	if dirty_categories.has(id):
		dirty_categories.erase(id)
		category_cache.erase(id)
		store.entries = store.entries.filter(func(entry: Dictionary) -> bool: return entry.get("category", "") != id)
	if category_cache.has(id): return
	scan_queue.append(id)
	_start_category_scan()


func _start_category_scan() -> void:
	if scanner != null or scan_queue.is_empty():
		return
	loading_category = scan_queue.pop_front()
	var category := loading_category
	var definitions := store.definitions_root
	scanner = Thread.new()
	var error := scanner.start(func() -> Array[Dictionary]:
		var category_store := AssetStore.new()
		category_store.definitions_root = definitions
		return category_store.scan_category(category)
	)
	if error != OK:
		scanner = null
		loading_category = ""
		_notice("Could not load assets. Collapse and reopen the category to retry.", true)


func _set_sections_collapsed(collapsed: bool) -> void:
	expand_all_sections = not collapsed
	rebuilding_tree = true
	for folder: TreeItem in folders.values():
		folder.collapsed = collapsed
	for key: String in collapsed_folders:
		collapsed_folders[key] = collapsed
	for category in categories:
		collapsed_folders[category.id] = collapsed
		if not collapsed: _request_category(str(category.id))
	if collapsed: scan_queue.clear()
	rebuilding_tree = false
	_schedule_populate()


func _select_item() -> void:
	var item := tree.get_selected()
	if item == null or not item.get_metadata(0) is Dictionary:
		return
	var entry: Dictionary = item.get_metadata(0)
	if not selected.is_empty() and entry.path == selected.path and entry.get("category", "") == selected.get("category", ""):
		return
	var change := func() -> void:
		selected = entry
		_discard()
	if worker != null:
		_populate()
		return
	if not pending.is_empty():
		_unsaved(change)
	else:
		change.call()


func _show_preview(path: String) -> void:
	audio_preview_source = ""
	audio_preview_target = ""
	audio.stop()
	audio.stream = null
	play_button.hide()
	picture.texture = null
	if video != null:
		video.set_active(false)
		preview.remove_child(video)
		video.queue_free()
		video = null
	picture.show()
	var media_kind := str(selected.get("kind", AssetStore.kind(path))) if pending.is_empty() else AssetStore.kind(path)
	if media_kind == "image":
		picture.texture = RuntimeAssets.texture(path)
	elif media_kind == "audio":
		audio.stream = RuntimeAssets.audio(path)
		play_button.text = "Play audio"
		play_button.visible = audio.stream != null
		if audio.stream == null and path.get_extension().to_lower() in RuntimeAssets.CONVERT_AUDIO_EXTENSIONS:
			audio_preview_source = path
			_notice("Preparing audio preview…")
			var prepared := AssetStore.prepare_audio_preview(path)
			if prepared.ok:
				audio_preview_target = str(prepared.preview)
			else:
				_notice(str(prepared.error), true)
	elif media_kind == "video":
		picture.hide()
		video = preload("res://scripts/game_background.gd").new()
		video.source_stem = path.get_basename()
		video.reduced_motion = reduced_motion
		preview.add_child(video)
		video.set_active(true)


func _choose() -> void:
	# FileDialog's filesystem setup can query slow Windows drives. Do this only
	# when a replacement is requested, never while opening the asset browser.
	if chooser == null:
		chooser = FileDialog.new()
		chooser.title = "Choose replacement media"
		chooser.use_native_dialog = true
		chooser.access = FileDialog.ACCESS_FILESYSTEM
		chooser.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		chooser.file_selected.connect(_stage)
		add_child(chooser)
	var allowed: Array = BackgroundMedia.IMAGE_EXTENSIONS
	var media_kind := str(selected.get("kind", AssetStore.kind(RuntimeAssets.source("res://" + str(selected.path)))))
	if selected.background:
		allowed = BackgroundMedia.IMAGE_EXTENSIONS + BackgroundMedia.VIDEO_EXTENSIONS
	elif media_kind == "audio":
		allowed = RuntimeAssets.AUDIO_EXTENSIONS
	var patterns: Array[String] = []
	for extension: String in allowed:
		patterns.append("*." + extension)
	chooser.filters = PackedStringArray([",".join(patterns) + ";Supported media"])
	chooser.popup_centered_ratio(0.8)


func _stage(path: String) -> void:
	if worker != null or selected.is_empty():
		return
	_notice("Checking file support and preparing preview…")
	var entry := selected.duplicate()
	worker = Thread.new()
	worker.start(func() -> Dictionary: return store.stage(entry, path))
	_update_actions()


func _process(_delta: float) -> void:
	if not audio_preview_target.is_empty() and FileAccess.file_exists(audio_preview_target):
		audio.stream = RuntimeAssets.audio(audio_preview_target)
		play_button.visible = audio.stream != null
		audio_preview_target = ""
		_notice("")
	if worker != null and not worker.is_alive():
		var result: Dictionary = worker.wait_to_finish()
		worker = null
		if result.ok:
			_clear_pending()
			pending = result
			_show_preview(str(pending.staged))
			details.text = "%s\nReplacement: %s · %s\n%s" % [selected.path, pending.name, str(pending.kind).capitalize(), pending.details]
			_notice("Supported replacement. Save will ask for confirmation." + (" MP4/H.264 or WebM is recommended for phone backgrounds; Android hosts need OGV." if pending.kind == "video" else ""))
		else:
			_notice(str(result.error), true)
		_update_actions()
	if scanner != null and not scanner.is_alive() and worker == null:
		var loaded: Array[Dictionary] = scanner.wait_to_finish()
		scanner = null
		var category := loading_category
		loading_category = ""
		if dirty_categories.has(category):
			if not bool(collapsed_folders.get(category, true)): _request_category(category)
		else:
			category_cache[category] = loaded
			store.entries.append_array(loaded)
			for entry in loaded:
				if selected.get("path", "") == entry.path and selected.get("category", category) == category:
					selected = entry
		_start_category_scan()
		_schedule_populate()
	if not is_visible_in_tree() or populate_scheduled:
		return
	var deadline := Time.get_ticks_usec() + 3000
	rebuilding_tree = true
	for index in mini(64, tree_pending.size()):
		_append_entry(tree_pending.pop_front())
		if Time.get_ticks_usec() >= deadline: break
	rebuilding_tree = false


func _confirm_save() -> void:
	if pending.is_empty() or worker != null:
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Save asset replacement?"
	dialog.dialog_autowrap = true
	dialog.dialog_text = "Replace %s with %s?\n\nThe actual media file will be saved. Its previous version will be kept in Backups. Reopen the game or refresh its controllers to see the change." % [selected.path, pending.name]
	dialog.ok_button_text = "Save replacement"
	dialog.confirmed.connect(func() -> void:
		dialog.hide()
		dialog.queue_free()
		_save()
	)
	dialog.canceled.connect(func() -> void:
		after_save = Callable()
		dialog.hide()
		dialog.queue_free()
		_populate()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(mini(600, int(size.x) - 24), 260))


func _save() -> void:
	var result := store.save(pending)
	if not result.ok:
		after_save = Callable()
		_notice(str(result.error), true)
		return
	var path := str(selected.path)
	_clear_pending()
	# Replacement files are hidden from the catalog; only this source changed.
	selected.source = RuntimeAssets.source("res://" + path)
	selected.kind = "audio" if path.begins_with("asset/lobby_songs/") or path.begins_with("asset/music/") else AssetStore.kind(str(selected.source))
	_discard()
	_populate()
	_notice("Saved. Previous version: %s" % str(result.backup))
	asset_saved.emit(path)
	if after_save.is_valid():
		var next := after_save
		after_save = Callable()
		next.call()


func _clear_pending() -> void:
	if pending.has("staged"):
		DirAccess.remove_absolute(str(pending.staged))
	pending.clear()


func _discard() -> void:
	_clear_pending()
	_notice("")
	if not selected.is_empty():
		heading.text = str(selected.path).get_file()
		var path := RuntimeAssets.source("res://" + str(selected.path))
		details.text = "%s\n%s · %s" % [selected.path, str(selected.get("kind", AssetStore.kind(path))).capitalize(), path.get_extension().to_upper()]
		_show_preview(path)
		skins.text = "Skins: %s" % selected.get("skin", "Default")
	_update_actions()


func _restore() -> void:
	var path := store.previous(str(selected.path))
	if not path.is_empty():
		_stage(path)


func request_exit() -> void:
	_leave(func() -> void: exit_requested.emit())


func request_quit() -> void:
	_leave(func() -> void: quit_requested.emit())


func _leave(action: Callable) -> void:
	if is_instance_valid(theme_editor) and theme_editor.visible:
		theme_editor.request_leave(action)
		return
	if worker != null:
		_notice("Wait for the file check to finish before leaving.")
	elif not pending.is_empty():
		_unsaved(action)
	else:
		action.call()


func _unsaved(action: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Unsaved asset replacement"
	dialog.dialog_autowrap = true
	dialog.dialog_text = "Save your previewed replacement before leaving this asset?"
	dialog.ok_button_text = "Save…"
	dialog.cancel_button_text = "Cancel"
	var discard := dialog.add_button("Discard", false, "discard")
	discard.pressed.connect(func() -> void:
		_clear_pending()
		dialog.hide()
		dialog.queue_free()
		action.call()
	)
	dialog.confirmed.connect(func() -> void:
		dialog.hide()
		dialog.queue_free()
		after_save = action
		_confirm_save()
	)
	dialog.canceled.connect(func() -> void:
		dialog.hide()
		dialog.queue_free()
		_populate()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(mini(540, int(size.x) - 24), 220))


func _update_actions() -> void:
	var busy := worker != null
	var protected := bool(selected.get("protected", false))
	replace_button.disabled = selected.is_empty() or busy or protected
	restore_button.disabled = selected.is_empty() or busy or protected or store.previous(str(selected.get("path", ""))).is_empty()
	skin_section.visible = not selected.is_empty()
	skin_button.visible = selected.has("game_id")
	save_button.disabled = pending.is_empty() or busy
	discard_button.disabled = pending.is_empty() or busy
	tree.mouse_filter = Control.MOUSE_FILTER_IGNORE if busy else Control.MOUSE_FILTER_STOP


func _toggle_audio() -> void:
	if audio.playing:
		audio.stop()
		play_button.text = "Play audio"
	else:
		audio.play()
		play_button.text = "Stop audio"


func _notice(message: String, error := false) -> void:
	notice.text = message
	notice.add_theme_color_override("font_color", Color("ff6961") if error else Color("a1a1aa"))


func _button(caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	return button


func _exit_tree() -> void:
	audio.stop()
	if video != null:
		video.set_active(false)
	if worker != null:
		var result: Dictionary = worker.wait_to_finish()
		if result.has("staged"):
			DirAccess.remove_absolute(str(result.staged))
		worker = null
	if scanner != null:
		scanner.wait_to_finish()
		scanner = null
	_clear_pending()


func _edit_skin() -> void:
	_open_themes(str(selected.get("game_id", "")), str(selected.get("slot_id", "")))


func _close_themes() -> void:
	theme_editor.suspend_previews()
	theme_editor.hide()
	content.show()
	# Themes may add immutable media. Refresh only previously loaded, open games;
	# collapsed games wait until the host chooses to open them again.
	if loading_category.begins_with("Games/"): dirty_categories[loading_category] = true
	for id: String in category_cache.keys():
		if not id.begins_with("Games/"): continue
		dirty_categories[id] = true
		if not bool(collapsed_folders.get(id, true)): _request_category(id)
	_populate()
	_discard()


func _open_themes(game_id := "", slot_id := "") -> void:
	_leave(func() -> void:
		audio.stop()
		if video != null: video.set_active(false)
		content.hide()
		if not is_instance_valid(theme_editor):
			theme_editor = preload("res://scripts/theme_pack_editor.gd").new()
			theme_editor.initial_game_id = game_id
			theme_editor.initial_slot_id = slot_id
			theme_editor.definitions_root = store.definitions_root
			theme_editor.reduced_motion = reduced_motion
			theme_editor.settings_store = game_settings_store
			theme_editor.exit_requested.connect(_close_themes)
			add_child(theme_editor)
		else:
			theme_editor.show()
			theme_editor.open_asset(game_id, slot_id)
	)
