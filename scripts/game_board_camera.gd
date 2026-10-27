class_name GameBoardCamera
extends RefCounted

# Local presentation only. Gameplay still receives a tap, never a drag release.
signal changed
signal tapped(position: Vector2)

var zoom := 1.0
var pan := Vector2.ZERO
var viewport_size := Vector2.ONE
var fit_rect := Rect2()
var maximum_zoom := 4.0
var _points := {}
var _starts := {}
var _gesture := false

func reset() -> void:
	zoom = 1.0; pan = Vector2.ZERO; cancel(); changed.emit()

func cancel() -> void:
	_points.clear(); _starts.clear(); _gesture = false

func is_interacting() -> bool:
	return not _points.is_empty()

func set_frame(viewport: Vector2, bounds := Rect2()) -> void:
	viewport_size = viewport; fit_rect = bounds
	# Containers can report their previous anchor for one resize frame. Clamping
	# against that off-screen rectangle would turn a fitted map into a manual pan.
	if not bounds.has_area() or Rect2(Vector2.ZERO,viewport).grow(1).encloses(bounds): _constrain()

func focus_center() -> Vector2:
	return fit_rect.get_center() if fit_rect.has_area() else viewport_size/2

func project(point: Vector2) -> Vector2:
	var center := focus_center()
	return (point-center)*zoom+center+pan

func zoom_at(factor: float, anchor: Vector2) -> void:
	var next := clampf(zoom*factor,1.0,maximum_zoom)
	var center := focus_center()
	pan = anchor-center-(anchor-center-pan)*(next/zoom)
	zoom = next; _constrain(); changed.emit()

func _constrain() -> void:
	if fit_rect.has_area():
		var edge := Vector2.ONE*minf(48,minf(viewport_size.x,viewport_size.y)*.12)
		var half := fit_rect.size*zoom/2
		pan = pan.clamp(edge-focus_center()-half,viewport_size-edge-focus_center()+half)
		return
	var limit := viewport_size*(.35+(zoom-1)*.5)
	pan = pan.clamp(-limit,limit)

func _center() -> Vector2:
	var result := Vector2.ZERO
	for point: Vector2 in _points.values(): result += point
	return result/maxi(1,_points.size())

func _distance() -> float:
	var values: Array = _points.values()
	return values[0].distance_to(values[1]) if values.size() > 1 else 0.0

func handle_input(event: InputEvent, point: Vector2) -> bool:
	var inside := Rect2(Vector2.ZERO,viewport_size).has_point(point)
	if event is InputEventMagnifyGesture and inside:
		zoom_at(event.factor,point); return true
	if event is InputEventPanGesture and inside:
		pan -= event.delta*12; _constrain(); changed.emit(); return true
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_HOME: reset()
			KEY_PLUS, KEY_EQUAL, KEY_KP_ADD: zoom_at(1.2,viewport_size/2)
			KEY_MINUS, KEY_KP_SUBTRACT: zoom_at(1/1.2,viewport_size/2)
			KEY_LEFT: pan.x += 32
			KEY_RIGHT: pan.x -= 32
			KEY_UP: pan.y += 32
			KEY_DOWN: pan.y -= 32
			_: return false
		_constrain(); changed.emit(); return true
	if event is InputEventMouseButton and event.pressed and inside:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_at(pow(1.15,event.factor if event.button_index == MOUSE_BUTTON_WHEEL_UP else -event.factor),point); return true
	var id := -1
	if event is InputEventScreenTouch or event is InputEventScreenDrag: id = event.index
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT: return false
		if event.pressed:
			if not inside: return false
			_points[id] = point; _starts[id] = point
			if _points.size() > 1: _gesture = true
			return true
		if not _points.has(id): return false
		var tap: bool = not _gesture and not (event is InputEventScreenTouch and event.canceled) and point.distance_to(_starts[id]) < 8
		_points.erase(id); _starts.erase(id)
		if _points.is_empty(): _gesture = false
		if tap and inside: tapped.emit(point)
		return true
	if (event is InputEventMouseMotion or event is InputEventScreenDrag) and _points.has(id):
		var old_center := _center(); var old_distance := _distance()
		_points[id] = point
		var center := _center()
		if point.distance_to(_starts[id]) >= 8: _gesture = true
		if _points.size() > 1 and old_distance > 1:
			zoom_at(_distance()/old_distance,old_center)
		if _gesture:
			pan += center-old_center; _constrain(); changed.emit()
		return true
	return false
