class_name ThemePacks
extends RefCounted

# Shared, cosmetic-only packs. A game pins an immutable manifest until replay.
static var active: Dictionary = {}
var game_id := ""
var slots: Array = []
var presentation := "card-table"
var preview_kind := "cards"
var last_error := ""
var definitions_root := "res://Games"


func _init(id := "", custom_definitions_root := "") -> void:
	game_id = id
	if not custom_definitions_root.is_empty(): definitions_root = custom_definitions_root
	# Preserve legacy packs while allowing new modules to declare their preview.
	if id == "monopoly-deal": presentation = "modern-table"
	if valid_id(id):
		var value: Variant = _read(definitions_root.path_join(id).path_join("theme-slots.json"))
		if value is Dictionary and value.get("schema_version") == 1 and value.get("slots") is Array:
			if value.get("presentation", "") in ["card-table", "modern-table"]:
				presentation = value.presentation
			if value.get("preview_kind", "") in ["cards", "portfolio", "assets"]:
				preview_kind = value.preview_kind
			# Only the bundled definition can opt into another module's shared art.
			# Packs themselves cannot add slots, sources, or rule/content files.
			var sources: Array = [id]
			if value.get("asset_sources") is Array:
				for source in value.asset_sources:
					if source is String and valid_id(source) and not sources.has(source): sources.append(source)
			var ids := {}; var paths := {}
			for slot in value.slots:
				if not slot is Dictionary: continue
				var path := str(slot.get("path", ""))
				if not valid_id(str(slot.get("id", ""))) or not RuntimeAssets.safe_media_path(path): continue
				if not path.begins_with("Games/") or not path.get_slice("/", 1) in sources: continue
				if slot.get("kind") not in ["image", "audio", "background"] or not slot.get("label") is String or not slot.get("group") is String: continue
				if ids.has(slot.id) or paths.has(path): continue
				ids[slot.id] = true; paths[path] = true; slots.append(slot)


static func valid_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64 or value.begins_with("-") or value.ends_with("-"): return false
	for character in value:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789-": return false
	return true


func list_packs() -> Array:
	var result: Array = []
	var ids: Array = ["default"]
	for folder in [definitions_root.path_join(game_id).path_join("themes"), RuntimeAssets.root_folder().path_join("Games/%s/themes" % game_id)]:
		if DirAccess.dir_exists_absolute(folder):
			for id in DirAccess.get_directories_at(folder):
				if valid_id(id) and not ids.has(id): ids.append(id)
	ids.sort()
	ids.erase("default"); ids.push_front("default")
	for id in ids:
		var pack := load_pack(id)
		if not pack.is_empty(): result.append(pack)
	return result


func load_pack(id: String) -> Dictionary:
	if not valid_id(game_id) or not valid_id(id) or slots.is_empty(): return {}
	var relative := "Games/%s/themes/%s/theme.json" % [game_id, id]
	var path := RuntimeAssets.root_folder().path_join(relative)
	if id == "default" or not FileAccess.file_exists(path): path = definitions_root.path_join(game_id).path_join("themes/%s/theme.json" % id)
	var pack: Variant = _read(path)
	if not pack is Dictionary or pack.get("schema_version") != 1 or pack.get("id") != id or not pack.get("name") is String or pack.name.strip_edges().is_empty() or pack.name.length() > 64: return {}
	if not pack.get("assets", {}) is Dictionary or not pack.get("labels", {}) is Dictionary: return {}
	var allowed: Array = slots.map(func(slot: Dictionary) -> String: return slot.id)
	for key in pack.get("assets", {}):
		var file: Variant = pack.assets[key]
		if not key in allowed or not file is String or not RuntimeAssets.safe_media_path(file) or not file.begins_with("Games/%s/themes/%s/media/" % [game_id, id]): return {}
		if not _safe(file): return {}
		if not FileAccess.file_exists(RuntimeAssets.root_folder().path_join(file)) and not FileAccess.file_exists("res://" + file): return {}
		var physical := RuntimeAssets.root_folder().path_join(file)
		if not FileAccess.file_exists(physical): physical = "res://" + file
		var signature := FileAccess.get_sha256(physical).substr(0, 24)
		if not file.get_file().begins_with(str(key) + "-" + signature + "."): return {}
		var slot: Dictionary = slots.filter(func(item: Dictionary) -> bool: return item.id == key)[0]
		# Bundled, content-addressed videos were validated by the desktop editor.
		# Android has no FFmpeg; the shared native player validates OGV playback
		# and retains its image fallback for unsupported containers.
		var inspected := {"ok": true, "kind": "video"} if OS.get_name() == "Android" and AssetStore.kind(physical) == "video" else AssetStore.inspect(physical)
		if not inspected.ok or (inspected.kind != slot.kind and not (slot.kind == "background" and inspected.kind in ["image", "video"])): return {}
	for key in pack.get("labels", {}):
		if not key in allowed or not pack.labels[key] is String or pack.labels[key].strip_edges().is_empty() or pack.labels[key].length() > 80: return {}
	pack["assets"] = pack.get("assets", {})
	pack["labels"] = pack.get("labels", {})
	pack["revision"] = JSON.stringify(pack).sha256_text().substr(0, 20)
	return pack


