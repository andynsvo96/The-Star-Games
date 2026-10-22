extends RefCounted

const DEFAULTS := "res://Games/spyfall/locations.json"
const MIN_MINUTES := 0.1
const MAX_MINUTES := 1440.0
const MAX_LOCATIONS := 200
const MAX_NAME := 60
var path := "user://spyfall/settings.json"
var minutes := 8.0
var vote_minutes := 1.0
var anonymous_voting := false
var locations: Array = []
var last_error := ""


func _init(custom_path := "") -> void:
	if not custom_path.is_empty():
		path = custom_path
	locations = JSON.parse_string(FileAccess.get_file_as_string(DEFAULTS)).locations


static func validate_names(value: Variant) -> Array:
	if not value is Array or value.size() < 2 or value.size() > MAX_LOCATIONS:
		return []
	var names: Array = []
	var seen: Array = []
	for item in value:
		if not item is String:
			return []
		var name: String = " ".join(item.strip_edges().split(" ", false))
		if name.is_empty() or name.length() > MAX_NAME or name.contains("\n") or name.contains("\r") or name.contains("\t") or seen.has(name.to_lower()):
			return []
		names.append(name)
		seen.append(name.to_lower())
	return names


func load_data() -> void:
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema_version") != 1:
		last_error = "Saved settings are invalid. Using the default locations and timer."
		return
	var names := validate_names(data.get("locations"))
	var value: Variant = data.get("timer_minutes")
	var voting_value: Variant = data.get("vote_timer_minutes", 1.0)
	var anonymous: Variant = data.get("anonymous_voting", false)
	if not anonymous is bool or names.is_empty() or not _valid_minutes(value) or not _valid_minutes(voting_value):
		last_error = "Saved settings are invalid. Using the default locations and timer."
		return
	locations = names
	minutes = float(value)
	vote_minutes = float(voting_value)
	anonymous_voting = anonymous


static func _valid_minutes(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= MIN_MINUTES and float(value) <= MAX_MINUTES


func save_data(names: Array, value: float, anonymous: Variant = null, voting_value: Variant = null) -> bool:
	last_error = ""
	var cleaned := validate_names(names)
	if anonymous == null:
		anonymous = anonymous_voting
	if voting_value == null:
		voting_value = vote_minutes
	if not anonymous is bool or cleaned.is_empty() or not _valid_minutes(value) or not _valid_minutes(voting_value):
		last_error = "Use 2–200 unique locations (up to 60 characters) and a valid timer."
		return false
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		last_error = "Could not create the Spyfall settings folder."
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Could not save Spyfall settings."
		return false
	file.store_string(JSON.stringify({"schema_version": 1, "timer_minutes": value, "vote_timer_minutes": voting_value, "locations": cleaned, "anonymous_voting": anonymous}, "\t"))
	file.flush()
	file.close()
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(absolute + ".bak")
	if FileAccess.file_exists(path) and DirAccess.rename_absolute(absolute, absolute + ".bak") != OK:
		last_error = "Could not back up Spyfall settings."
		return false
	if DirAccess.rename_absolute(absolute + ".tmp", absolute) != OK:
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.rename_absolute(absolute + ".bak", absolute)
		last_error = "Could not finish saving Spyfall settings."
		return false
	locations = cleaned
	minutes = value
	vote_minutes = float(voting_value)
	anonymous_voting = anonymous
	return true
