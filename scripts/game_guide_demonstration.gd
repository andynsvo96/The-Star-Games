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
var stage: Control
var caption: Label
var pause_button: Button
var replay_button: Button


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.custom_minimum_size = Vector2(0, 220)
	stage.draw.connect(_paint)
	stage.resized.connect(stage.queue_redraw)
	add_child(stage)
	caption = Label.new()
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_override("font", GameLook.interface_font())
	caption.add_theme_font_size_override("font_size", 13)
	caption.custom_minimum_size.y = 36
	add_child(caption)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(controls)
	pause_button = Button.new(); pause_button.text = "PAUSE"
	replay_button = Button.new(); replay_button.text = "REPLAY"
	for button in [pause_button, replay_button]:
		controls.add_child(button)
		GameLook.board_action(button)
		button.add_theme_font_override("font", GameLook.interface_font(700))
		button.add_theme_font_size_override("font_size", 12)
	pause_button.pressed.connect(func() -> void: playing = not playing; pause_button.text = "PAUSE" if playing else "PLAY")
	replay_button.pressed.connect(restart)


func set_demonstration(value: Dictionary) -> void:
	if value == record: return
	record = value.duplicate(true)
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
	if pause_button != null: pause_button.text = "PAUSE"
	_begin_step(0)


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
	caption.text = str(instruction.get("caption", ""))
	stage.accessibility_name = str(record.get("description", ""))
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
	for sprite in sprites:
		var rect: Array = sprite.get("rect", [])
		if rect.size() != 4: continue
		var texture := _texture(str(sprite.get("image", "")))
		if texture == null: continue
		var bounds := Rect2(area.position + Vector2(rect[0], rect[1]) * art_size, Vector2(rect[2], rect[3]) * art_size)
		GameLook.draw_texture_contained(stage, texture, bounds, Color(1, 1, 1, float(sprite.get("opacity", 1))))
