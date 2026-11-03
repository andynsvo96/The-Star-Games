extends SceneTree

# Public acceptance suite: synthetic media only, with optional rendered captures.
var checks := 0
var failures := 0
var fixture := "res://.test_data/asset-editor-ui-%d" % Time.get_ticks_usec()
var app: Control


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func write(path: String, contents: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()


func capture(name: String) -> void:
	for frame in 12: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(fixture.path_join(name + ".png"))


func inside(control: Control) -> bool:
	return Rect2(Vector2.ZERO, Vector2(root.content_scale_size)).grow(1).encloses(control.get_global_rect())


func settle_browser(editor: Control) -> void:
	for frame in 1200:
		await process_frame
		if editor.scanner == null and editor.scan_queue.is_empty() and editor.tree_pending.is_empty() and not editor.populate_scheduled:
			return
	check(false, "Category scanning and progressive rows finish")


func listed_assets(item: TreeItem) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if item.get_metadata(0) is Dictionary: result.append(item.get_metadata(0))
	for child in item.get_children(): result.append_array(listed_assets(child))
	return result


func _run() -> void:
	var definitions := fixture.path_join("definitions")
	var runtime := fixture.path_join("runtime")
	var module := definitions.path_join("editor-fixture")
	var art := '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96"><rect x="8" y="8" width="80" height="80" rx="20" fill="#82c4ff"/><circle cx="48" cy="48" r="20" fill="#315775"/></svg>'
	var slots: Array = []
	for index in 480:
		var path := "Games/editor-fixture/art/piece-%d.svg" % index
		write(runtime.path_join(path), art)
		slots.append({"id":"piece-%d" % index, "label":"Piece %d" % index, "group":"Pieces" if index % 2 == 0 else "Artwork", "kind":"image", "path":path})
	write(module.path_join("theme-slots.json"), JSON.stringify({"schema_version":1,"preview_kind":"assets","slots":slots}))
	write(module.path_join("themes/default/theme.json"), JSON.stringify({"schema_version":1,"id":"default","name":"Default","assets":{},"labels":{}}))
	write(runtime.path_join("asset/test/launcher.svg"), art)
	write(runtime.path_join("asset/editor-fixture/original.svg"), art)
	write(runtime.path_join("Games/editor-fixture/thumbnail.svg"), art)
	write(runtime.path_join("Games/editor-fixture/art/room.svg"), art)
	write(runtime.path_join("Games/editor-fixture/art/room.webp"), "media discovery fixture")
	write(runtime.path_join("Games/editor-fixture/game.json"), JSON.stringify({"title":"Editor fixture", "background":"art/room"}))
	write(runtime.path_join("Games/other-fixture/game.json"), JSON.stringify({"title":"Other fixture"}))
	write(runtime.path_join("Games/other-fixture/art/other.svg"), art)
	write(definitions.path_join("other-fixture/theme-slots.json"), JSON.stringify({"schema_version":1,"asset_sources":["editor-fixture"],"slots":[{"id":"shared","label":"Shared piece","group":"Artwork","kind":"image","path":slots[0].path}]}))
	write(runtime.path_join("Games/empty-fixture/game.json"), JSON.stringify({"title":"Other fixture"}))
	RuntimeAssets.root_override = ProjectSettings.globalize_path(runtime); RuntimeAssets.refresh()
	var store := AssetStore.new(); store.definitions_root = definitions
	var entries := store.scan()
	check(entries.filter(func(entry: Dictionary) -> bool: return str(entry.path).begins_with("Games/editor-fixture/")).size() == 483, "Every themed asset, thumbnail and same-stem background source is present")
	check(not entries.any(func(entry: Dictionary) -> bool: return entry.kind == "themes" or str(entry.path).ends_with("Theme packs")), "No synthetic Theme packs rows")
	check(entries.all(func(entry: Dictionary) -> bool: return entry.skin == "Default"), "Every existing source is assigned to Default")
	var piece: Dictionary = entries.filter(func(entry: Dictionary) -> bool: return entry.path == slots[0].path)[0]
	check(piece.protected and piece.slot_id == "piece-0", "Visible skin sources retain their protected slot identity")
	check(not store.stage({"path":piece.path,"background":false}, runtime.path_join("asset/test/launcher.svg")).ok, "Omitting protection metadata cannot overwrite Default")
	app = load("res://Main.tscn").instantiate()
	app.profile_store = ProfileStore.new(fixture.path_join("profiles.json"))
	app.game_settings_store = GameSettingsStore.new(fixture.path_join("settings"))
	root.add_child(app)
	app.profile_store.data.settings.fullscreen = false
	app.profile_store.data.settings.reduced_motion = true
	root.min_size = Vector2i.ONE
	root.content_scale_size = Vector2i(1280,720); root.size = Vector2i(1280,720)
	app._show_settings("title")
	var opened := Time.get_ticks_msec()
	app._show_asset_editor()
	print("Open Asset Editor dispatch ms: ", Time.get_ticks_msec() - opened)
	var editor: Control = app.asset_editor
	check(editor.store.entries.is_empty() and editor.category_cache.is_empty() and editor.scanner == null, "Opening the editor scans no asset libraries")
	check(editor.chooser == null, "Opening the browser does not initialize the filesystem picker")
	check(editor.folders.values().all(func(item: TreeItem) -> bool: return item.collapsed), "Every category starts collapsed")
	editor.store = AssetStore.new(); editor.store.definitions_root = definitions
	editor.categories = editor.store.categories(); editor._populate()
	check(editor.categories.size() == 4 and editor.store.entries.is_empty(), "Discovery lists Launcher and detected games without loading media")
	check(editor.categories.filter(func(category: Dictionary) -> bool: return category.id in ["Games/other-fixture", "Games/empty-fixture"]).all(func(category: Dictionary) -> bool: return str(category.label).contains(str(category.id).trim_prefix("Games/"))), "Games with duplicate titles remain distinguishable")
	check(editor.tree.get_root().get_child_count() == 4 and listed_assets(editor.tree.get_root()).is_empty(), "Initial tree contains only collapsed categories and loading hints")
	await capture("asset-categories")
	editor.folders["Games/editor-fixture"].collapsed = false
	check(editor.scanner != null and editor.category_cache.is_empty(), "Expanding a game dispatches its scan in a worker")
	await settle_browser(editor)
	check(editor.category_cache.keys() == ["Games/editor-fixture"] and editor.store.entries.size() == 484, "Only the expanded game's media is scanned")
	check(editor.store.entries.any(func(entry: Dictionary) -> bool: return entry.path == "asset/editor-fixture/original.svg"), "Legacy source assets load with their detected game")
	check(editor.folders["Games/editor-fixture/art"].collapsed and editor.folders["Games/other-fixture"].collapsed, "Nested folders and other games remain collapsed")
	check(editor.category_cache["Games/editor-fixture"].filter(func(entry: Dictionary) -> bool: return entry.path.begins_with("Games/editor-fixture/art/room.")).all(func(entry: Dictionary) -> bool: return entry.background), "Category scans preserve same-stem background sources")
	editor._populate()
	check(editor.tree_pending.size() == 484 and listed_assets(editor.tree.get_root()).is_empty(), "Expanded catalogs add their rows progressively")
	await settle_browser(editor)
	editor.folders["Games/editor-fixture"].collapsed = true
	await process_frame
	await process_frame
	editor.folders["Games/editor-fixture"].collapsed = false
	check(editor.scanner == null and editor.scan_queue.is_empty(), "Reopening a loaded category reuses its cached inventory")
	editor.search.text = "piece-479"
	await settle_browser(editor)
	var matches := listed_assets(editor.tree.get_root())
	check(matches.size() == 1 and matches[0].path.ends_with("piece-479.svg") and editor.category_cache.size() == 1, "Search filters loaded assets without opening another library")
	editor.search.clear()
	await settle_browser(editor)
	editor.folders["Games/editor-fixture/art"].collapsed = false
	editor.selected = editor.category_cache["Games/editor-fixture"].filter(func(entry: Dictionary) -> bool: return entry.path == piece.path)[0]; editor._discard()
	await capture("asset-editor")
	check(editor.skins.text == "Skins: Default" and editor.skin_section.visible, "Selected asset exposes its Skin section")
	check(editor.replace_button.disabled and editor.skin_button.visible, "Protected asset offers skin editing without changing its source")
	check(editor.themes_button.get_global_rect().end.x > editor.size.x - 30, "Themes is at the right edge of the header")
	var started := Time.get_ticks_msec()
	editor._edit_skin()
	print("Open Themes dispatch ms: ", Time.get_ticks_msec() - started)
	var themes: Control = editor.theme_editor
	check(themes.loader != null and themes.visible, "Themes opens immediately while skin validation runs in a worker")
	check(themes.chooser == null, "Opening Themes does not initialize the filesystem picker")
	for frame in 600:
		await process_frame
		if themes.loader == null: break
	check(themes.manager.game_id == "editor-fixture" and themes.selected.id == "piece-0", "Per-asset navigation opens the matching game and slot once")
	themes._populate()
	check(themes.grid.get_child_count() == 0 and themes.tile_pending.size() == 480, "Large catalogs create tiles progressively")
	await capture("themes-desktop")
	check(themes.grid.get_child_count() > 0 and themes.browse_count.text == "480 / 480", "Asset browser shows catalog count and progressive tiles")
	themes.search.text = "Piece 479"
	themes._populate()
	await process_frame
	check(themes.browse_count.text == "1 / 480", "Search filters the asset inventory")
	themes.search.clear(); themes.group_choice.select(1); themes.group_filter = themes.group_choice.get_item_text(1); themes._populate()
	check(themes.browse_count.text == "240 / 480", "Group filtering stays separate from assets")
	themes.group_filter = "All groups"; themes.sort_choice.select(1); themes._populate()
	check(themes.tile_pending[0].label == "Piece 479", "Descending sort uses natural asset names")
	var created: Dictionary = themes.manager.duplicate_pack("default", "Blue skin")
	check(created.ok, "Duplicate Default still creates an independent skin")
	var pack: Dictionary = created.pack.duplicate(true)
	check(themes.manager.stage_media(pack, "piece-0", runtime.path_join("asset/test/launcher.svg")).ok and themes.manager.save_pack(pack).ok, "Skin artwork still stages and saves through validated manifests")
	themes._load_theme("blue-skin"); themes._focus_slot("piece-0")
	themes._use_skin()
	check(app.game_settings_store.load_settings("editor-fixture", {"theme":"default"}).theme == "blue-skin", "Use skin persists the accepted preference")
	var skin_entries := store.scan().filter(func(entry: Dictionary) -> bool: return str(entry.path).contains("/themes/blue-skin/media/"))
	check(skin_entries.size() == 1 and skin_entries[0].protected and skin_entries[0].skin == "Blue Skin", "Custom media is discoverable with its skin and remains immutable")
	for view in [["portrait",390,844],["landscape",844,390],["desktop",1280,720]]:
		root.content_scale_size = Vector2i(view[1],view[2]); root.size = root.content_scale_size
		await capture("themes-" + str(view[0]))
		check(inside(themes.save_button) and inside(themes.use_button), "Theme actions remain reachable in " + str(view[0]))
		check(inside(themes.game_choice) and inside(themes.sort_choice), "Context and filters fit in " + str(view[0]))
	var cached_id := themes.get_instance_id()
	themes.exit_requested.emit()
	check(not themes.visible and editor.content.visible, "Return reveals the original asset editor")
	await settle_browser(editor)
	check(editor.category_cache.size() == 1 and editor.category_cache["Games/editor-fixture"].size() == 485, "Returning from Themes refreshes the open game and discovers its new skin media")
	started = Time.get_ticks_msec(); editor._open_themes()
	print("Reopen Themes dispatch ms: ", Time.get_ticks_msec() - started)
	check(editor.theme_editor.get_instance_id() == cached_id and themes.loader == null, "Reopening reuses the loaded editor without rescanning skins")
	# Dirty names retain the existing Save / Discard / Cancel guard.
	themes.draft.labels["piece-0"] = "Unsaved name"; themes._changed()
	themes.request_leave(func() -> void: themes.hide())
	var guarded := false
	for child in themes.get_children():
		if child is ConfirmationDialog:
			guarded = true; child.canceled.emit(); child.queue_free()
	check(guarded and themes.visible and themes.draft != themes.original, "Cancel keeps the unsaved skin draft visible")
	themes._apply_theme("blue-skin"); themes.exit_requested.emit()
	await settle_browser(editor)
	editor.folders["Launcher"].collapsed = false
	await settle_browser(editor)
	check(editor.store.entries.any(func(entry: Dictionary) -> bool: return entry.path == "asset/test/launcher.svg") and not editor.category_cache.has("Games/other-fixture"), "Launcher media loads independently of unopened games")
	check(not editor.category_cache.Launcher.any(func(entry: Dictionary) -> bool: return entry.path.begins_with("asset/editor-fixture/")), "Launcher skips detected games' legacy asset folders")
	editor.selected = editor.category_cache.Launcher.filter(func(entry: Dictionary) -> bool: return entry.path == "asset/test/launcher.svg")[0]; editor._discard()
	check(editor.skins.text == "Skins: Default" and not editor.replace_button.disabled, "Launcher assets retain ordinary Default replacement")
	editor._stage(runtime.path_join("asset/test/launcher.svg"))
	for frame in 600:
		await process_frame
		if editor.worker == null: break
	var staged := str(editor.pending.get("staged", ""))
	check(not staged.is_empty(), "A loaded launcher asset still supports staged replacement")
	editor._set_sections_collapsed(true)
	await settle_browser(editor)
	check(editor.folders.values().all(func(item: TreeItem) -> bool: return item.collapsed) and listed_assets(editor.tree.get_root()).is_empty(), "Collapse All removes hidden rows and preserves collapsed categories")
	check(editor.pending.get("staged") == staged and not editor.save_button.disabled, "Collapsing preserves the staged replacement")
	editor._set_sections_collapsed(false)
	await settle_browser(editor)
	check(editor.category_cache.size() == 4 and editor.folders.values().all(func(item: TreeItem) -> bool: return not item.collapsed), "Explicit Expand All progressively loads every category")
	var shared: Array = editor.category_cache["Games/other-fixture"].filter(func(entry: Dictionary) -> bool: return entry.path == piece.path)
	check(shared.size() == 1 and shared[0].game_id == "other-fixture" and shared[0].protected, "Variants discover declared shared artwork with their own protected slot")
	var shared_item: TreeItem = editor.folders["Games/other-fixture/Games/editor-fixture/art"].get_first_child()
	editor.selected = piece.duplicate(); editor.selected.category = "Games/editor-fixture"
	shared_item.select(0)
	# The pending replacement guard still applies when the physical source is
	# shared by two games; cancel it before continuing the launcher replacement.
	var shared_guard := false
	for child in editor.get_children():
		if child is ConfirmationDialog:
			shared_guard = true; child.canceled.emit(); child.queue_free()
	check(shared_guard, "Selecting the same source in another game preserves the unsaved-change guard")
	editor.selected = editor.category_cache.Launcher.filter(func(entry: Dictionary) -> bool: return entry.path == "asset/test/launcher.svg")[0]
	check(editor.category_cache["Games/empty-fixture"].is_empty(), "Empty games finish loading without repeating their scan")
	check(editor.pending.get("staged") == staged, "Loading other games preserves the staged replacement")
	editor._save()
	check(editor.pending.is_empty() and editor.scanner == null and editor.category_cache.size() == 4, "Saving updates the selected asset without rescanning libraries")
	check(editor.selected.source == RuntimeAssets.source("res://asset/test/launcher.svg"), "Saved asset metadata points at the accepted replacement")
	editor.folders["Games/other-fixture"].collapsed = true
	await settle_browser(editor)
	editor._open_themes(); themes.exit_requested.emit()
	await settle_browser(editor)
	check(editor.dirty_categories.has("Games/other-fixture") and editor.category_cache.has("Games/other-fixture"), "Returning from Themes defers refreshing collapsed games and retains their selected media")
	editor.folders["Games/other-fixture"].collapsed = false
	await settle_browser(editor)
	check(not editor.dirty_categories.has("Games/other-fixture"), "Reopening a changed category refreshes its inventory")
	for view in [["portrait",390,844],["landscape",844,390]]:
		root.content_scale_size = Vector2i(view[1],view[2]); root.size = root.content_scale_size
		await capture("assets-" + str(view[0]))
		check(inside(editor.themes_button), "Themes navigation stays reachable in " + str(view[0]))
	editor.request_exit(); await process_frame
	check(app.current_state == "settings", "Clean return restores Settings")
	app._show_asset_editor()
	check(app.asset_editor.category_cache.is_empty() and app.asset_editor.folders.values().all(func(item: TreeItem) -> bool: return item.collapsed), "Reopening the editor starts with every category collapsed and unloaded")
	app.asset_editor.request_exit(); await process_frame
	app.queue_free(); await process_frame; await process_frame
	RuntimeAssets.root_override = ""; RuntimeAssets.refresh()
	print("Asset editor fixture: %d checks, %d failures; captures: %s" % [checks, failures, fixture])
	quit(1 if failures else 0)
