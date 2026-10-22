extends Control

signal cell_pressed(cell: int)
signal anchor_pressed(row: int, col: int)
signal settled
var pawns: Array = [76, 4]
var walls: Array = []
var colors: Array = [Color("25b3ab"), Color("e8794b")]
var legal: Array = []
var legal_anchors: Array = []
var preview: Dictionary = {}
var wall_mode := false
var playable := false
var outcome := 0
var cells: Array[Button] = []
var anchors: Array[Button] = []
var pawn_art := RuntimeAssets.texture("res://Games/quoridor/art/pawn-polished.svg")
var frame_art := RuntimeAssets.texture("res://Games/quoridor/art/board-frame.svg")
var tile_art := RuntimeAssets.texture("res://Games/quoridor/art/tile.svg")
var pawn_highlight := RuntimeAssets.texture("res://Games/quoridor/art/pawn-highlight.svg")
var visuals: Array[Control] = []
var motion: Tween
var busy := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cell in 81:
		var button := _target()
		button.pressed.connect(func() -> void: cell_pressed.emit(cell))
		cells.append(button)
	for row in 8:
		for col in 8:
			var button := _target()
			button.pressed.connect(func() -> void: anchor_pressed.emit(row, col))
			anchors.append(button)
	for side in 4:
		var visual := Control.new()
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(visual)
		for texture in [pawn_art, pawn_highlight]:
			var layer := TextureRect.new()
			layer.texture = texture
			layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			visual.add_child(layer)
		visuals.append(visual)
		visual.visible = side < pawns.size()
	resized.connect(_layout)
	_layout()


func _target() -> Button:
	var button := Button.new()
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", GameLook.box(Color.TRANSPARENT, Color("fff2bc"), 3, 2))
	add_child(button)
	return button


func _geometry() -> Vector3:
	var edge := minf(size.x, size.y)
	var inset := edge * 0.055
	var pitch := (edge - inset * 2) / 9.0
	return Vector3(inset, pitch, pitch * 0.06)


func _cell_rect(cell: int) -> Rect2:
	var g := _geometry()
	return Rect2(Vector2(g.x + cell % 9 * g.y + g.z / 2, g.x + int(cell / 9) * g.y + g.z / 2), Vector2.ONE * (g.y - g.z))


func _wall_rect(wall: Dictionary) -> Rect2:
	var g := _geometry()
	var junction := Vector2(g.x + (wall.col + 1) * g.y, g.x + (wall.row + 1) * g.y)
	var thickness := maxf(6, g.y * 0.30)
	return Rect2(junction - Vector2(g.y - g.z / 2, thickness / 2), Vector2(2 * g.y - g.z, thickness)) if wall.orientation == "h" else Rect2(junction - Vector2(thickness / 2, g.y - g.z / 2), Vector2(thickness, 2 * g.y - g.z))


func _layout() -> void:
	if cells.is_empty():
		return
	settle_motion()
	var g := _geometry()
	for cell in 81:
		cells[cell].position = _cell_rect(cell).position
		cells[cell].size = _cell_rect(cell).size
	for row in 8:
		for col in 8:
			var button := anchors[row * 8 + col]
			button.position = Vector2(g.x + (col + 0.5) * g.y, g.x + (row + 0.5) * g.y)
			button.size = Vector2.ONE * g.y
	_update_targets()


func _update_targets() -> void:
	for cell in 81:
		cells[cell].disabled = not playable or busy or wall_mode or not legal.has(cell)
		cells[cell].mouse_filter = Control.MOUSE_FILTER_IGNORE if wall_mode else Control.MOUSE_FILTER_STOP
	for row in 8:
		for col in 8:
			var button := anchors[row * 8 + col]
			button.visible = wall_mode
			button.disabled = not playable or busy or not legal_anchors.any(func(wall: Dictionary) -> bool: return wall.row == row and wall.col == col)
	for side in visuals.size():
		visuals[side].visible = side < pawns.size()
		if side >= pawns.size():
			continue
		visuals[side].get_child(0).modulate = colors[side]
		if not busy:
			visuals[side].position = _cell_rect(pawns[side]).position
			visuals[side].size = _cell_rect(pawns[side]).size
	queue_redraw()


func settle_motion() -> void:
	if motion != null and motion.is_valid():
		motion.kill()
	busy = false
	if visuals.size() >= pawns.size():
		for side in pawns.size():
			visuals[side].position = _cell_rect(pawns[side]).position
			visuals[side].size = _cell_rect(pawns[side]).size


