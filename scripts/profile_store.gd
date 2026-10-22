class_name ProfileStore
extends RefCounted

signal changed

const SCHEMA_VERSION := 1
const DEFAULT_SETTINGS := {
	"master_volume": 0.8,
	"music_volume": 0.7,
	"effects_volume": 0.8,
	"fullscreen": false,
	"reduced_motion": false,
	"game_view": "list",
	"host_name": "Star Host"
}

var data_path: String
var data: Dictionary = {}
var last_error := ""


func _init(custom_path := "") -> void:
	data_path = custom_path if not custom_path.is_empty() else "user://the_star_games.json"
	data = _default_data()


func load_data() -> bool:
	last_error = ""
	var recovered_from_backup := false
	if not FileAccess.file_exists(data_path):
		data = _default_data()
		return save_data()
	var parsed: Variant = _read_json(data_path)
	if not _is_valid_root(parsed):
		var backup_path := data_path + ".bak"
		parsed = _read_json(backup_path) if FileAccess.file_exists(backup_path) else null
		if not _is_valid_root(parsed):
			last_error = "The profile file was invalid. A new local profile store was created."
			data = _default_data()
			return save_data()
		recovered_from_backup = true
	data = parsed
	_migrate_and_sanitize()
	if recovered_from_backup:
		return save_data()
	return true


func save_data() -> bool:
	var temp_path := data_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		last_error = "Could not open the local profile store for writing."
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.flush()
	file.close()
	var absolute := ProjectSettings.globalize_path(data_path)
	var temp_absolute := ProjectSettings.globalize_path(temp_path)
	var backup_absolute := ProjectSettings.globalize_path(data_path + ".bak")
	if FileAccess.file_exists(data_path):
		if FileAccess.file_exists(data_path + ".bak"):
			DirAccess.remove_absolute(backup_absolute)
		var backup_error := DirAccess.rename_absolute(absolute, backup_absolute)
		if backup_error != OK:
			last_error = "Could not create a backup of the profile store."
			DirAccess.remove_absolute(temp_absolute)
			return false
	var replace_error := DirAccess.rename_absolute(temp_absolute, absolute)
	if replace_error != OK:
		last_error = "Could not finish saving the profile store."
		if FileAccess.file_exists(data_path + ".bak"):
			DirAccess.rename_absolute(backup_absolute, absolute)
		return false
	changed.emit()
	return true


func get_settings() -> Dictionary:
	return data.get("settings", DEFAULT_SETTINGS).duplicate(true)


func update_settings(values: Dictionary) -> bool:
	var settings: Dictionary = data["settings"]
	for key in DEFAULT_SETTINGS:
		if values.has(key):
			settings[key] = values[key]
	return save_data()


func get_profiles() -> Array:
	return data.get("profiles", []).duplicate(true)


func get_profile(profile_id: String) -> Dictionary:
	for profile in data.get("profiles", []):
		if profile.get("id", "") == profile_id:
			return profile.duplicate(true)
	return {}


func create_or_get_profile(display_name: String) -> Dictionary:
	var clean_name := display_name.strip_edges()
	if clean_name.is_empty() or clean_name.length() > 24:
		return {"ok": false, "error": "Names must contain 1 to 24 characters."}
	var normalized := _normalize_name(clean_name)
	for profile in data["profiles"]:
		if profile["normalized_name"] == normalized:
			return {"ok": true, "created": false, "profile": profile.duplicate(true)}
	var profile := {
		"id": _make_id(),
		"display_name": clean_name,
		"normalized_name": normalized,
		"game_points": {},
		"wins": 0,
		"losses": 0,
		"created_at": Time.get_datetime_string_from_system(true),
		"updated_at": Time.get_datetime_string_from_system(true)
	}
	data["profiles"].append(profile)
	save_data()
	return {"ok": true, "created": true, "profile": profile.duplicate(true)}


