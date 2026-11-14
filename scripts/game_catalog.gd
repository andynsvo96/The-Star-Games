class_name GameCatalog
extends RefCounted

signal scan_completed(games: Array, diagnostics: Array)

const SUPPORTED_SCHEMA_VERSION := 1
const ALLOWED_MODES := ["singleplayer", "multiplayer"]

var games_root := "res://Games"
var games: Array = []
var diagnostics: Array = []


func _init(custom_root := "") -> void:
	if not custom_root.is_empty():
		games_root = custom_root.trim_suffix("/")


func scan() -> Array:
	games.clear()
	diagnostics.clear()
	var directory := DirAccess.open(games_root)
	if directory == null:
		diagnostics.append({"folder": games_root, "message": "Games folder is missing or unreadable."})
		scan_completed.emit(games, diagnostics)
		return games
	var used_ids := {}
	var folders := directory.get_directories()
	folders.sort()
	for folder_name in folders:
		if folder_name.begins_with("_"):
			continue
		_scan_folder(folder_name, used_ids)
	_validate_collections()
	scan_completed.emit(games, diagnostics)
	return games


func _scan_folder(relative: String, used_ids: Dictionary, expected_id := "", child := false) -> void:
	# Declared modes are optional installations. An absent folder is a disabled
	# choice; a present but malformed module still deserves a scan diagnostic.
	if child and not DirAccess.dir_exists_absolute(games_root.path_join(relative)): return
	var result := _read_game(relative)
	if not result.ok:
		diagnostics.append({"folder": relative, "message": result.error})
		return
	var game: Dictionary = result.game
	if not expected_id.is_empty() and game.id != expected_id:
		diagnostics.append({"folder": relative, "message": "Mode ID must match its declaration: %s" % expected_id})
		return
	if child and game.has("game_choices"):
		diagnostics.append({"folder": relative, "message": "Nested collections are not supported."})
		return
	if used_ids.has(game.id):
		diagnostics.append({"folder": relative, "message": "Duplicate game ID: %s" % game.id})
		return
	used_ids[game.id] = true
	games.append(game)
	for choice in game.get("choice_definitions", []):
		if choice.has("folder"):
			_scan_folder(relative.path_join(choice.folder), used_ids, choice.id, true)


# Keep declared choices even when their optional folder is absent or invalid.
# Only validated modules enter games, LAN routing, or launch eligibility.
func choices_for(collection: Dictionary) -> Array:
	var result: Array = []
	var definitions: Array = collection.get("choice_definitions", [])
	if definitions.is_empty():
		for id in collection.get("game_choices", []): definitions.append({"id": id, "title": str(id).capitalize()})
	for definition in definitions:
		var installed := find_game(str(definition.id))
		if definition.has("folder") and installed.get("folder", "") != str(collection.folder).path_join(definition.folder):
			installed = {}
		var choice := installed.duplicate(true)
		if choice.is_empty():
			choice = {"id": definition.id, "title": definition.title}
		choice["available"] = not installed.is_empty()
		result.append(choice)
	return result


# Lightweight manifest inventory for skin/editor paths. Do not recursively scan
# artwork, source archives or arbitrary subfolders looking for modules.
static func module_folders(root := "res://Games") -> Dictionary:
	var result: Dictionary = {}
	var folders := DirAccess.get_directories_at(root)
	folders.sort()
	for name in folders:
		if name.begins_with("_") or AssetStore._is_link(root.path_join(name)): continue
		var folder := root.path_join(name)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("game.json"))) if FileAccess.file_exists(folder.path_join("game.json")) else null
		# Theme fixtures and legacy definitions may have slots without a manifest.
		var id := str(parsed.get("id", name)) if parsed is Dictionary else str(name)
		if not _is_valid_id(id): continue
		if not result.has(id): result[id] = folder
		if not parsed is Dictionary or not parsed.get("game_choices") is Array: continue
		for choice in parsed.game_choices:
			if not choice is Dictionary or not choice.get("id") is String or not choice.get("folder") is String: continue
			if not _is_valid_id(choice.id) or not _is_safe_relative_path(choice.folder) or choice.folder.contains("/") or choice.folder.begins_with("_"): continue
			var nested := folder.path_join(choice.folder)
			if AssetStore._is_link(nested) or not FileAccess.file_exists(nested.path_join("game.json")): continue
			var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(nested.path_join("game.json")))
			if manifest is Dictionary and manifest.get("id") == choice.id and not manifest.has("game_choices") and not result.has(choice.id): result[choice.id] = nested
	return result


