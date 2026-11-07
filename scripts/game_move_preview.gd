class_name GameMovePreview
extends Control

# Public presentation only: a keyed demonstration never moves real artwork.
var rect_for: Callable
var make_visual: Callable
var visual: Control
var key := ""
var route: Array = []
var elapsed := 0.0
var duration := .35
var paused := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(rectangle: Callable, factory: Callable) -> void:
	rect_for = rectangle; make_visual = factory


func update_preview(record: Dictionary, pause: bool, reduced: bool, restore := false) -> void:
	paused = pause
	if record.get("to", -1) < 0:
		clear()
		return
	var next := str(record.get("key", ""))
	if next != key:
		clear()
		key = next
		route = record.get("path", [record.from, record.to]).duplicate()
		duration = minf(1.5, maxf(.35, (route.size() - 1) * .32))
		elapsed = duration if reduced or restore else 0.0
		visual = make_visual.call(record)
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.modulate.a = .85
		add_child(visual)
	if reduced or restore: elapsed = duration
	_position()


func clear() -> void:
	if is_instance_valid(visual): visual.free()
	key = ""; route.clear()


func _process(delta: float) -> void:
	if not paused: elapsed = minf(duration, elapsed + delta)
	_position()


func _position() -> void:
	if route.size() < 2 or not is_instance_valid(visual): return
	var progress := clampf(elapsed / duration, 0, 1) * (route.size() - 1)
	var segment := mini(int(progress), route.size() - 2)
	var fraction := progress - segment
	var a: Rect2 = rect_for.call(route[segment])
	var b: Rect2 = rect_for.call(route[segment + 1])
	visual.size = a.size.lerp(b.size, fraction)
	visual.global_position = a.get_center().lerp(b.get_center(), smoothstep(0, 1, fraction)) - visual.size / 2 - Vector2(0, sin(fraction * PI) * visual.size.y * .15)


static func white_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){vec4 p=texture(TEXTURE,UV);float v=dot(p.rgb,vec3(.299,.587,.114));COLOR=vec4(vec3(.72+.28*v),p.a*COLOR.a);}"
	var material := ShaderMaterial.new(); material.shader = shader
	return material
