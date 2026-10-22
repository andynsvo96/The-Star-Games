class_name GameCelebration
extends Control

# Reusable, input-transparent board celebration. Coordinates are normalized.
var lines: Array = []
var age := 3.0
var accent := GameLook.RED
var banner: Label
var sparks: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner = Label.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_stylebox_override("normal", GameLook.surface("gold"))
	banner.add_theme_color_override("font_color", GameLook.INK)
	add_child(banner)
	resized.connect(_layout)
	_layout()
	clear()


func _layout() -> void:
	banner.position = Vector2(-8, size.y * 0.37)
	banner.size = Vector2(size.x + 16, size.y * 0.26)
	banner.add_theme_font_size_override("font_size", int(clampf(size.x / 17.0, 16, 34)))
	banner.pivot_offset = banner.size / 2.0
	queue_redraw()


func clear() -> void:
	lines.clear()
	sparks.clear()
	age = 3.0
	set_process(false)
	if banner != null:
		GameMotion.reset(banner)
		banner.hide()
	queue_redraw()


func show_win(segments: Array, headline: String, color: Color, animate: bool) -> void:
	clear()
	lines = segments.duplicate(true)
	accent = color
	if animate:
		age = 0.0
		banner.text = headline
		banner.modulate.a = 1.0
		banner.show()
		GameMotion.play(banner, false, true)
		for index in 64:
			var angle := -PI + float(index) / 63.0 * PI
			var speed := 0.35 + float(index % 7) * 0.075
			sparks.append({"velocity": Vector2(cos(angle), sin(angle)) * speed, "spin": index * 1.7, "star": index % 3 == 0, "color": [Color("ffdb36"), accent, Color.WHITE, GameLook.BLUE][index % 4]})
		set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	age += delta
	banner.modulate.a = clampf((2.1 - age) / 0.4, 0.0, 1.0)
	if age >= 2.8:
		set_process(false)
		sparks.clear()
		banner.hide()
	queue_redraw()


func _draw() -> void:
	var width := minf(size.x, size.y)
	var sweep := clampf(age / 0.45, 0.0, 1.0)
	for segment in lines:
		var start: Vector2 = segment[0] * size
		var finish: Vector2 = start.lerp(segment[1] * size, sweep)
		draw_line(start, finish, Color(accent, 0.24), width * 0.065, true)
		draw_line(start, finish, Color("ffd43d"), width * 0.025, true)
		draw_line(start, finish, Color("fffbe4"), width * 0.009, true)
	if age < 0.8 and not sparks.is_empty():
		draw_arc(size / 2.0, width * (0.1 + age * 0.65), 0, TAU, 64, Color(1, 0.85, 0.25, (1.0 - age / 0.8) * 0.7), 5, true)
	for index in sparks.size():
		var spark: Dictionary = sparks[index]
		var point: Vector2 = size * Vector2(0.5, 0.45) + spark.velocity * width * age + Vector2(0, width * 0.28 * age * age)
		var color: Color = spark.color
		color.a = clampf((2.8 - age) / 0.9, 0.0, 1.0)
		draw_set_transform(point, spark.spin + age * 3.0)
		if spark.star:
			var vertices := PackedVector2Array()
			for tip in 10:
				var radius := width * (0.025 if tip % 2 == 0 else 0.011)
				vertices.append(Vector2.from_angle(tip * PI / 5.0 - PI / 2.0) * radius)
			draw_colored_polygon(vertices, color)
		else:
			draw_rect(Rect2(-3, -6, 6, 12), color)
	draw_set_transform(Vector2.ZERO)