func duplicate_pack(source: String, name: String) -> Dictionary:
	var pack := load_pack(source)
	var id := name.strip_edges().to_lower().replace(" ", "-")
	if pack.is_empty() or not valid_id(id) or id == "default" or not load_pack(id).is_empty(): return _error("Choose a new theme name using letters, numbers and spaces.")
	var copy := {"schema_version": 1, "id": id, "name": name.strip_edges(), "assets": {}, "labels": pack.labels.duplicate(true)}
	for key in pack.assets:
		var old: String = pack.assets[key]
		var target := "Games/%s/themes/%s/media/%s" % [game_id, id, old.get_file()]
		if not _safe(target): return _error("Theme destination contains a linked folder.")
		DirAccess.make_dir_recursive_absolute(RuntimeAssets.root_folder().path_join(target).get_base_dir())
		var current := RuntimeAssets.root_folder().path_join(old)
		if not FileAccess.file_exists(current): current = "res://" + old
		if not RuntimeAssets.copy_file(current, RuntimeAssets.root_folder().path_join(target)): return _error("Could not duplicate the artwork.")
		copy.assets[key] = target
	return save_pack(copy)


func save_pack(pack: Dictionary) -> Dictionary:
	var id := str(pack.get("id", ""))
	if not valid_id(id) or id == "default": return _error("Duplicate Default before editing.")
	var relative := "Games/%s/themes/%s/theme.json" % [game_id, id]
	if not _safe(relative): return _error("Theme destination contains a linked folder.")
	var path := RuntimeAssets.root_folder().path_join(relative)
	var previous := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var backup := ""
	if not previous.is_empty():
		backup = RuntimeAssets.root_folder().path_join("Backups/themes-%s-%s" % [Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_usec()])
		if not _safe("Backups") or DirAccess.make_dir_recursive_absolute(backup.path_join(relative).get_base_dir()) != OK: return _error("Could not create a backup.")
		if not RuntimeAssets.copy_file(path, backup.path_join(relative)): return _error("Backup failed; theme is unchanged.")
		var ignore := FileAccess.open(backup.path_join(".gdignore"), FileAccess.WRITE)
		if ignore != null: ignore.close()
	var value := pack.duplicate(true)
	value.erase("revision")
	if not AssetStore._write_json(path, value): return _error("Could not save the theme.")
	var checked := load_pack(id)
	if checked.is_empty():
		if previous.is_empty(): DirAccess.remove_absolute(path)
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null: file.store_string(previous)
		return _error("Invalid theme; previous version restored.")
	return {"ok": true, "pack": checked, "backup": backup}


func stage_media(pack: Dictionary, slot_id: String, source_path: String) -> Dictionary:
	if pack.get("id", "default") == "default": return _error("Duplicate Default before editing.")
	var found: Array = slots.filter(func(slot: Dictionary) -> bool: return slot.id == slot_id)
	if found.is_empty(): return _error("Select an asset slot.")
	var slot: Dictionary = found[0]
	var result := AssetStore.inspect(source_path)
	if not result.ok: return result
	if result.kind != slot.kind and not (slot.kind == "background" and result.kind in ["image", "video"]): return _error("Choose media matching this asset group.")
	var signature := FileAccess.get_sha256(source_path)
	var relative := "Games/%s/themes/%s/media/%s-%s.%s" % [game_id, pack.id, slot_id, signature.substr(0, 24), source_path.get_extension().to_lower()]
	if not _safe(relative): return _error("Theme destination contains a linked folder.")
	var target := RuntimeAssets.root_folder().path_join(relative)
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	if not FileAccess.file_exists(target) and not RuntimeAssets.copy_file(source_path, target): return _error("Could not prepare artwork.")
	# Content-addressed files are immutable. Only the confirmed manifest activates them.
	pack.assets[slot_id] = relative
	return {"ok": true, "source": target}


func pin(id: String) -> Dictionary:
	var pack := load_pack(id)
	if pack.is_empty(): pack = load_pack("default")
	if pack.is_empty():
		unpin(game_id)
		return {}
	var mapping := {}
	for slot in slots:
		if pack.get("assets", {}).has(slot.id): mapping[slot.path] = pack.assets[slot.id]
	active[game_id] = {"pack": pack.duplicate(true), "mapping": mapping}
	RuntimeAssets.textures.clear()
	return pack


static func unpin(id: String) -> void:
	active.erase(id)
	RuntimeAssets.textures.clear()


# Public cosmetic metadata only; never expose a manifest's filesystem paths.
static func snapshot(id: String) -> Dictionary:
	var pack: Dictionary = active.get(id, {}).get("pack", {})
	if pack.is_empty(): return {}
	return {"id": pack.id, "name": pack.name, "revision": pack.revision, "labels": pack.labels.duplicate(true)}


func display_name(slot: String, fallback: String, pack: Dictionary) -> String:
	return str(pack.get("labels", {}).get(slot, fallback))


static func resolve(relative: String) -> String:
	var id := relative.get_slice("/", 1)
	# A variant may use another module's art while retaining its own pack/settings.
	for owner in active:
		if owner != id and active[owner].get("mapping", {}).has(relative): return str(active[owner].mapping[relative])
	return str(active.get(id, {}).get("mapping", {}).get(relative, relative))


static func _safe(relative: String) -> bool:
	var path := RuntimeAssets.root_folder()
	for segment in relative.split("/"):
		path = path.path_join(segment)
		if AssetStore._is_link(path): return false
	return true


static func _read(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null


func _error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}
