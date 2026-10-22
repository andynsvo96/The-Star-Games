extends SceneTree
var checks := 0
var failures := 0
var manager := ThemePacks.new("monopoly-deal")

func _init() -> void: call_deferred("_run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + text)

func _run() -> void:
	var fixture := "res://.test_data/theme-packs-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(fixture); RuntimeAssets.root_override = ProjectSettings.globalize_path(fixture); RuntimeAssets.refresh()
	check(manager.list_packs().size() == 1 and manager.slots.size() == 69, "Default pack and 69 grouped slots discovered")
	var created := manager.duplicate_pack("default", "Philadelphia")
	check(created.ok and manager.list_packs().size() == 2, "Duplicate creates a separately named cosmetic pack")
	var pack: Dictionary = created.pack.duplicate(true); pack.labels["boardwalk"] = "City Hall <test>"
	check(manager.save_pack(pack).ok and manager.load_pack("philadelphia").labels.boardwalk == "City Hall <test>", "Editable names survive a reload as literal text")
	var original := FileAccess.get_sha256("res://Games/monopoly-deal/art/boardwalk.svg")
	check(manager.pin("philadelphia").id == "philadelphia" and ThemePacks.resolve("Games/monopoly-deal/art/boardwalk.svg") == "Games/monopoly-deal/art/boardwalk.svg", "Partial themes inherit default art")
	var image := Image.create(44,60,false,Image.FORMAT_RGBA8); image.fill(Color.PURPLE); image.save_png(fixture + "/custom.png")
	check(manager.stage_media(pack,"boardwalk",fixture+"/custom.png").ok, "Valid image is prepared in a content-addressed slot")
	check(ThemePacks.resolve("Games/monopoly-deal/art/boardwalk.svg") == "Games/monopoly-deal/art/boardwalk.svg", "Preparing a draft does not change the active game")
	check(manager.save_pack(pack).ok and ThemePacks.resolve("Games/monopoly-deal/art/boardwalk.svg") == "Games/monopoly-deal/art/boardwalk.svg", "Saving does not mutate the pinned pack")
	manager.pin("philadelphia")
	check(RuntimeAssets.texture("res://Games/monopoly-deal/art/boardwalk.svg").get_width() == 44, "Native artwork resolves the chosen pack through its canonical path")
	check(FileAccess.get_sha256("res://Games/monopoly-deal/art/boardwalk.svg") == original, "Default artwork is untouched")
	check(not manager.save_pack(manager.load_pack("default")).ok and not manager.duplicate_pack("default","../escape").ok, "Default and traversal names are rejected")
	var isolated := manager.duplicate_pack("philadelphia","Second")
	check(isolated.ok and isolated.pack.assets.boardwalk.contains("/second/"), "Duplicates isolate media from their source pack")
	var invalid := pack.duplicate(true); invalid.assets.boardwalk = "Games/monopoly-deal/host/main.gd"
	check(not manager.save_pack(invalid).ok and manager.load_pack("philadelphia").assets.boardwalk == pack.assets.boardwalk, "Invalid manifest is rolled back to the previous theme")
	manager.pin("default")
	check(RuntimeAssets.texture("res://Games/monopoly-deal/art/boardwalk.svg").get_width() == 240, "Choosing Default restores the original art")
	var media: String = pack.assets.boardwalk
	var file := FileAccess.open(RuntimeAssets.root_folder().path_join(media),FileAccess.WRITE); file.store_string("corrupt"); file.close()
	check(manager.load_pack("philadelphia").is_empty() and manager.pin("philadelphia").id == "default", "Corrupt immutable media invalidates its pack and falls back to Default")
	ThemePacks.active.clear(); RuntimeAssets.root_override = ""; RuntimeAssets.refresh()
	var store := AssetStore.new(); var entries := store.scan()
	check(entries.any(func(entry: Dictionary) -> bool: return entry.kind == "themes") and not entries.any(func(entry: Dictionary) -> bool: return entry.path == "Games/monopoly-deal/art/boardwalk.svg"), "Asset Editor routes grouped games to themes and protects Default")
	print("Theme packs: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