static func module_folder(id: String, root := "res://Games") -> String:
	return str(module_folders(root).get(id, root.path_join(id)))


static func path_owner(relative: String, folders: Dictionary) -> String:
	var owner := ""
	var longest := 0
	for id in folders:
		var prefix := str(folders[id]).trim_prefix("res://").trim_suffix("/") + "/"
		if relative.begins_with(prefix) and prefix.length() > longest:
			owner = id
			longest = prefix.length()
	return owner


static func controller_asset_url(resource: String) -> String:
	return _controller_resource(resource, module_folders())


static func controller_resources(value: Variant) -> Variant:
	return _controller_resource(value, module_folders())


static func _controller_resource(value: Variant, folders: Dictionary) -> Variant:
	if value is Array:
		return value.map(func(item: Variant) -> Variant: return _controller_resource(item, folders))
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = _controller_resource(value[key], folders)
		return result
	if not value is String or not value.begins_with("res://Games/"): return value
	var resource: String = value
	var relative := resource.trim_prefix("res://")
	var id := path_owner(relative, folders)
	if id.is_empty(): return resource
	return "/game/%s/%s" % [id, relative.trim_prefix(str(folders[id]).trim_prefix("res://") + "/")]


# Collections change menu presentation only. Children retain their stable IDs,
# settings, controller routes and independently validated manifests.
func menu_games() -> Array:
	var children: Array = []
	for game in games:
		for id in game.get("game_choices", []):
			if not children.has(id): children.append(id)
	return games.filter(func(game: Dictionary) -> bool: return not children.has(game.id))


func find_game(id: String) -> Dictionary:
	for game in games:
		if game.id == id: return game
	return {}


func _validate_collections() -> void:
	var rejected: Array = []
	for game in games:
		for id in game.get("game_choices", []):
			var child := find_game(id)
			if not child.is_empty() and child.has("game_choices"):
				diagnostics.append({"folder": game.id, "message": "Collection choice must reference a standalone game: %s" % id})
				rejected.append(game)
				break
	for game in rejected: games.erase(game)


