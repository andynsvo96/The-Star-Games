extends Node

signal settled
var cells: Array[Button] = []
var pieces: Array[TextureRect] = []
var visual_parent: Control
var textures: Dictionary = {}
var tween: Tween
var sprites: Array[TextureRect] = []
var busy := false


func reset(board: Array) -> void:
	if tween != null:
		tween.kill()
		tween = null
	for sprite in sprites:
		if is_instance_valid(sprite):
			sprite.free()
	sprites.clear()
	busy = false
	for cell in 64:
		pieces[cell].texture = textures.get(board[cell])


func play(previous: Array, board: Array, step: Dictionary) -> void:
	reset(previous)
	busy = true
	var travels: Array[Dictionary] = [{"from": step.from, "to": step.to}]
	if step.has("rook_from"):
		travels.append({"from": step.rook_from, "to": step.rook_to})
	for travel in travels:
		pieces[travel.from].texture = null
		var sprite := TextureRect.new()
		sprite.texture = textures[previous[travel.from]]
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.z_index = 4
		visual_parent.add_child(sprite)
		sprites.append(sprite)
	var progress := func(t: float) -> void:
		for index in travels.size():
			var travel: Dictionary = travels[index]
			var start := pieces[travel.from].global_position
			var finish := pieces[travel.to].global_position
			sprites[index].size = pieces[travel.to].size
			sprites[index].global_position = start.lerp(finish, t) - Vector2(0, sin(t * PI) * pieces[travel.to].size.y * 0.08)
		if step.capture >= 0 and t >= 0.6:
			pieces[step.capture].texture = null
	progress.call(0.0)
	tween = create_tween()
	tween.tween_method(progress, 0.0, 1.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func() -> void:
		reset(board)
		settled.emit()
	)
