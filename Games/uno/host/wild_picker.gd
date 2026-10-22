extends Control

signal color_selected(suit: String)
signal canceled
signal uno_pressed
const Rules = preload("res://Games/uno/host/rules.gd")
var card_rect := Rect2()
var texture: Texture2D
var sectors: Array[Button] = []
var cancel_button: Button
var uno_button: Button
var placement := Callable()
var layout_area := Rect2()

# Hit testing follows the rotated ellipse on the bundled Wild card exactly.
class Sector extends Button:
	var suit := "red"
	var quadrant := 0

	func _has_point(point: Vector2) -> bool:
		var offset := Vector2(point.x / size.x * 120 - 60, point.y / size.y * 180 - 90).rotated(deg_to_rad(-25))
		if pow(offset.x / 37, 2) + pow(offset.y / 57, 2) > 1: return false
		match quadrant:
			0: return offset.x < 0 and offset.y < 0
			1: return offset.x >= 0 and offset.y < 0
			2: return offset.x >= 0 and offset.y >= 0
			_: return offset.x < 0 and offset.y >= 0

	func _draw() -> void:
		if not has_focus(): return
		var start: float = [PI, PI * 1.5, 0.0, PI * .5][quadrant]
		var points := PackedVector2Array([size / 2])
		for step in 17:
			var angle := start + step / 16.0 * PI / 2
			var point := Vector2(cos(angle) * 35, sin(angle) * 55).rotated(deg_to_rad(25)) + Vector2(60,90)
			points.append(point * size / Vector2(120,180))
		points.append(size / 2)
		draw_polyline(points, Color.WHITE, 3, true)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for index in 4:
		var suit: String = ["red", "blue", "green", "yellow"][index]
		var button := Sector.new()
		button.quadrant = index
		button.suit = suit
		button.accessibility_name = "Choose " + suit.capitalize()
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for mode in ["normal", "hover", "pressed", "focus"]: button.add_theme_stylebox_override(mode, StyleBoxEmpty.new())
		button.focus_entered.connect(button.queue_redraw)
		button.focus_exited.connect(button.queue_redraw)
		button.pressed.connect(func() -> void: color_selected.emit(button.suit))
		add_child(button)
		sectors.append(button)
	cancel_button = Button.new()
	cancel_button.text = "CANCEL"
	GameLook.action(cancel_button, false)
	GameLook.compact_control(cancel_button)
	add_child(cancel_button)
	cancel_button.pressed.connect(func() -> void: canceled.emit())
	uno_button = Button.new()
	uno_button.text = "UNO!"
	GameLook.action(uno_button, true)
	GameLook.compact_control(uno_button)
	add_child(uno_button)
	uno_button.pressed.connect(func() -> void: uno_pressed.emit())
	resized.connect(_layout)
	hide()


func open(card: Dictionary, can_uno := false, can_cancel := true, free_area := Callable(), palette: Array = Rules.COLORS, gamemode := "classic") -> void:
	placement = free_area
	var prefix := Rules.card_art_prefix(card, gamemode)
	texture = RuntimeAssets.texture("res://Games/uno/art/cards/wild-wild.svg") if card.has("addon") else RuntimeAssets.texture("res://Games/uno/art/cards/%swild-%s%s.svg" % [prefix,card.kind,"-picker" if gamemode == "no_mercy" else ""])
	var ordered := [palette[0], palette[3], palette[2], palette[1]]
	for index in sectors.size():
		sectors[index].suit = ordered[index]
		sectors[index].accessibility_name = "Choose " + str(ordered[index]).capitalize()
	uno_button.visible = can_uno
	cancel_button.visible = can_cancel
	show()
	_layout()
	sectors[0].grab_focus()


func _area() -> Rect2:
	return placement.call() if placement.is_valid() else Rect2(Vector2(16,56), Vector2(size.x - 32,size.y * .42))


func _process(_delta: float) -> void:
	if visible and _area() != layout_area: _layout()


func _layout() -> void:
	layout_area = _area()
	var height := minf(270,maxf(90,layout_area.size.y - 44))
	var width := minf(layout_area.size.x * .7,height / 1.5)
	var center := layout_area.get_center()
	card_rect = Rect2(Vector2(center.x - width / 2,layout_area.position.y + (layout_area.size.y - width * 1.5 - 44) / 2), Vector2(width,width * 1.5))
	for button in sectors:
		button.position = card_rect.position
		button.size = card_rect.size
	cancel_button.size = cancel_button.get_combined_minimum_size()
	uno_button.size = uno_button.get_combined_minimum_size()
	var row_width := (cancel_button.size.x if cancel_button.visible else 0.0) + (uno_button.size.x if uno_button.visible else 0.0)
	if cancel_button.visible and uno_button.visible: row_width += 12
	uno_button.position = Vector2(center.x - row_width / 2, card_rect.end.y + 12)
	cancel_button.position = uno_button.position + Vector2(uno_button.size.x + 12 if uno_button.visible else 0.0,0)
	var focusable: Array[Button] = sectors.duplicate()
	if uno_button.visible: focusable.append(uno_button)
	if cancel_button.visible: focusable.append(cancel_button)
	for index in focusable.size():
		focusable[index].focus_next = focusable[index].get_path_to(focusable[(index + 1) % focusable.size()])
		focusable[index].focus_previous = focusable[index].get_path_to(focusable[posmod(index - 1, focusable.size())])
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size), Color(0,0,0,.35))
	if texture != null: draw_texture_rect(texture, card_rect, false)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		canceled.emit()
		get_viewport().set_input_as_handled()
