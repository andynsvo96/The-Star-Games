extends Control

# Only board artwork moves. The cell buttons stay fixed and focusable.
signal cell_pressed(cell: int)
signal ship_held(cell: int)
const ART_SIZE := Vector2(424, 456)
const ASPECT := 456.0 / 424.0
const HOLD_SECONDS := 0.45
var SHIP := RuntimeAssets.texture("res://Games/battleship/art/ship.png")
var MISS := RuntimeAssets.texture("res://Games/battleship/art/miss.svg")
var HIT := RuntimeAssets.texture("res://Games/battleship/art/hit.svg")
var CANNON := RuntimeAssets.texture("res://Games/battleship/art/cannon.svg")
var frame: Texture2D
var caption := "PLAYER FLEET"
var fleet: Array = []
var incoming: Array = []
var buttons: Array[Button] = []
var poses: Array[Control] = []
var reduced_motion := false
var editable := false
var selected_ship := 0
var vertical := false
var preview := -1
var placement_left := 0.0
var shot: Dictionary = {}
var shot_age := 2.0
var source_cannon := false
var placement_ages: Dictionary = {}
var newly_revealed: Array = []
var hold_cell := -1
var hold_age := 0.0
var hold_fired := false
var suppress_cell := -1
var hold_origin := Vector2.ZERO


func _init() -> void:
	incoming.resize(100)
	incoming.fill(0)
	frame = RuntimeAssets.texture("res://Games/battleship/art/board-blue-v2.svg")
	for index in 5:
		var pose := Control.new()
		pose.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pose)
		poses.append(pose)
	for cell in 100:
		var button := Button.new()
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", GameLook.box(Color.TRANSPARENT, Color.WHITE, 3, 2))
		button.pressed.connect(func() -> void:
			if suppress_cell != cell:
				cell_pressed.emit(cell)
		)
		button.button_down.connect(func() -> void: _begin_hold(cell))
		button.button_up.connect(_end_hold)
		button.gui_input.connect(_hold_motion)
		button.mouse_entered.connect(func() -> void: preview = cell; queue_redraw())
		button.mouse_exited.connect(func() -> void: preview = -1; _cancel_hold(); queue_redraw())
		button.focus_entered.connect(func() -> void: preview = cell; queue_redraw())
		button.focus_exited.connect(func() -> void: preview = -1; queue_redraw())
		add_child(button)
		buttons.append(button)
	resized.connect(_layout_cells)


func field_rect() -> Rect2:
	var scale := size.x / ART_SIZE.x
	return Rect2(Vector2(56, 94) * scale, Vector2(320, 320) * scale)


func coordinate_rect(index: int, column: bool) -> Rect2:
	var scale := size.x / ART_SIZE.x
	return Rect2(Vector2(56 + index * 32, 66) * scale, Vector2(32, 22) * scale) if column else Rect2(Vector2(28, 94 + index * 32) * scale, Vector2(26, 32) * scale)


func _begin_hold(cell: int) -> void:
	if not editable or buttons[cell].disabled:
		return
	hold_cell = cell
	hold_age = 0.0
	hold_fired = false
	suppress_cell = -1
	hold_origin = get_global_mouse_position()
	preview = cell


func _hold_motion(event: InputEvent) -> void:
	if hold_cell < 0:
		return
	if event is InputEventMouseMotion and event.global_position.distance_to(hold_origin) > 12:
		_cancel_hold()
	elif event is InputEventScreenDrag and event.position.distance_to(hold_origin) > 12:
		_cancel_hold()


func _cancel_hold() -> void:
	if hold_cell >= 0:
		suppress_cell = hold_cell
	hold_cell = -1
	queue_redraw()


func _end_hold() -> void:
	hold_cell = -1
	_reset_suppression.call_deferred()
	queue_redraw()


func _reset_suppression() -> void:
	suppress_cell = -1


func cell_center(cell: int) -> Vector2:
	var field := field_rect()
	return field.position + Vector2(cell % 10 + 0.5, int(cell / 10) + 0.5) * field.size / 10.0


func _layout_cells() -> void:
	var field := field_rect()
	for cell in 100:
		buttons[cell].position = field.position + Vector2(cell % 10, int(cell / 10)) * field.size / 10.0
		buttons[cell].size = field.size / 10.0
	queue_redraw()