func update_view(state: Dictionary, can_play: bool, use_wall: bool, anchors_for_orientation: Array, candidate: Dictionary, animate: bool) -> void:
	var before := pawns.duplicate()
	pawns = state.pawns.duplicate()
	walls = state.walls.duplicate(true)
	colors = state.players.map(func(player: Dictionary) -> Color: return Color(str(player.color)))
	legal = state.legal_moves
	legal_anchors = anchors_for_orientation
	preview = candidate.duplicate()
	outcome = state.outcome
	wall_mode = use_wall
	playable = can_play
	var changed := before != pawns
	if changed and animate and not state.last_action.is_empty() and state.last_action.action == "move":
		settle_motion()
		busy = true
		var side: int = state.last_action.side - 1
		visuals[side].position = _cell_rect(state.last_action.from).position
		visuals[side].size = _cell_rect(state.last_action.from).size
		motion = create_tween()
		motion.tween_property(visuals[side], "position", _cell_rect(pawns[side]).position, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		motion.finished.connect(func() -> void:
			busy = false
			_update_targets()
			settled.emit()
		)
	elif changed:
		settle_motion()
	_update_targets()


func _draw() -> void:
	if frame_art != null:
		draw_texture_rect(frame_art, Rect2(Vector2.ZERO, size), false)
	var g := _geometry()
	for cell in 81:
		var rect := _cell_rect(cell)
		var tone := 0.98 + float((cell * 17 + int(cell / 9) * 3) % 7) * 0.006
		draw_texture_rect(tile_art, rect, false, Color(tone, tone, tone))
		if playable and not wall_mode and not busy and legal.has(cell):
			draw_circle(rect.get_center(), g.y * 0.13, Color("53afa1"))
	for goal in [0, 8]:
		var y: float = g.x + (0 if goal == 0 else 9) * g.y
		var height := maxf(2, g.y * 0.075)
		for col in 9:
			var marker := Rect2(Vector2(g.x + col * g.y + g.z / 2, y - height / 2), Vector2(g.y - g.z, height))
			draw_rect(marker, Color("d7a13d"))
			draw_line(marker.position, Vector2(marker.end.x, marker.position.y), Color("ffe7a0"), 1)
	if pawns.size() == 4:
		for edge in [0, 9]:
			var x: float = g.x + edge * g.y
			var width := maxf(2, g.y * 0.075)
			for row in 9:
				var marker := Rect2(Vector2(x - width / 2, g.x + row * g.y + g.z / 2), Vector2(width, g.y - g.z))
				draw_rect(marker, Color("d7a13d"))
				draw_line(marker.position, Vector2(marker.position.x, marker.end.y), Color("ffe7a0"), 1)
	for wall in walls:
		_draw_wall(_wall_rect(wall), false)
	if wall_mode:
		for row in 8:
			for col in 8:
				var point := Vector2(g.x + (col + 1) * g.y, g.x + (row + 1) * g.y)
				var enabled := not anchors[row * 8 + col].disabled
				draw_circle(point, maxf(2, g.y * 0.075), Color("ffe1a0") if enabled else Color("9a9da1"))
	if not preview.is_empty() and playable:
		_draw_wall(_wall_rect(preview), true)
	if outcome > 0 and outcome <= pawns.size():
		draw_style_box(GameLook.box(Color.TRANSPARENT, Color("ffde55"), 5, 3), _cell_rect(pawns[outcome - 1]).grow(2))


func _draw_wall(rect: Rect2, ghost: bool) -> void:
	var fill := Color("8faa76") if ghost else Color("854c27")
	var bevel := maxf(1.5, minf(rect.size.x, rect.size.y) * 0.2)
	draw_style_box(GameLook.box(Color("28150c99"), Color.TRANSPARENT, 3), Rect2(rect.position + Vector2(2, 4), rect.size))
	draw_style_box(GameLook.box(fill, Color("fff0ad") if ghost else Color("3c2415"), 3, 1), rect)
	draw_line(rect.position + Vector2(2, bevel), Vector2(rect.end.x - 2, rect.position.y + bevel), Color("e8cf9d") if ghost else Color("d9a565"), bevel)
	draw_line(rect.position + Vector2(bevel, 2), Vector2(rect.position.x + bevel, rect.end.y - 2), fill.lightened(0.35), bevel)
	draw_line(Vector2(rect.position.x + 2, rect.end.y - bevel), rect.end - Vector2(2, bevel), fill.darkened(0.4), bevel)
