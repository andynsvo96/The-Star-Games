extends Control

# Decorative set pieces orbit independently of the shared background media player.
var sun: Texture2D
var moon: Texture2D
var city_night: Texture2D
var city_day: Texture2D
var daytime: Variant = null
var transition: Tween
var cycle := 0.0:
	set(value):
		cycle = value
		queue_redraw()
var city_mix := 0.0:
	set(value):
		city_mix = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sun = RuntimeAssets.texture("res://Games/mafia/art/sun.svg")
	moon = RuntimeAssets.texture("res://Games/mafia/art/moon.svg")
	city_night = RuntimeAssets.texture("res://Games/mafia/art/town-night-front.png")
	city_day = RuntimeAssets.texture("res://Games/mafia/art/town-day-front.png")
	resized.connect(queue_redraw)


func set_daytime(value: bool, animate := true, reduced := false) -> void:
	if daytime == value and not reduced:
		return
	if is_instance_valid(transition):
		transition.kill()
	transition = null
	var moving := animate and not reduced and daytime != null
	daytime = value
	if not moving:
		cycle = 0.0 if value else 1.0
		city_mix = 1.0 if value else 0.0
		return
	# Keep rotating forward even if a new phase interrupts the previous exchange.
	var target := int(floor(cycle)) + 1
	if target % 2 != (0 if value else 1):
		target += 1
	transition = create_tween().set_parallel(true)
	transition.tween_property(self, "cycle", float(target), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	transition.tween_property(self, "city_mix", 1.0 if value else 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func orbit_position(value: float) -> Vector2:
	var angle := -PI / 2.0 + value * PI
	var parked_y := minf(size.y * 0.17, minf(size.x, size.y) * 0.13)
	var height_radius := size.y * 1.1 - parked_y
	return Vector2(size.x * (0.79 + 0.12 * cos(angle)), size.y * 1.1 + height_radius * sin(angle))


func _draw() -> void:
	var radius := clampf(minf(size.x, size.y) * 0.075, 26, 67)
	for item in [[sun, cycle], [moon, cycle + 1.0]]:
		if item[0] != null:
			draw_texture_rect(item[0], Rect2(orbit_position(item[1]) - Vector2.ONE * radius, Vector2.ONE * radius * 2), false)
	# A covering, transparent city layer hides the planets as they reach the roofs.
	var source_size := city_night.get_size() if city_night != null else Vector2(1672, 941)
	var artwork_size := source_size * maxf(size.x / source_size.x, size.y / source_size.y)
	var city_rect := Rect2((size - artwork_size) / 2, artwork_size)
	if city_night != null:
		draw_texture_rect(city_night, city_rect, false)
	if city_day != null and city_mix > 0:
		draw_texture_rect(city_day, city_rect, false, Color(1, 1, 1, city_mix))


func stop() -> void:
	if is_instance_valid(transition):
		transition.kill()
	transition = null
	hide()


func _exit_tree() -> void:
	stop()
