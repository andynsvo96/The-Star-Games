extends RefCounted

const Rules = preload("res://Games/monopoly-classic/host/rules.gd")
var path := "user://monopoly-classic/session.json"
var error := ""


func _marker(id: String, kind: String) -> String:
	if id.length() != 32: return ""
	for character in id.to_utf8_buffer():
		if not character in "0123456789abcdef".to_utf8_buffer(): return ""
	return path.get_base_dir().path_join("classic-%s-%s.flag" % [id, kind])


func _mark(id: String, kind: String) -> bool:
	var target := _marker(id, kind)
	if target.is_empty(): return false
	if FileAccess.file_exists(target): return true
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null: return false
	file.store_string(kind); file.flush(); file.close()
	return true


func mark_practice(id: String) -> bool:
	return _mark(id, "practice")


func was_practice(id: String) -> bool:
	var marker := _marker(id, "practice")
	return not marker.is_empty() and FileAccess.file_exists(marker)


func mark_completed(id: String) -> bool:
	return _mark(id, "completed")


func save_game(payload: Dictionary) -> bool:
	if not valid(payload): error = "The game could not be validated for saving."; return false
	var data := JSON.stringify(payload)
	var envelope := JSON.stringify({"schema_version": 1, "data": data, "sha256": data.sha256_text()})
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: error = "The saved-game folder is unavailable."; return false
	file.store_string(envelope); file.flush(); file.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".previous"): DirAccess.remove_absolute(path + ".previous")
		if DirAccess.rename_absolute(path, path + ".previous") != OK: error = "The previous save could not be backed up."; return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		if FileAccess.file_exists(path + ".previous"): DirAccess.rename_absolute(path + ".previous", path)
		error = "The game could not be saved."; return false
	error = ""
	return true


func load_game() -> Dictionary:
	for candidate in [path, path + ".previous"]:
		if not FileAccess.file_exists(candidate): continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null or file.get_length() > 1048576: continue
		var envelope: Variant = _parse(file.get_as_text()); file.close()
		if not envelope is Dictionary or envelope.get("schema_version") != 1 or not envelope.get("data") is String or envelope.get("sha256") != str(envelope.data).sha256_text(): continue
		var payload: Variant = _parse(envelope.data)
		if payload is Dictionary and valid(payload):
			var completed := _marker(str(payload.round_id), "completed")
			if payload.rules.phase != "finished" and FileAccess.file_exists(completed): continue
			payload.practice = bool(payload.practice) or was_practice(str(payload.round_id))
			error = ""; return payload
	error = "No valid saved game is available."
	return {}


func _parse(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null


func valid(payload: Dictionary) -> bool:
	if not payload.get("round_id") is String or _marker(payload.round_id, "practice").is_empty(): return false
	if not payload.get("rules") is Dictionary or not Rules.new().import_state(payload.rules): return false
	if not payload.get("seats") is Array or payload.seats.size() != int(payload.rules.count) or not payload.get("solo") is bool or not payload.get("practice") is bool or not payload.get("results_recorded") is bool: return false
	var ids: Array = []
	for seat in payload.seats:
		if not seat is Dictionary or not seat.get("id") is String or seat.id.is_empty() or seat.id.length() > 100 or ids.has(seat.id): return false
		if not seat.get("display_name") is String or seat.display_name.length() > 80 or not seat.get("color") is String or not Color.html_is_valid(seat.color) or not Rules.whole(seat.get("pose"), 0, 5) or not seat.get("ai") is bool: return false
		if seat.ai and not payload.practice: return false
		ids.append(seat.id)
	if not payload.get("options") is Dictionary or not payload.get("clocks") is Dictionary or not payload.get("wins") is Dictionary: return false
	for id in payload.wins:
		if not id is String or not Rules.whole(payload.wins[id]): return false
	var options: Dictionary = payload.options
	for key in ["turn_timer", "game_timer"]:
		if not options.get(key) is bool: return false
	for key in ["turn_seconds", "game_seconds"]:
		if not typeof(options.get(key)) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(options[key])) or float(options[key]) < 6 or float(options[key]) > (3600 if key == "turn_seconds" else 86400): return false
	if not Rules.whole(options.get("difficulty"), 0, 2) or not ThemePacks.valid_id(str(options.get("theme", ""))): return false
	for key in ["turn", "response", "game"]:
		if not typeof(payload.clocks.get(key)) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(payload.clocks[key])) or float(payload.clocks[key]) < 0 or float(payload.clocks[key]) > 86400: return false
	if not Rules.whole(payload.clocks.get("turn_serial"), 1) or not payload.clocks.get("decision_key") is String or not Rules.whole(payload.get("autoplay_turn"), -1) or not payload.get("autoplay_decision") is String: return false
	return payload.get("results_recorded") == false or payload.rules.phase == "finished"
