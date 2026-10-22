extends Control

# Fleet-specific artwork. Only public wrecks and the viewer's private ships enter here.
var SHIPS := [
	RuntimeAssets.texture("res://Games/battleship/art/fleet-carrier.svg"),
	RuntimeAssets.texture("res://Games/battleship/art/fleet-battleship.svg"),
	RuntimeAssets.texture("res://Games/battleship/art/fleet-cruiser.svg"),
	RuntimeAssets.texture("res://Games/battleship/art/fleet-submarine.svg"),
	RuntimeAssets.texture("res://Games/battleship/art/fleet-destroyer.svg"),
]
var FRAME := RuntimeAssets.texture("res://Games/battleship/art/fleet-console-v2.svg")
const Rules = preload("res://Games/battleship/host/rules.gd")
var caption := "PLAYER FLEET"
var states: Array = [0, 0, 0, 0, 0]
var enemy := false
var docked := false
var show_status := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)


func set_view(ships: Array, marks: Array, title: String, red: bool) -> void:
	caption = title
	enemy = red
	states.fill(0)
	for ship in ships:
		if ship.cells.all(func(cell: int) -> bool: return marks[cell] == 3):
			states[ship.ship] = 2
		elif ship.cells.any(func(cell: int) -> bool: return marks[cell] == 2):
			states[ship.ship] = 1
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(FRAME, Rect2(Vector2.ZERO, size), false)
	var inset := Vector2(size.x * 0.08, size.y * 0.085)
	var area := size - inset * 2
	var font := get_theme_font("font", "Label")
	var font_size := maxi(10, int(area.x * 0.07))
	var heading := float(font_size) + 9
	draw_string(font, inset + Vector2(0, font_size), caption, HORIZONTAL_ALIGNMENT_CENTER, area.x, font_size, Color.WHITE)
	if not show_status:
		return
	var step := (area.y - heading) / 5
	for index in 5:
		var center := inset + Vector2(area.x * 0.89, heading + step * (index + 0.5))
		var texture: Texture2D = SHIPS[index]
		var maximum := Vector2(area.x * 0.34 * Rules.LENGTHS[index] / 5.0, step * 0.68)
		var ship_size := texture.get_size() * minf(maximum.x / texture.get_width(), maximum.y / texture.get_height())
		draw_texture_rect(texture, Rect2(inset.x + area.x * 0.03, center.y - ship_size.y / 2, ship_size.x, ship_size.y), false, Color("496681") if states[index] == 2 else Color.WHITE)
		var name_size := maxi(8, int(area.x * 0.045))
		draw_string(font, inset + Vector2(area.x * 0.40, heading + step * (index + 0.5) + name_size * 0.35), Rules.NAMES[index].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, area.x * 0.43, name_size, Color("f4ead5"))
		var radius := minf(step * 0.24, area.x * 0.035)
		var color := Color("fa3448") if enemy else Color("26e94b")
		if states[index] == 1:
			color = Color("ffc83d")
		elif states[index] == 2:
			color = Color("23364b")
		draw_circle(center + Vector2(0, 1), radius + 2, Color("10243b"))
		draw_circle(center, radius, color)
		draw_arc(center, radius, 0, TAU, 24, Color("819ab2"), 1, true)
		if states[index] == 2:
			draw_line(center - Vector2.ONE * radius * 0.48, center + Vector2.ONE * radius * 0.48, Color("afc7d8"), 2, true)
			draw_line(center + Vector2(-1, 1) * radius * 0.48, center + Vector2(1, -1) * radius * 0.48, Color("afc7d8"), 2, true)
		else:
			draw_circle(center + Vector2(-radius * 0.28, -radius * 0.32), radius * 0.28, Color(1, 1, 1, 0.75))
