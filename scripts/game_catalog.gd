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
		var result := _read_game(folder_name)
		if not result["ok"]:
			diagnostics.append({"folder": folder_name, "message": result["error"]})
			continue
		var game: Dictionary = result["game"]
		if used_ids.has(game["id"]):
			diagnostics.append({"folder": folder_name, "message": "Duplicate game ID: %s" % game["id"]})
			continue
		used_ids[game["id"]] = true
		games.append(game)
	_validate_collections()
	scan_completed.emit(games, diagnostics)
	return games


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
			if child.is_empty() or child.has("game_choices"):
				diagnostics.append({"folder": game.id, "message": "Collection choice must reference an existing standalone game: %s" % id})
				rejected.append(game)
				break
	for game in rejected: games.erase(game)


func _read_game(folder_name: String) -> Dictionary:
	var folder := games_root.path_join(folder_name)
	var manifest_path := folder.path_join("game.json")
	if not FileAccess.file_exists(manifest_path):
		return {"ok": false, "error": "Missing game.json."}
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Could not read game.json."}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"ok": false, "error": "game.json is not valid JSON object."}
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
		for id in parsed.game_choices:
			if not id is String or not _is_valid_id(id) or id == game_id or seen.has(id):
				return {"ok": false, "error": "game_choices must contain distinct, safe child game IDs."}
			seen.append(id)
	for path_field in ["thumbnail", "host_scene", "controller_entry"]:
		var relative := str(parsed[path_field])
		if not _is_safe_relative_path(relative):
			return {"ok": false, "error": "%s must be a safe relative path." % path_field}
		if not FileAccess.file_exists(folder.path_join(relative)):
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
	var game: Dictionary = parsed.duplicate(true)
	game["folder"] = folder
	game["host_scene_path"] = folder.path_join(str(parsed["host_scene"]))
	game["thumbnail_path"] = folder.path_join(str(parsed["thumbnail"]))
	game["controller_entry_path"] = folder.path_join(str(parsed["controller_entry"]))
	return {"ok": true, "game": game}


func _is_valid_id(value: String) -> bool:
	if value.is_empty() or value.begins_with("-") or value.ends_with("-"):
		return false
	for character in value:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789-":
			return false
	return true


func _is_safe_relative_path(value: String) -> bool:
	if value.is_empty() or value.is_absolute_path() or value.contains("\\"):
		return false
	for segment in value.split("/"):
		if segment in ["", ".", ".."]:
			return false
	return true
