class_name GamePlayerFocus
extends Control

# Floating player decisions never reserve space in the board's action row.
signal confirmed
signal action_pressed(id: String)
var targets: Array[Rect2] = []
var colors: Array[Color] = []
var obstacles: Array[Rect2] = []
var protected_areas: Array[Rect2] = []
var reduced_motion := false
var clock := 0.0
var prompt: PanelContainer
var message: Label
var confirm: Button
var counters: Array[Label] = []
var column: VBoxContainer
var row: HBoxContainer
var commands := HFlowContainer.new()
var commands_key := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 1
	prompt = PanelContainer.new()
	prompt.add_theme_stylebox_override("panel", GameLook.modern_table_sheet())
	add_child(prompt)
	column = VBoxContainer.new()
	prompt.add_child(column)
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	prompt.add_child(row)
	row.hide()
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.add_theme_color_override("font_color", Color("f3f6ff"))
	message.add_theme_font_size_override("font_size", 14)
	column.add_child(message)
	confirm = Button.new()
	confirm.text = "CONFIRM"
	GameLook.party_action(confirm)
	confirm.add_theme_font_size_override("font_size", 14)
	column.add_child(confirm)
	confirm.pressed.connect(func() -> void: confirmed.emit())
	commands.add_theme_constant_override("h_separation", 6)
	commands.add_theme_constant_override("v_separation", 6)
	commands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(commands)
	commands.hide()
	for index in 16:
		var counter := Label.new()
		counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		counter.add_theme_font_size_override("font_size", 14)
		counter.add_theme_color_override("font_color", GameLook.CREAM)
		var counter_style := GameLook.box(GameLook.INK, GameLook.CREAM, 10, 1)
		counter_style.set_content_margin_all(2)
		counter.add_theme_stylebox_override("normal", counter_style)
		counter.custom_minimum_size = Vector2(44, 24)
		counter.hide()
		add_child(counter)
		counters.append(counter)
	hide()


func present(rects: Array[Rect2], accents: Array[Color], captions: Array[String], copy: String, avoid: Array[Rect2], reduced: bool, multiple := false, protect: Array[Rect2] = []) -> void:
	commands.hide()
	targets = rects
	colors = accents
	obstacles = avoid
	protected_areas = protect
	reduced_motion = reduced
	message.text = copy
	message.visible = not copy.is_empty()
	confirm.visible = multiple
	visible = not targets.is_empty()
	for index in counters.size():
		counters[index].visible = visible and index < captions.size() and not captions[index].is_empty()
		if counters[index].visible:
			counters[index].text = captions[index]
			counters[index].position = Vector2(targets[index].end.x - 44, targets[index].position.y - 12)
	_fit_prompt()
	queue_redraw()


func present_context(copy: String, actions: Array, avoid: Array[Rect2], reduced: bool, protect: Array[Rect2] = []) -> void:
	targets = []
	colors = []
	obstacles = avoid
	protected_areas = protect
	reduced_motion = reduced
	message.text = copy
	message.visible = not copy.is_empty()
	confirm.hide()
	for counter in counters: counter.hide()
	var key := JSON.stringify(actions)
	if key != commands_key:
		commands_key = key
		for child in commands.get_children(): commands.remove_child(child); child.queue_free()
		for action: Dictionary in actions:
			var button := Button.new()
			button.text = action.label
			button.accessibility_name = action.label
			button.disabled = action.get("disabled", false)
			GameLook.party_action(button)
			GameLook.compact_control(button)
			button.add_theme_font_size_override("font_size", 12)
			button.pressed.connect(func() -> void: action_pressed.emit(str(action.id)))
			commands.add_child(button)
	commands.visible = not actions.is_empty()
	visible = not copy.is_empty() or not actions.is_empty()
	_fit_prompt()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible: return
	if not reduced_motion: clock += delta
	_fit_prompt()
	queue_redraw()


func _fit_prompt() -> void:
	if not visible or size.x <= 0: return
	var short := size.y < 500
	var horizontal := short and (confirm.visible or commands.visible)
	var destination: BoxContainer = row if horizontal else column
	if message.get_parent() != destination:
		message.reparent(destination)
		confirm.reparent(destination)
	if commands.get_parent() != destination: commands.reparent(destination)
	row.visible = horizontal
	column.visible = not horizontal
	confirm.custom_minimum_size.x = 88 if horizontal else 0
	message.add_theme_font_size_override("font_size", 12 if short else 14)
	var width := clampf(size.x * (.55 if horizontal and commands.visible else .47 if horizontal else .32 if short else .47 if size.x < 600 else .23), 160, 420 if horizontal and commands.visible else 300)
	if short and commands.visible and not message.visible:
		width = prompt.get_theme_stylebox("panel").get_minimum_size().x + 4 + maxi(0, commands.get_child_count() - 1) * 6
		for button: Button in commands.get_children(): width += button.get_combined_minimum_size().x
	width = minf(width, size.x - 32)
	prompt.custom_minimum_size.x = width
	prompt.size = Vector2(width, maxf(44, prompt.get_combined_minimum_size().y))
	var preferred := 12.0 if short else size.y * (.26 if size.x < 600 else .64)
	var best := Vector2(size.x - width - 16, 12)
	var best_score := INF
	for right_inset in [16.0, 86.0, 112.0] if short else [16.0]:
		var x := maxf(16, size.x - width - right_inset)
		for y in range(12, maxi(13, int(size.y - prompt.size.y - 12)), 8):
			var candidate := Rect2(Vector2(x, y), prompt.size)
			var score := absf(y - preferred) * .05
			for area in obstacles:
				var overlap := candidate.intersection(area.grow(4))
				score += overlap.get_area()
			for area in targets:
				score += candidate.intersection(area.grow(18)).get_area() * 100
			for area in protected_areas:
				score += candidate.intersection(area.grow(6)).get_area() * 1000
			if score < best_score:
				best = candidate.position
				best_score = score
	prompt.position = best


func _draw() -> void:
	if not visible or targets.is_empty(): return
	var pieces: Array[Rect2] = [Rect2(Vector2.ZERO, size)]
	for target in targets:
		var next: Array[Rect2] = []
		for piece in pieces:
			var cut := piece.intersection(target.grow(2))
			if not cut.has_area():
				next.append(piece)
				continue
			for remainder: Rect2 in [Rect2(piece.position, Vector2(piece.size.x, cut.position.y - piece.position.y)), Rect2(Vector2(piece.position.x, cut.end.y), Vector2(piece.size.x, piece.end.y - cut.end.y)), Rect2(Vector2(piece.position.x, cut.position.y), Vector2(cut.position.x - piece.position.x, cut.size.y)), Rect2(Vector2(cut.end.x, cut.position.y), Vector2(piece.end.x - cut.end.x, cut.size.y))]:
				if remainder.has_area(): next.append(remainder)
		pieces = next
	for piece in pieces: draw_rect(piece, Color(0.01, .04, .08, .23))
	for index in targets.size():
		GameLook.draw_turn_glow(self, targets[index], colors[index], .5 if reduced_motion else (sin(clock * 3) + 1) / 2)
