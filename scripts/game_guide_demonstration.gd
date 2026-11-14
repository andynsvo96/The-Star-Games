class_name GameGuideDemonstration
extends VBoxContainer

# Offline presentation data only; demonstrations never read or change a game.
var record: Dictionary = {}
var sprites: Array = []
var starts: Array = []
var targets: Array = []
var textures: Dictionary = {}
var paths: Dictionary = {}
var fades: Dictionary = {}
var step := 0
var elapsed := 0.0
var playing := true
var reduced_motion := false
var stage: Button
var focus_frame: StyleBoxFlat


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	stage = Button.new()
	stage.flat = true
	stage.toggle_mode = true
	stage.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_frame = GameLook.box(Color.TRANSPARENT, GameLook.GOLD, 4, 2)
	focus_frame.shadow_size = 0
	focus_frame.draw_center = false
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]: stage.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	stage.custom_minimum_size = Vector2(0, 220)
	stage.draw.connect(_paint)
	stage.resized.connect(stage.queue_redraw)
	stage.pressed.connect(toggle_playing)
	add_child(stage)


func set_demonstration(value: Dictionary) -> void:
	if value == record: return
	record = value.duplicate(true)
	stage.accessibility_name = str(record.get("description", "Move demonstration")) + ". Pause or play animation."
	reload_artwork()
	restart()


func reload_artwork() -> void:
	textures.clear()
	for sprite in record.get("sprites", []): _texture(str(sprite.get("image", "")))
	_texture(str(record.get("background", "")))
	for instruction in record.get("steps", []):
		for move in instruction.get("moves", []):
			if move.has("image"): _texture(str(move.image))
	if stage != null: stage.queue_redraw()


func _texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path] = RuntimeAssets.texture(path) if not path.is_empty() else null
	return textures[path]


func restart() -> void:
	playing = true
	stage.set_pressed_no_signal(false)
	_begin_step(0)


func toggle_playing() -> void:
	playing = not playing
	stage.set_pressed_no_signal(not playing)
	stage.queue_redraw()


func aspect_ratio() -> float:
	if record.has("aspect"): return maxf(.2, float(record.aspect))
	var background := _texture(str(record.get("background", "")))
	return float(background.get_width()) / background.get_height() if background != null else 1.0


func _begin_step(index: int) -> void:
	var steps: Array = record.get("steps", [])
	if steps.is_empty(): return
	step = index % steps.size()
	var instruction: Dictionary = steps[step]
	if step == 0 or instruction.get("reset", false):
		sprites = record.get("sprites", []).duplicate(true)
		for sprite in sprites: sprite["opacity"] = float(sprite.get("opacity", 1.0))
	starts = sprites.duplicate(true); targets = sprites.duplicate(true); paths.clear(); fades.clear()
	for move in instruction.get("moves", []):
		var actor := int(move.get("sprite", -1))
		if actor < 0 or actor >= sprites.size(): continue
		if move.has("rect"):
			targets[actor].rect = move.rect.duplicate()
			paths[actor] = [starts[actor].rect] + move.get("via", []) + [move.rect]
		if move.has("opacity"): targets[actor].opacity = clampf(float(move.opacity), 0, 1)
		if move.has("image"): targets[actor].image = str(move.image)
		if move.get("fade", false): fades[actor] = true
	elapsed = 0
	_advance(0)


func _process(delta: float) -> void:
	if playing and not reduced_motion and is_visible_in_tree(): _advance(delta)


