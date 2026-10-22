class_name GameDragScroll
extends RefCounted

# Tap on release; crossing the threshold turns the gesture into browsing.
var origin := Vector2.ZERO
var previous := Vector2.ZERO
var down := false
var dragged := false


func begin(point: Vector2) -> void:
	origin = point; previous = point; down = true; dragged = false


func move(point: Vector2) -> float:
	if not down: return 0.0
	if point.distance_to(origin) > 8: dragged = true
	var delta := previous.x - point.x; previous = point
	return delta if dragged else 0.0


func end() -> bool:
	var tapped := down and not dragged
	down = false
	return tapped
