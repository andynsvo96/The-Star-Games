class_name GameMotion
extends RefCounted

# Animate an inner visual, never its layout container or input target.
static func reset(visual: Control) -> void:
	if visual.has_meta("game_motion"):
		var previous: Tween = visual.get_meta("game_motion")
		if previous != null and previous.is_valid():
			previous.kill()
		visual.remove_meta("game_motion")
	visual.scale = Vector2.ONE
	visual.rotation = 0.0


static func play(visual: Control, reduced: bool, placed := false, celebrate := false, delay := 0.0) -> void:
	reset(visual)
	if reduced or not (placed or celebrate):
		return
	visual.pivot_offset = visual.size / 2.0
	var tween := visual.create_tween()
	visual.set_meta("game_motion", tween)
	if placed:
		visual.scale = Vector2.ONE * 0.35
		visual.rotation = -0.16
		tween.set_parallel(true)
		tween.tween_property(visual, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(visual, "rotation", 0.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.chain()
		tween.set_parallel(false)
	if celebrate:
		tween.tween_interval(delay)
		for repeat in 2:
			tween.tween_property(visual, "scale", Vector2.ONE * 1.16, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(visual, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# One finite pulse for an urgent clock tick; never animate an input target.
static func countdown(visual: Control, reduced: bool) -> void:
	reset(visual)
	if reduced:
		return
	visual.pivot_offset = visual.size / 2.0
	visual.scale = Vector2.ONE * 1.18
	var tween := visual.create_tween()
	visual.set_meta("game_motion", tween)
	tween.tween_property(visual, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# An opt-in clock blink: color only the timer span, never the layout container.
static func countdown_alpha(seconds: float, reduced: bool) -> float:
	return 1.0 if reduced or int(floorf(seconds * 2.0)) % 2 == 0 else 0.45