func set_view(ships: Array, marks: Array, title: String, red: bool, active: bool, setup: bool, selection: int, upright: bool, reduced: bool, moving := false) -> void:
	var previous := fleet.duplicate(true)
	fleet = ships.duplicate(true)
	incoming = marks.duplicate()
	caption = title
	frame = RuntimeAssets.texture("res://Games/battleship/art/board-%s-v2.svg" % ("red" if red else "blue"))
	editable = setup
	selected_ship = selection
	vertical = upright
	reduced_motion = reduced
	if not moving:
		newly_revealed.clear()
	for cell in 100:
		buttons[cell].disabled = not active or (not setup and incoming[cell] != 0)
	if not setup or not active:
		_end_hold()
	for placement in fleet:
		var old := previous.filter(func(p: Dictionary) -> bool: return p.ship == placement.ship)
		if not old.is_empty() and old[0] == placement:
			continue
		if moving and old.is_empty() and placement.cells.all(func(cell: int) -> bool: return incoming[cell] == 3) and not newly_revealed.has(placement.ship):
			newly_revealed.append(placement.ship)
		if setup:
			GameMotion.play(poses[placement.ship], reduced_motion, true)
			placement_left = 0.6 if not reduced_motion else 0.0
			if not reduced_motion:
				placement_ages[placement.ship] = 0.0
	queue_redraw()


func animate_fire(event: Dictionary, source: bool) -> void:
	shot = event.duplicate()
	source_cannon = source
	shot_age = 2.0 if reduced_motion else 0.0
	queue_redraw()


func clear_motion() -> void:
	shot = {}
	shot_age = 2.0
	placement_left = 0.0
	placement_ages.clear()
	newly_revealed.clear()
	preview = -1
	_end_hold()
	for pose in poses:
		GameMotion.reset(pose)
	queue_redraw()


func _process(delta: float) -> void:
	if hold_cell >= 0 and not hold_fired:
		hold_age += delta
		if hold_age >= HOLD_SECONDS:
			hold_fired = true
			suppress_cell = hold_cell
			ship_held.emit(hold_cell)
		queue_redraw()
	if reduced_motion and (shot_age < 1.25 or placement_left > 0):
		clear_motion()
	if placement_left > 0:
		placement_left = maxf(0.0, placement_left - delta)
		for ship in placement_ages.keys():
			placement_ages[ship] += delta
			if placement_ages[ship] >= 0.6:
				placement_ages.erase(ship)
		queue_redraw()
	if shot_age < 1.25:
		shot_age += delta
		queue_redraw()


