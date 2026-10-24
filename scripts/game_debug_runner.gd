class_name GameDebugRunner
extends Node

signal changed

const MAX_ACTIONS := 20000
const STALL_SECONDS := 30.0
var adapter: GameDebugAdapter
var interval := 0.25
var actions := 0
var state := "stopped"
var rng := RandomNumberGenerator.new()
var _elapsed := 0.0
var _idle := 0.0
var _progress := ""


static func players(count: int) -> Array:
	var roster: Array = []
	for index in clampi(count, 1, 16):
		var id := "debug-player-%02d" % (index + 1)
		roster.append({"id": id, "profile_id": id, "display_name": "Test Player %d" % (index + 1), "color": LanServer.PLAYER_COLORS[index], "pose": index % 6, "connected": true})
	return roster


func start(driver: GameDebugAdapter, delay := 0.25) -> void:
	adapter = driver
	interval = clampf(delay, 0.05, 3.0) if is_finite(delay) else 0.25
	actions = 0; _elapsed = 0.0; _idle = 0.0
	rng.randomize()
	_progress = adapter.progress()
	state = "completed" if adapter.is_complete() else "running"
	changed.emit()


func stop() -> void:
	state = "stopped"
	adapter = null
	changed.emit()


func toggle_pause() -> void:
	if state not in ["running", "paused", "stalled"]: return
	state = "paused" if state == "running" else "running"
	_idle = 0.0; _elapsed = 0.0
	changed.emit()


func step_once() -> void:
	if state in ["paused", "stalled"]: _step()


func _process(delta: float) -> void:
	if adapter == null or not is_instance_valid(adapter.game) or not adapter.game.is_inside_tree():
		if state != "stopped": stop()
		return
	# An explicit game replay or Apply may create another board after completion.
	# Leave it ready for inspection until the host chooses Resume bots.
	if state == "completed" and not adapter.is_complete():
		state = "paused"; actions = 0; _elapsed = 0.0; _idle = 0.0
		_progress = adapter.progress()
		changed.emit()
	if state != "running": return
	var token := adapter.progress()
	if token != _progress:
		_progress = token; _idle = 0.0
	else: _idle += delta
	if adapter.is_complete():
		state = "completed"; changed.emit(); return
	if _idle >= STALL_SECONDS:
		state = "stalled"; changed.emit(); return
	_elapsed += delta
	if _elapsed >= interval:
		_elapsed = 0.0
		_step()


func _step() -> void:
	if adapter == null or not is_instance_valid(adapter.game): return
	if adapter.is_complete(): state = "completed"
	else:
		var before := adapter.progress()
		var accepted := adapter.step(rng)
		if accepted:
			actions += 1; _idle = 0.0
		if adapter.progress() != before:
			_progress = adapter.progress(); _idle = 0.0
		if adapter.is_complete(): state = "completed"
		elif actions >= MAX_ACTIONS: state = "limit reached"
	changed.emit()
