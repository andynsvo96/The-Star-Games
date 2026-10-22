extends RefCounted

const Rules = preload("res://Games/poker/host/rules.gd")
var path := "user://poker-texas-holdem/session.json"
var error := ""


func _marker(id: String, kind: String) -> String:
	if id.length() != 32 or not id.is_valid_hex_number(false): return ""
	return path.get_base_dir().path_join("poker-%s-%s.flag" % [id, kind])


func _mark(id: String, kind: String) -> bool:
	var target := _marker(id, kind)
	if target.is_empty(): return false
	if FileAccess.file_exists(target): return true
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null: return false
	file.store_string(kind); file.flush(); file.close(); return true


func mark_practice(id: String) -> bool: return _mark(id, "practice")
func mark_completed(id: String) -> bool: return _mark(id, "completed")
func was_practice(id: String) -> bool: return FileAccess.file_exists(_marker(id, "practice"))


func save_game(payload: Dictionary) -> bool:
	if not valid(payload): error = "The Poker session could not be validated."; return false
	var data := JSON.stringify(payload)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: error = "The Poker save folder is unavailable."; return false
	file.store_string(JSON.stringify({"schema_version": 1, "data": data, "sha256": data.sha256_text()})); file.flush(); file.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".previous"): DirAccess.remove_absolute(path + ".previous")
		if DirAccess.rename_absolute(path, path + ".previous") != OK: error = "The previous Poker save could not be backed up."; return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		if FileAccess.file_exists(path + ".previous"): DirAccess.rename_absolute(path + ".previous", path)
		error = "The Poker save could not be replaced."; return false
	error = ""; return true


func load_game() -> Dictionary:
	for candidate in [path, path + ".previous"]:
		if not FileAccess.file_exists(candidate): continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null or file.get_length() > 1048576: continue
		var json := JSON.new(); var status := json.parse(file.get_as_text()); file.close()
		if status != OK or not json.data is Dictionary: continue
		var envelope: Dictionary = json.data
		if envelope.get("schema_version") != 1 or not envelope.get("data") is String or envelope.get("sha256") != str(envelope.data).sha256_text(): continue
		if json.parse(envelope.data) != OK or not json.data is Dictionary: continue
		var payload: Dictionary = json.data
		if not valid(payload): continue
		if FileAccess.file_exists(_marker(payload.run_id, "completed")): continue
		payload.practice = bool(payload.practice) or was_practice(payload.run_id)
		error = ""; return payload
	error = "No valid unfinished Poker session is available."; return {}


func valid(payload: Dictionary) -> bool:
	if not payload.get("run_id") is String or _marker(payload.run_id, "practice").is_empty() or not payload.get("rules") is Dictionary or not Rules.new().import_state(payload.rules): return false
	if not payload.get("solo") is bool or not payload.get("practice") is bool or not payload.get("results_recorded") is bool or not payload.get("seats") is Array or payload.seats.size() != int(payload.rules.count): return false
	var identities: Array = []
	for seat in payload.seats:
		if not seat is Dictionary or not seat.get("id") is String or seat.id.is_empty() or seat.id.length() > 100 or identities.has(seat.id) or not seat.get("display_name") is String or seat.display_name.length() > 80 or not seat.get("color") is String or not Color.html_is_valid(seat.color) or not Rules.whole(seat.get("pose"), 0, 5) or not seat.get("ai") is bool: return false
		if seat.ai and not payload.practice: return false
		identities.append(seat.id)
	if not payload.get("options") is Dictionary or not Rules.valid_options(payload.options) or not payload.options.get("turn_timer") is bool: return false
	for key in ["solo_ai", "party_ai", "difficulty"]:
		if not Rules.whole(payload.options.get(key), 1 if key == "solo_ai" else 0, 2 if key == "difficulty" else 9): return false
	if not Rules.whole(payload.options.get("turn_seconds"), 5, 600): return false
	for key in ["turn_remaining", "phase_remaining", "motion_elapsed", "motion_duration"]:
		if not typeof(payload.get(key)) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(payload[key])) or float(payload[key]) < 0 or float(payload[key]) > 600: return false
	if not Rules.whole(payload.get("clock_serial"), 0) or not payload.get("wins") is Dictionary or not payload.get("motion") is Dictionary: return false
	if float(payload.turn_remaining) > float(payload.options.turn_seconds) or float(payload.motion_elapsed) > float(payload.motion_duration): return false
	for key in Rules.DEFAULTS:
		if payload.options[key] != payload.rules.options[key]: return false
	for id in payload.wins:
		if not id is String or not Rules.whole(payload.wins[id]): return false
	# Timeline data is validated before any presentation code consumes it.
	if not Rules.whole(payload.motion.get("revision")) or not payload.motion.get("flights") is Array or payload.motion.flights.size() > 60: return false
	if not typeof(payload.motion.get("shuffle")) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(payload.motion.shuffle)) or float(payload.motion.shuffle) < 0 or float(payload.motion.shuffle) > 1: return false
	if not payload.motion.get("chips") is Array or payload.motion.chips.size() > 10: return false
	for change in payload.motion.chips:
		if not change is Dictionary or not Rules.whole(change.get("seat"), 0, payload.seats.size() - 1) or not Rules.whole(change.get("amount"), 1, int(payload.rules.total_chips)) or not change.get("award") is bool: return false
	for flight in payload.motion.flights:
		if not flight is Dictionary or not flight.get("from") is Dictionary or not flight.get("to") is Dictionary or not flight.get("card") is Dictionary: return false
		for key in ["from", "to"]:
			if flight[key].get("zone") not in ["deck", "hand", "board", "pot"] or not Rules.whole(flight[key].get("seat", 0), 0, 9) or not Rules.whole(flight[key].get("index", 0), 0, 4): return false
		for key in ["delay", "duration"]:
			if not typeof(flight.get(key)) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(flight[key])) or float(flight[key]) < 0 or float(flight[key]) > 10: return false
		if flight.card.get("back", false) != true and not Rules.whole(flight.card.get("id"), 0, 51): return false
	return not payload.results_recorded or payload.rules.phase == "finished"
