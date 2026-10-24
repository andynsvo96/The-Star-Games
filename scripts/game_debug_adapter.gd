class_name GameDebugAdapter
extends RefCounted

# Module-owned host/debug.gd scripts extend this contract. They choose legal
# inputs from a player's permitted view, then use the ordinary host handlers.
# No game IDs or rules belong in the runner.
var game: BaseGame


static func for_game(manifest: Dictionary) -> GameDebugAdapter:
	var path := str(manifest.get("folder", "")).path_join("host/debug.gd")
	if not ResourceLoader.exists(path): return null
	var script := load(path) as Script
	if script == null or not script.can_instantiate(): return null
	var instance: Variant = script.new()
	if instance is GameDebugAdapter: return instance
	if instance is Node: instance.free()
	return null


func player_counts(manifest: Dictionary) -> Array:
	if manifest.get("modes", []).has("multiplayer"):
		return range(int(manifest.min_players), int(manifest.max_players) + 1)
	return [1]


func description() -> String:
	return ""


# Adapters can narrow the catalog range, never expand its admitted party limits.
func supported_counts(manifest: Dictionary) -> Array:
	var counts: Array = []
	var party: bool = manifest.get("modes", []).has("multiplayer")
	for value: Variant in player_counts(manifest):
		if not value is int or value < 1 or value > 16 or counts.has(value): continue
		if party and (value < int(manifest.min_players) or value > int(manifest.max_players)): continue
		if not party and value != 1: continue
		counts.append(value)
	counts.sort()
	return counts


# Runs before initialize_session. Replace module-owned persistent stores here
# with in-memory implementations, and configure an exact test lineup.
func prepare(_context: GameSessionContext) -> void:
	pass


func is_complete() -> bool:
	return false


# A public progress token, never secret cards/roles/answers. Include intermediate
# phases so simultaneous decisions and timer transitions count as progress.
func progress() -> String:
	return ""


# One bounded decision; return false when waiting for motion or a timer.
func step(_rng: RandomNumberGenerator) -> bool:
	return false


func submit(player_id: String, message: Dictionary) -> bool:
	var before := progress()
	game.handle_controller_message(player_id, message)
	return progress() != before