func _advance(delta: float) -> void:
	var steps: Array = record.get("steps", [])
	if steps.is_empty() or starts.is_empty(): return
	elapsed += delta
	var duration := maxf(.3, float(steps[step].get("duration", 1.2)))
	var progress := clampf((elapsed - .55) / duration, 0, 1)
	var eased := progress * progress * (3 - 2 * progress)
	for index in sprites.size():
		if paths.has(index):
			var route: Array = paths[index]
			var part := minf(eased * (route.size() - 1), route.size() - 1.00001)
			var segment := int(part)
			var a: Array = route[segment]; var b: Array = route[segment + 1]
			sprites[index].rect = [lerpf(a[0], b[0], part - segment), lerpf(a[1], b[1], part - segment), lerpf(a[2], b[2], part - segment), lerpf(a[3], b[3], part - segment)]
		# Captured pieces disappear and promotion changes only after arrival.
		sprites[index].opacity = lerpf(starts[index].opacity, targets[index].opacity, eased) if fades.has(index) else targets[index].opacity if progress >= 1 else starts[index].opacity
		sprites[index].image = targets[index].image if progress >= 1 else starts[index].image
	stage.queue_redraw()
	if elapsed >= duration + 1.55: _begin_step(step + 1)


func _paint() -> void:
	var background := _texture(str(record.get("background", "")))
	if background == null: return
	var factor := minf(stage.size.x / background.get_width(), stage.size.y / background.get_height())
	var art_size := background.get_size() * factor
	var area := Rect2((stage.size - art_size) / 2, art_size)
	stage.draw_texture_rect(background, area, false)
	_draw_paths(area)
	for sprite in sprites:
		var rect: Array = sprite.get("rect", [])
		if rect.size() != 4: continue
		var texture := _texture(str(sprite.get("image", "")))
		if texture == null: continue
		var bounds := Rect2(area.position + Vector2(rect[0], rect[1]) * art_size, Vector2(rect[2], rect[3]) * art_size)
		GameLook.draw_texture_contained(stage, texture, bounds, Color(1, 1, 1, float(sprite.get("opacity", 1))))
	var badge := area.position + Vector2(10, area.size.y - 10)
	stage.draw_circle(badge, 8, Color("233f50ee"))
	if playing:
		for x in [-2.5, 2.5]: stage.draw_line(badge + Vector2(x,-3), badge + Vector2(x,3), Color.WHITE, 2, true)
	else: stage.draw_colored_polygon(PackedVector2Array([badge+Vector2(-2,-4),badge+Vector2(4,0),badge+Vector2(-2,4)]), Color.WHITE)
	if stage.has_focus(): stage.draw_style_box(focus_frame, Rect2(Vector2.ONE, stage.size - Vector2.ONE * 2))


func _draw_paths(area: Rect2) -> void:
	for actor in paths:
		var route: Array = paths[actor]
		var points := PackedVector2Array()
		for rect: Array in route: points.append(area.position + Vector2(rect[0] + rect[2] / 2, rect[1] + rect[3] / 2) * area.size)
		if points[0].distance_to(points[-1]) < .1: continue
		var origin: Array = starts[actor].rect
		var ghost := _texture(str(starts[actor].image))
		if ghost != null: GameLook.draw_texture_contained(stage, ghost, Rect2(area.position + Vector2(origin[0],origin[1])*area.size,Vector2(origin[2],origin[3])*area.size),Color(1,1,1,.24))
		var color: Color = [Color("147a9c"),Color("ad6327"),Color("6651a4")][int(actor) % 3]
		stage.draw_polyline(points, Color("fff5df"), 6, true)
		stage.draw_polyline(points, color, 3, true)
		stage.draw_circle(points[0], 4, Color("fff5df"))
		stage.draw_circle(points[0], 3, color)
		var radius := minf(area.size.x * origin[2], area.size.y * origin[3]) * .42
		stage.draw_arc(points[-1], radius, 0, TAU, 32, Color("fff5df"), 5, true)
		stage.draw_arc(points[-1], radius, 0, TAU, 32, color, 2, true)
		var direction := (points[-1] - points[-2]).normalized()
		var tip := points[-1] - direction * radius
		var normal := Vector2(-direction.y, direction.x)
		stage.draw_polyline(PackedVector2Array([tip-direction*8+normal*5,tip,tip-direction*8-normal*5]),color,3,true)