func _draw() -> void:
	draw_texture_rect(frame, Rect2(Vector2.ZERO, size), false)
	var field := field_rect()
	var edge := field.size.x / 10.0
	var font := get_theme_font("font", "Label")
	var scale := size.x / ART_SIZE.x
	var font_size := maxi(7, int(18 * scale))
	var title_size := maxi(6, int(18 * scale))
	var text_width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var title_baseline := 29.5 * scale + (font.get_ascent(title_size) - font.get_descent(title_size)) / 2
	draw_string(font, Vector2((size.x - text_width) / 2.0 + 10 * scale, title_baseline), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color.WHITE)
	for cell in 100:
		var rect := Rect2(field.position + Vector2(cell % 10, int(cell / 10)) * edge, Vector2.ONE * edge)
		var shade := Color("008bbf") if (cell + int(cell / 10)) % 2 == 0 else Color("0075ab")
		draw_rect(rect, shade)
		var wave_y := rect.position.y + edge * (0.3 + fmod(cell * 0.173, 0.45))
		draw_polyline(PackedVector2Array([Vector2(rect.position.x, wave_y + edge * 0.1), Vector2(rect.position.x + edge * 0.4, wave_y), Vector2(rect.end.x, wave_y + edge * 0.12)]), Color("14cde33b"), maxf(1, edge * 0.09), true)
		draw_rect(rect, Color("57e7f1"), false, maxf(1, edge * 0.035))
	for index in 10:
		for column in [true, false]:
			var text := String.chr(65 + index) if column else str(index + 1)
			var rect := coordinate_rect(index, column)
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var baseline := (font.get_ascent(font_size) - font.get_descent(font_size)) / 2
			draw_string(font, rect.get_center() + Vector2(-width / 2, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	for placement in fleet:
		var just_sunk: bool = not shot.is_empty() and not source_cannon and shot.result == 3 and placement.cells.has(shot.cell)
		var waiting_impact := just_sunk and shot_age < 0.48
		if waiting_impact and newly_revealed.has(placement.ship):
			continue
		var sunk: bool = not waiting_impact and placement.cells.all(func(cell: int) -> bool: return incoming[cell] == 3)
		var from := cell_center(placement.cell)
		var direction := Vector2.DOWN if placement.vertical else Vector2.RIGHT
		var center: Vector2 = from + direction * edge * (placement.length - 1) / 2.0
		var sinking := sin((shot_age - 0.48) / 0.77 * PI) if just_sunk and shot_age >= 0.48 and shot_age < 1.25 else 0.0
		center.y += edge * 0.2 * sinking
		var pose := poses[placement.ship]
		var landing: float = 1.0 - float(placement_ages.get(placement.ship, 0.6)) / 0.6
		var offset := Vector2(0, -edge * 0.5 * landing * landing)
		if landing > 0:
			draw_arc(center, edge * (0.3 + (1.0 - landing) * 1.5), 0, TAU, 24, Color(0.8, 1, 1, landing * 0.5), maxf(1.5, edge * 0.04), true)
		var rotation := PI / 2.0 if placement.vertical else 0.0
		draw_set_transform(center + offset, rotation + pose.rotation + sinking * 0.09, pose.scale)
		var ship_size := Vector2(edge * (placement.length - 0.12), edge * 0.95)
		draw_texture_rect(SHIP, Rect2(-ship_size / 2.0, ship_size), false, Color("8795a8") if sunk else Color.WHITE)
		draw_set_transform(Vector2.ZERO)
		if sunk:
			for cell in placement.cells:
				draw_rect(Rect2(cell_center(cell) - Vector2.ONE * edge * 0.46, Vector2.ONE * edge * 0.92), Color("ffcd55"), false, maxf(1.5, edge * 0.06))
	for cell in 100:
		var mark: int = incoming[cell]
		if not source_cannon and not shot.is_empty() and shot.cell == cell and shot_age < 0.48:
			mark = 0
		if mark != 0:
			var marker := MISS if mark == 1 else HIT
			draw_texture_rect(marker, Rect2(cell_center(cell) - Vector2.ONE * edge * 0.42, Vector2.ONE * edge * 0.84), false)
	if editable and preview >= 0 and not buttons[preview].disabled:
		var rules = preload("res://Games/battleship/host/rules.gd")
		var valid: bool = rules.can_place(fleet, selected_ship, preview, vertical)
		for cell in rules.ship_cells(preview, rules.LENGTHS[selected_ship], vertical):
			draw_rect(Rect2(cell_center(cell) - Vector2.ONE * edge * 0.48, Vector2.ONE * edge * 0.96), Color(0.4, 1, 0.4, 0.5) if valid else Color(1, 0.2, 0.2, 0.55))
	if hold_cell >= 0 and not hold_fired:
		draw_arc(cell_center(hold_cell), edge * 0.35, -PI / 2, -PI / 2 + TAU * minf(1, hold_age / HOLD_SECONDS), 24, Color.WHITE, maxf(2, edge * 0.07), true)
	_draw_fire(edge)


func _draw_fire(edge: float) -> void:
	var scale := size.x / ART_SIZE.x
	var gun := Vector2(30, 12) * scale
	var recoil := sin(minf(1.0, shot_age / 0.30) * PI) * edge * 0.16 if source_cannon and shot_age < 0.30 else 0.0
	draw_texture_rect(CANNON, Rect2(gun - Vector2(recoil, 0), Vector2.ONE * 36 * scale), false)
	if shot.is_empty() or shot_age >= 1.25:
		return
	if source_cannon:
		if shot_age < 0.24:
			_draw_burst(gun + Vector2(35, 5) * scale, edge * (0.25 + shot_age * 4), Color("ffdc4f"), 1.0 - shot_age / 0.24)
		return
	var target := cell_center(shot.cell)
	if shot_age < 0.48:
		var t := shot_age / 0.48
		var origin := Vector2(size.x * 0.07, size.x * 0.12)
		var position := origin.lerp(target, t) + Vector2(0, -sin(t * PI) * size.x * 0.22)
		draw_line(position - Vector2(edge * 0.55, -edge * 0.5), position, Color("fff5ac"), maxf(2, edge * 0.10), true)
		draw_circle(position, maxf(3, edge * 0.12), Color("262c3f"))
		return
	var elapsed := shot_age - 0.48
	var fade := 1.0 - elapsed / 0.77
	if shot.result == 1:
		draw_arc(target, edge * (0.22 + elapsed * 2.2), 0, TAU, 32, Color(0.8, 1, 1, fade), maxf(2, edge * 0.06), true)
		for index in 8:
			var direction := Vector2.from_angle(index * TAU / 8)
			var position := target + direction * edge * elapsed * 2 + Vector2(0, -edge * sin(elapsed * PI / 0.77) * 0.65)
			draw_circle(position, maxf(2, edge * 0.065), Color(0.8, 1, 1, fade))
	else:
		_draw_burst(target, edge * (0.45 + elapsed * 1.4) * (1.3 if shot.result == 3 else 1.0), Color("ffad18"), fade)
		_draw_burst(target, edge * (0.22 + elapsed * 0.75), Color("fff2a3"), fade)
		for index in 5:
			var position := target + Vector2((index - 2) * edge * 0.19, -elapsed * edge * (0.7 + index * 0.22))
			draw_circle(position, edge * (0.09 + elapsed * 0.15), Color(0.15, 0.20, 0.28, fade * 0.5))


func _draw_burst(center: Vector2, radius: float, color: Color, opacity: float) -> void:
	var points := PackedVector2Array()
	for index in 20:
		points.append(center + Vector2.from_angle(index * TAU / 20) * radius * (1.0 if index % 2 == 0 else 0.42))
	color.a = clampf(opacity, 0.0, 1.0)
	draw_colored_polygon(points, color)
