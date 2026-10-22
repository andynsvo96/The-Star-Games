class_name GameSettingsStore
extends RefCounted

# Preferences only: never persist a board, roster, scores or private game state.
const SCHEMA_VERSION := 1
var directory := "user://game_settings"
var last_error := ""


func _init(custom_directory := "") -> void:
	if not custom_directory.is_empty():
		directory = custom_directory


func load_settings(game_id: String, defaults: Dictionary) -> Dictionary:
	return _with_defaults(defaults, _read(game_id))


static func _with_defaults(defaults: Dictionary, saved: Dictionary) -> Dictionary:
	var values := defaults.duplicate(true)
	for key in defaults:
		var value: Variant = saved.get(key)
		var fallback: Variant = defaults[key]
		if fallback is Dictionary and value is Dictionary:
			values[key] = _with_defaults(fallback, value)
		elif fallback is int and (value is int or value is float):
			if is_finite(float(value)) and float(value) == floor(float(value)) and absf(float(value)) <= 2147483647:
				values[key] = int(value)
		elif fallback is float and (value is int or value is float):
			if is_finite(float(value)):
				values[key] = float(value)
		elif typeof(value) == typeof(fallback):
			values[key] = value.duplicate(true) if value is Array else value
	return values


func _path(game_id: String) -> String:
	if game_id.is_empty():
		return ""
	for character in game_id:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789-":
			return ""
	return directory.path_join(game_id + ".json")


func _read(game_id: String) -> Dictionary:
	var path := _path(game_id)
	if path.is_empty():
		return {}
	# A previous committed file remains usable after an interrupted replacement.
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate)) != OK:
			continue
		var data: Variant = parser.data
		if data is Dictionary and data.get("schema_version") == SCHEMA_VERSION and data.get("settings") is Dictionary:
			return data.settings
	return {}


func save_settings(game_id: String, changes: Dictionary) -> bool:
	last_error = ""
	var path := _path(game_id)
	if path.is_empty():
		last_error = "Cannot save settings without a valid game ID."
		return false
	var values := _read(game_id)
	values.merge(changes.duplicate(true), true)
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		last_error = "Could not create the game settings folder."
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Could not save game settings."
		return false
	file.store_string(JSON.stringify({"schema_version": SCHEMA_VERSION, "settings": values}, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_error = "Could not write game settings."
		return false
	if FileAccess.file_exists(path + ".bak") and DirAccess.remove_absolute(absolute + ".bak") != OK:
		last_error = "Could not replace the game settings backup."
		return false
	if FileAccess.file_exists(path) and DirAccess.rename_absolute(absolute, absolute + ".bak") != OK:
		last_error = "Could not back up game settings."
		return false
	if DirAccess.rename_absolute(absolute + ".tmp", absolute) != OK:
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.rename_absolute(absolute + ".bak", absolute)
		last_error = "Could not finish saving game settings."
		return false
	return true
