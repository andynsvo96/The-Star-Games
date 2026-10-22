class_name GameCardEffect
extends Control

var event: Dictionary = {}
var elapsed := 0.0
var paused := false
var reduced := false
var key := -1
var static_left := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); z_index = 8

func update(motion: Dictionary, is_paused: bool, reduce: bool) -> void:
	var fresh := int(motion.get("revision", -1)) != key
	if fresh and key >= 0 and reduce and not motion.get("effects", []).is_empty(): static_left = 0.85
	key = int(motion.get("revision", -1)); paused = is_paused; reduced = reduce
	elapsed = float(motion.get("elapsed", 0)); event = motion; queue_redraw()

func _process(delta: float) -> void:
	if paused: return
	elapsed += delta; static_left = maxf(0, static_left - delta)
	if not event.get("effects", []).is_empty(): queue_redraw()

func _draw() -> void:
	if event.get("effects", []).is_empty(): return
	var effect: Dictionary = event.effects[0]
	var duration := float(effect.get("duration", 1.25))
	var effect_elapsed := elapsed - float(effect.get("start", 0))
	if (effect_elapsed < 0 or effect_elapsed >= duration or not event.get("active", false)) and static_left <= 0: return
	var progress := 0.4 if reduced else clampf(effect_elapsed / duration, 0, 1)
	var alpha := 1.0 if reduced else minf(1, progress * 8) * minf(1, (1 - progress) * 6)
	var blocking: bool = effect.card.kind == "just-say-no"
	var tint := Color("ff6576") if blocking else Color("ffd44c")
	var center := size * (Vector2(0.84, 0.18) if reduced else Vector2(0.5, 0.43))
	var height: float = minf(100 if reduced else 230, size.y * (0.18 if reduced else 0.42)) * (1.0 if reduced else 0.85 + sin(minf(1, progress * 3) * PI / 2) * 0.15)
	draw_circle(center, height * 0.7, Color(tint, alpha * 0.12))
	if not reduced: draw_arc(center, height * (0.55 + progress * 0.4), 0, TAU, 64, Color(tint, alpha * 0.65), 4, true)
	draw_set_transform(center, 0 if reduced else sin(progress * TAU) * (0.14 if blocking else 0.07))
	var data: Dictionary = effect.card.duplicate(true); data.display_name = effect.get("display_name", data.name)
	GameCard.paint(self, Rect2(Vector2(-height / 3, -height / 2), Vector2(height * 2 / 3, height)), data, GameCard.artwork(str(effect.art)), tint)
	draw_set_transform(Vector2.ZERO)
	if not reduced: GameLook.draw_table_text(self, str(effect.get("label", "")), center + Vector2(-size.x * 0.42, height * 0.65), size.x * 0.84, 20, Color(tint, alpha), true)