func rename_profile(profile_id: String, display_name: String) -> Dictionary:
	var clean_name := display_name.strip_edges()
	if clean_name.is_empty() or clean_name.length() > 24:
		return {"ok": false, "error": "Names must contain 1 to 24 characters."}
	var normalized := _normalize_name(clean_name)
	for profile in data["profiles"]:
		if profile["id"] != profile_id and profile["normalized_name"] == normalized:
			return {"ok": false, "error": "That profile name already exists."}
	for profile in data["profiles"]:
		if profile["id"] == profile_id:
			profile["display_name"] = clean_name
			profile["normalized_name"] = normalized
			profile["updated_at"] = Time.get_datetime_string_from_system(true)
			save_data()
			return {"ok": true, "profile": profile.duplicate(true)}
	return {"ok": false, "error": "Profile not found."}


func set_game_points(profile_id: String, game_id: String, points: int) -> bool:
	if game_id.strip_edges().is_empty():
		last_error = "A game ID is required."
		return false
	for profile in data["profiles"]:
		if profile["id"] == profile_id:
			profile["game_points"][game_id] = points
			profile["updated_at"] = Time.get_datetime_string_from_system(true)
			return save_data()
	last_error = "Profile not found."
	return false


func add_game_points(profile_id: String, game_id: String, amount: int) -> bool:
	var profile := get_profile(profile_id)
	if profile.is_empty():
		last_error = "Profile not found."
		return false
	var current := int(profile.get("game_points", {}).get(game_id, 0))
	return set_game_points(profile_id, game_id, current + amount)


func reset_game_points(profile_id: String, game_id: String) -> bool:
	for profile in data["profiles"]:
		if profile["id"] == profile_id:
			profile["game_points"].erase(game_id)
			profile["updated_at"] = Time.get_datetime_string_from_system(true)
			return save_data()
	return false


func reset_profile_points(profile_id: String) -> bool:
	for profile in data["profiles"]:
		if profile["id"] == profile_id:
			profile["game_points"] = {}
			profile["updated_at"] = Time.get_datetime_string_from_system(true)
			return save_data()
	return false


func reset_all_points() -> bool:
	for profile in data["profiles"]:
		profile["game_points"] = {}
		profile["updated_at"] = Time.get_datetime_string_from_system(true)
	return save_data()


func record_result(profile_id: String, won: bool) -> bool:
	for profile in data["profiles"]:
		if profile["id"] == profile_id:
			var key := "wins" if won else "losses"
			profile[key] = int(profile.get(key, 0)) + 1
			profile["updated_at"] = Time.get_datetime_string_from_system(true)
			return save_data()
	last_error = "Profile not found."
	return false


func lifetime_points(profile: Dictionary) -> int:
	var total := 0
	for points in profile.get("game_points", {}).values():
		total += int(points)
	return total


func _default_data() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "settings": DEFAULT_SETTINGS.duplicate(true), "profiles": []}


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _is_valid_root(value: Variant) -> bool:
	return value is Dictionary and value.has("schema_version") and value.has("profiles") and value["profiles"] is Array


func _migrate_and_sanitize() -> void:
	data["schema_version"] = SCHEMA_VERSION
	var settings := DEFAULT_SETTINGS.duplicate(true)
	settings.merge(data.get("settings", {}), true)
	data["settings"] = settings
	var clean_profiles: Array = []
	var used_names := {}
	for raw in data.get("profiles", []):
		if not raw is Dictionary:
			continue
		var display_name := str(raw.get("display_name", "")).strip_edges()
		var normalized := _normalize_name(display_name)
		if display_name.is_empty() or used_names.has(normalized):
			continue
		used_names[normalized] = true
		clean_profiles.append({
			"id": str(raw.get("id", _make_id())),
			"display_name": display_name.left(24),
			"normalized_name": normalized,
			"game_points": raw.get("game_points", {}) if raw.get("game_points", {}) is Dictionary else {},
			"wins": maxi(0, int(raw.get("wins", 0))),
			"losses": maxi(0, int(raw.get("losses", 0))),
			"created_at": str(raw.get("created_at", "")),
			"updated_at": str(raw.get("updated_at", ""))
		})
	data["profiles"] = clean_profiles


func _normalize_name(value: String) -> String:
	return value.strip_edges().to_lower()


func _make_id() -> String:
	var crypto := Crypto.new()
	return crypto.generate_random_bytes(16).hex_encode()
