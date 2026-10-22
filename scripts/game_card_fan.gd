class_name GameCardFan
extends Control

# A bounded public-card row. End stacks repeat while held, like a hand fan.
var entries: Array = []
var offset := 0.0
var visible_cards := 5
var previous := Button.new()
var next := Button.new()
var drag := GameDragScroll.new()
var held := 0
var hold_age := 0.0
var card_width := 60.0
var step := 44.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP; focus_mode = Control.FOCUS_ALL
	clip_contents = true; size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for button in [previous, next]:
		button.flat = true; button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "disabled"]: button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		add_child(button); button.button_up.connect(_stop_hold)
	previous.accessibility_name = "Previous bank cards"; next.accessibility_name = "Next bank cards"
	previous.button_down.connect(func() -> void: _begin_hold(-1))
	next.button_down.connect(func() -> void: _begin_hold(1))
	resized.connect(_fit); visibility_changed.connect(func() -> void:
		if not is_visible_in_tree(): _stop_hold())
	_fit()


func set_items(items: Array) -> void:
	_stop_hold(); entries = items; offset = 0
	accessibility_name = "Bank cards"
	accessibility_description = ", ".join(items.map(func(entry: Dictionary) -> String: return "%s, $%d" % [entry.card.get("display_name", entry.card.name), entry.card.value]))
	if is_node_ready(): _fit()


func _fit() -> void:
	card_width = minf(70, maxf(24, (size.x - 12) / (1 + (visible_cards - 1) * 0.72)))
	step = card_width * 0.72
	custom_minimum_size.y = maxf(44, card_width * 1.5 + 8)
	var span := (mini(visible_cards, entries.size()) - 1) * step + card_width
	var left := maxf(6, (size.x - span) / 2)
	previous.position = Vector2(maxf(0, left - 4), 0); next.position = Vector2(maxf(0, left + span - 40), 0)
	previous.size = Vector2(44, custom_minimum_size.y); next.size = previous.size
	_set_offset(offset)


func _limit() -> float:
	return maxi(0, entries.size() - visible_cards) * step


func _set_offset(value: float) -> void:
	offset = clampf(value, 0, _limit())
	previous.visible = offset > 0.5; next.visible = offset < _limit() - 0.5
	queue_redraw()


func shift(direction: int) -> void:
	_set_offset(offset + direction * 3 * step)


func _begin_hold(direction: int) -> void:
	held = direction; hold_age = 0; shift(direction)


func _stop_hold() -> void:
	held = 0; hold_age = 0


func _process(delta: float) -> void:
	if not is_visible_in_tree(): _stop_hold()
	if held == 0: return
	hold_age += delta
	if hold_age >= 0.31: hold_age = 0; shift(held)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed: _stop_hold(); drag.end()
	if event is InputEventScreenTouch and not event.pressed: _stop_hold(); drag.end()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: _stop_hold(); drag.end()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
			shift(-1 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1); accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: drag.begin(event.position); grab_focus()
			else: drag.end()
			accept_event()
	elif event is InputEventMouseMotion and drag.down:
		_set_offset(offset + drag.move(event.position)); accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed: drag.begin(event.position)
		else: drag.end()
		accept_event()
	elif event is InputEventScreenDrag and drag.down:
		_set_offset(offset + drag.move(event.position)); accept_event()
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_LEFT, KEY_RIGHT]: shift(-1 if event.keycode == KEY_LEFT else 1); accept_event()
		elif event.keycode in [KEY_HOME, KEY_END]: _set_offset(0 if event.keycode == KEY_HOME else _limit()); accept_event()


func _draw() -> void:
	if entries.is_empty(): return
	var first := clampi(roundi(offset / step), 0, maxi(0, entries.size() - visible_cards))
	var count := mini(visible_cards, entries.size())
	var left := maxf(6, (size.x - ((count - 1) * step + card_width)) / 2)
	for index in count:
		var entry: Dictionary = entries[first + index]
		var rect := Rect2(Vector2(left + index * step, 4), Vector2(card_width, card_width * 1.5))
		if (index == 0 and first > 0) or (index == count - 1 and first + count < entries.size()):
			var direction := -1 if index == 0 else 1
			for depth in [2, 1]: GameCard.paint(self, Rect2(rect.position + Vector2(direction * depth * 2, depth), rect.size), entry.card, entry.texture, entry.get("tint", Color("17594d")))
		GameCard.paint(self, rect, entry.card, entry.texture, entry.get("tint", Color("17594d")))
