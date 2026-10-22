extends Node

# Board geometry stays module-owned; buttons and authoritative state never move.
signal landed(step: Dictionary, outcome: int)
signal settled
var cells: Array[Button] = []
var pieces: Array[TextureRect] = []
var textures: Array = []
var visual_parent: Control
var displayed: Array = []
var queue: Array[Dictionary] = []
var moving_piece: TextureRect
var tween: Tween
var busy := false


func reset(board: Array) -> void:
	if tween != null:
		tween.kill()
		tween = null
	if is_instance_valid(moving_piece):
		moving_piece.free()
	queue.clear()
	busy = false
	_paint(board)


func _paint(board: Array) -> void:
	displayed = board.duplicate()
	for cell in 64:
		pieces[cell].texture = null if board[cell] == 0 else textures[board[cell] - 1]


func enqueue(board: Array, step: Dictionary, piece: int, outcome: int) -> void:
	queue.append({"board": board.duplicate(), "step": step.duplicate(), "piece": piece, "outcome": outcome})
	if not busy:
		_start_next()


func _start_next() -> void:
	if queue.is_empty():
		busy = false
		settled.emit()
		return
	busy = true
	var move := queue.pop_front() as Dictionary
	var step: Dictionary = move.step
	pieces[step.from].texture = null
	moving_piece = TextureRect.new()
	moving_piece.texture = textures[move.piece - 1]
	moving_piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	moving_piece.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moving_piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moving_piece.z_index = 4
	visual_parent.add_child(moving_piece)
	var travel := func(progress: float) -> void:
		var start := pieces[step.from].global_position
		var finish := pieces[step.to].global_position
		var lift := sin(progress * PI) * pieces[step.to].size.y * (0.28 if step.capture >= 0 else 0.05)
		moving_piece.size = pieces[step.to].size
		moving_piece.global_position = start.lerp(finish, progress) - Vector2(0, lift)
		if step.capture >= 0 and progress >= 0.6:
			pieces[step.capture].texture = null
	travel.call(0.0)
	tween = create_tween()
	tween.tween_method(travel, 0.0, 1.0, 0.40 if step.capture >= 0 else 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func() -> void:
		moving_piece.free()
		tween = null
		_paint(move.board)
		landed.emit(step, move.outcome)
		_start_next()
	)
