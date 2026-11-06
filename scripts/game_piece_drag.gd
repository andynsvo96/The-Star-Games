class_name GamePieceDrag
extends Node

# Presentation only. A drop goes through the module's ordinary validated move.
var surface: Control
var callbacks: Dictionary
var source := -1
var origin := Vector2.ZERO
var pointer := -2
var dragging := false
var suppress_click := false
var token: Variant
var preview: Control


func configure(board: Control, handlers: Dictionary) -> void:
	surface = board
	callbacks = handlers
	board.resized.connect(cancel)
	board.get_window().focus_exited.connect(cancel)


func blocks_click() -> bool:
	return dragging or suppress_click


func _input(event: InputEvent) -> void:
	if surface == null: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: begin(event.position, -1)
		elif pointer == -1: finish(event.position)
	elif event is InputEventMouseMotion and pointer == -1:
		move_pointer(event.position)
	elif event is InputEventScreenTouch:
		if event.canceled: cancel()
		elif event.pressed: begin(event.position, event.index)
		elif pointer == event.index: finish(event.position)
	elif event is InputEventScreenDrag and pointer == event.index:
		move_pointer(event.position)


func begin(point: Vector2, id := -1) -> void:
	if source >= 0 and id >= 0 and pointer >= 0 and id != pointer:
		cancel()
		return
	if source >= 0 or not surface.is_visible_in_tree(): return
	var cell: int = callbacks.hit_test.call(point)
	if cell < 0 or not callbacks.can_start.call(cell): return
	source = cell; pointer = id; origin = point
	token = callbacks.revision.call()


func move_pointer(point: Vector2) -> void:
	if not _valid(): cancel(); return
	if not dragging and point.distance_to(origin) >= 8:
		dragging = true
		preview = callbacks.make_preview.call(source)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Stay inside the board's drawing layer, below every shared modal.
		surface.add_child(preview)
		if callbacks.has("start"): callbacks.start.call(source)
	if dragging:
		preview.global_position = point - preview.size / 2
		get_viewport().set_input_as_handled()


func finish(point: Vector2) -> void:
	if source < 0: return
	var from := source
	var to: int = callbacks.hit_test.call(point)
	var commit := dragging and _valid() and to >= 0 and to != from
	_clear()
	if commit: callbacks.drop.call(from, to)


func _valid() -> bool:
	return source >= 0 and surface.is_visible_in_tree() and token == callbacks.revision.call() and callbacks.can_start.call(source)


func _process(_delta: float) -> void:
	if source >= 0 and not _valid(): cancel()


func cancel() -> void:
	if source >= 0: _clear()


func _clear() -> void:
	var from := source
	var was_dragging := dragging
	source = -1; pointer = -2; dragging = false
	if is_instance_valid(preview): preview.queue_free()
	if was_dragging:
		suppress_click = true
		if callbacks.has("end"): callbacks.end.call(from)
		_clear_suppression.call_deferred()


func _clear_suppression() -> void:
	suppress_click = false