func _read_game(folder_name: String) -> Dictionary:
	var folder := games_root.path_join(folder_name)
	if AssetStore._is_link(folder):
		return {"ok": false, "error": "Game folders must not be linked directories."}
	var manifest_path := folder.path_join("game.json")
	if not FileAccess.file_exists(manifest_path):
		return {"ok": false, "error": "Missing game.json."}
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Could not read game.json."}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "error": "game.json is not valid JSON object."}
	parsed.erase("choice_definitions")
	var required := ["schema_version", "id", "title", "description", "version", "thumbnail", "host_scene", "controller_entry", "min_players", "max_players", "modes"]
	for field in required:
		if not parsed.has(field):
			return {"ok": false, "error": "Missing required field: %s" % field}
	if int(parsed["schema_version"]) != SUPPORTED_SCHEMA_VERSION:
		return {"ok": false, "error": "Unsupported schema version: %s" % parsed["schema_version"]}
	var game_id := str(parsed["id"])
	if not _is_valid_id(game_id):
		return {"ok": false, "error": "Game ID must use lowercase letters, numbers, and hyphens."}
	var minimum := int(parsed["min_players"])
	var maximum := int(parsed["max_players"])
	if minimum < 1 or maximum < minimum or maximum > 16:
		return {"ok": false, "error": "Player limits must satisfy 1 <= min <= max <= 16."}
	if not parsed["modes"] is Array or parsed["modes"].is_empty():
		return {"ok": false, "error": "Modes must be a non-empty array."}
	for mode in parsed["modes"]:
		if not ALLOWED_MODES.has(str(mode)):
			return {"ok": false, "error": "Unsupported mode: %s" % mode}
	if parsed.has("game_choices"):
		if not parsed.game_choices is Array or parsed.game_choices.is_empty():
			return {"ok": false, "error": "game_choices must be a non-empty array of game IDs."}
		var seen: Array = []
		var definitions: Array = []
		var choice_folders: Array = []
		for entry in parsed.game_choices:
			var id: Variant = entry.get("id") if entry is Dictionary else entry
			if not id is String or not _is_valid_id(id) or id == game_id or seen.has(id):
				return {"ok": false, "error": "game_choices must contain distinct, safe child game IDs."}
			var definition := {"id": id, "title": id.capitalize()}
			if entry is Dictionary:
				if not entry.get("title") is String or entry.title.strip_edges().is_empty() or entry.title.length() > 100:
					return {"ok": false, "error": "Each mode needs a non-empty title of at most 100 characters."}
				var nested: Variant = entry.get("folder")
				if not nested is String or not _is_safe_relative_path(nested) or nested.contains("/") or nested.begins_with("_") or choice_folders.has(nested.to_lower()):
					return {"ok": false, "error": "Each mode needs a distinct, safe direct subfolder."}
				definition.title = entry.title
				definition["folder"] = nested
				choice_folders.append(nested.to_lower())
			definitions.append(definition)
			seen.append(id)
		parsed.game_choices = seen
		parsed["choice_definitions"] = definitions
	if parsed.has("settings_variants"):
		if not parsed.settings_variants is bool or not parsed.has("game_choices"):
			return {"ok": false, "error": "settings_variants requires game_choices and a boolean value."}
	for path_field in ["thumbnail", "host_scene", "controller_entry"]:
		var relative := str(parsed[path_field])
		if not _is_safe_relative_path(relative):
			return {"ok": false, "error": "%s must be a safe relative path." % path_field}
		var resource := folder.path_join(relative)
		# Exported scenes/textures may have only a resource remap in the PCK.
		# Browser files still require their original bytes.
		var exists := FileAccess.file_exists(resource)
		if not exists and path_field in ["host_scene", "thumbnail"]: exists = ResourceLoader.exists(resource)
		if not exists:
			return {"ok": false, "error": "%s does not exist: %s" % [path_field, relative]}
	if parsed.has("background"):
		if not parsed["background"] is String or not _is_safe_relative_path(parsed["background"]) or not str(parsed["background"]).get_extension().is_empty():
			return {"ok": false, "error": "background must be a safe relative filename without an extension."}
	if parsed.has("background_variants"):
		if not parsed.background_variants is Dictionary or not parsed.has("background"):
			return {"ok": false, "error": "background_variants requires background and a dictionary of named filename stems."}
		for variant in parsed.background_variants:
			var stem: Variant = parsed.background_variants[variant]
			if not _is_valid_id(str(variant)) or not stem is String or not _is_safe_relative_path(stem) or not str(stem).get_extension().is_empty():
				return {"ok": false, "error": "background_variants must use stable names and safe extensionless paths."}
	if parsed.has("private_paths"):
		if not parsed.private_paths is Array or parsed.private_paths.size() > 32:
			return {"ok": false, "error": "private_paths must be an array of at most 32 safe relative files or folders."}
		var protected: Array = []
		var public_paths: Array = [parsed.controller_entry, parsed.thumbnail]
		var public_backgrounds: Array = parsed.get("background_variants", {}).values()
		if parsed.has("background"): public_backgrounds.append(parsed.background)
		for stem in public_backgrounds:
			public_paths.append(stem)
			for extension in BackgroundMedia.IMAGE_EXTENSIONS + BackgroundMedia.VIDEO_EXTENSIONS:
				public_paths.append(str(stem) + "." + extension)
		for path in parsed.private_paths:
			if not path is String or not _is_safe_relative_path(path) or protected.has(path.to_lower()):
				return {"ok": false, "error": "private_paths must contain distinct safe relative files or folders."}
			var prefix: String = path.to_lower()
			for public_path in public_paths:
				var public_name := str(public_path).to_lower()
				if public_name == prefix or public_name.begins_with(prefix + "/"):
					return {"ok": false, "error": "private_paths must not hide the controller entry, thumbnail, or background."}
			protected.append(prefix)
	var game: Dictionary = parsed.duplicate(true)
	game["folder"] = folder
	game["host_scene_path"] = folder.path_join(str(parsed["host_scene"]))
	game["thumbnail_path"] = folder.path_join(str(parsed["thumbnail"]))
	game["controller_entry_path"] = folder.path_join(str(parsed["controller_entry"]))
	return {"ok": true, "game": game}


static func _is_valid_id(value: String) -> bool:
	if value.is_empty() or value.begins_with("-") or value.ends_with("-"):
		return false
	for character in value:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789-":
			return false
	return true


static func _is_safe_relative_path(value: String) -> bool:
	if value.is_empty() or value.is_absolute_path() or value.contains("\\"):
		return false
	for segment in value.split("/"):
		if segment in ["", ".", ".."]:
			return false
	return true
