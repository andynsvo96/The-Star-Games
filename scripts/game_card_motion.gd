class_name GameCardMotion
extends RefCounted

# A presentation timeline. Hidden faces are removed before sending to viewers.
var flights: Array = []
var shuffle := 0.0
var duration := 0.0
var revision := 0
var effects: Array = []


func begin(items: Array, shuffling := false, highlights: Array = []) -> void:
	flights = items.duplicate(true); shuffle = 0.65 if shuffling else 0.0; revision += 1
	effects = highlights.duplicate(true)
	duration = shuffle
	for index in flights.size():
		flights[index].delay = shuffle + index * (0.045 if shuffling else 0.085)
		flights[index].duration = 0.38
		duration = maxf(duration, float(flights[index].delay) + 0.48)
	for effect in effects: duration = maxf(duration, float(effect.duration))


func view(viewer: int, elapsed: float, active: bool) -> Dictionary:
	var visible := flights.duplicate(true)
	for flight in visible:
		if flight.to.zone == "hand" and int(flight.to.seat) != viewer: flight.card = {"back": true, "layout": "standard"} if flight.card.get("layout", "") == "standard" else {"back": true}
	return {"revision": revision, "active": active, "elapsed": clampf(elapsed, 0, duration), "duration": duration, "shuffle": shuffle, "flights": visible, "effects": effects.duplicate(true)}


# Independent decisions may add flights while earlier recipients are still paying.
func append(items: Array, elapsed: float, highlights: Array = []) -> void:
	revision += 1
	for index in items.size():
		var flight: Dictionary = items[index].duplicate(true); flight.delay = elapsed + index * 0.085; flight.duration = 0.38
		flights.append(flight); duration = maxf(duration, float(flight.delay) + 0.48)
	if not highlights.is_empty():
		effects = highlights.duplicate(true)
		for effect in effects: effect.start = elapsed; duration = maxf(duration, elapsed + float(effect.duration))


static func progress(flight: Dictionary, elapsed: float) -> float:
	var hold := clampf(float(flight.get("hold",0)),0,maxf(0,float(flight.duration)-.001))
	return clampf((elapsed - float(flight.delay) - hold) / maxf(.001,float(flight.duration)-hold), 0, 1)


static func travel(from: Rect2, to: Rect2, progress_value: float, easing := "ease_out") -> Rect2:
	var eased := progress_value*progress_value*(3-2*progress_value) if easing == "smooth" else 1.0 - pow(1.0 - progress_value, 3)
	var result := Rect2(from.position.lerp(to.position, eased), from.size.lerp(to.size, eased))
	result.position.y -= sin(progress_value * PI) * 24
	return result
