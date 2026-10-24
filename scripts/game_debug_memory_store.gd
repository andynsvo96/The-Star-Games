class_name GameDebugMemoryStore
extends RefCounted

# Optional stand-in for module-owned resumable sessions. Each debug launch starts
# fresh; no checkpoint or eligibility marker reaches user://.
var path := "memory://debug"
var error := ""
var _practice: Dictionary = {}
var _completed: Dictionary = {}

func load_game() -> Dictionary: return {}
func save_game(_payload: Dictionary) -> bool: return true
func mark_practice(id: String) -> bool:
	_practice[id] = true
	return true
func was_practice(id: String) -> bool: return _practice.has(id)
func mark_completed(id: String) -> bool:
	_completed[id] = true
	return true
