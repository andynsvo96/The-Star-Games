class_name GameMoneyEffect
extends Control

# Presentation only: the caller supplies public cash changes and live balance bounds.
var resolve_rect: Callable
var resolve_transfer_rect: Callable
var events: Array = []
var elapsed := 0.0
var paused := false
var reduced := false
var active := false
var static_left := 0.0
var revision := -1
var cash_icon: Texture2D
var icon_texture: Texture2D
var amount_prefix := "$"
var amount_badge := true
var show_transfers := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); z_index = 9
	cash_icon = RuntimeAssets.texture("res://ui/playful/table-cash.svg")


func update(motion: Dictionary, is_paused: bool, reduce: bool) -> void:
	var fresh := revision >= 0 and revision != int(motion.get("revision", -1))
	var same := revision == int(motion.get("revision", -1))
	if fresh and reduce and not motion.get("money", []).is_empty(): static_left = .85
	revision = int(motion.get("revision", -1)); events = motion.get("money", [])
	elapsed = maxf(elapsed, float(motion.get("elapsed", 0))) if same else float(motion.get("elapsed", 0))
	active = motion.get("active", false); paused = is_paused; reduced = reduce
	queue_redraw()


func clear() -> void:
	events = []; static_left = 0; active = false; queue_redraw()


func _process(delta: float) -> void:
	if paused: return
	var was_active := active
	if active:
		elapsed += delta
		active = events.any(func(event: Dictionary) -> bool: return elapsed < float(event.start) + float(event.duration))
	var was_static := static_left > 0
	static_left = maxf(0, static_left - delta)
	if was_active or was_static: queue_redraw()


func _draw() -> void:
	if not resolve_rect.is_valid(): return
	for event in events:
		var progress := clampf((elapsed - float(event.start)) / float(event.duration), 0, 1)
		if reduced:
			if static_left <= 0: continue
		elif not active or elapsed < float(event.start) or progress >= 1: continue
		var alpha := 1.0 if reduced else minf(1, progress * 8) * minf(1, (1 - progress) * 5)
		for change in event.changes:
			var bounds: Rect2 = resolve_rect.call(int(change.seat))
			if not bounds.has_area(): continue
			var gain := int(change.amount) > 0
			var bubble := amount_rect(bounds, int(change.amount), 0 if reduced else progress)
			var tint := Color("48e59a") if gain else Color("ff6976")
			if amount_badge:
				var style := GameLook.box(Color("062a21") if gain else Color("3f1822"), tint, 8, 1)
				style.bg_color.a = alpha; style.border_color.a = alpha
				draw_style_box(style, bubble)
				GameLook.draw_table_text(self, amount_text(int(change.amount)), bubble.position + Vector2(5, 20), 82, 17, Color(tint, alpha), true)
			else:
				var font := GameLook.party_font(get_theme_default_font())
				var point := bubble.position + Vector2(0, 22)
				draw_string_outline(font, point, amount_text(int(change.amount)), HORIZONTAL_ALIGNMENT_CENTER, bubble.size.x, 22, 4, Color(0, 0, 0, alpha * .9))
				draw_string(font, point, amount_text(int(change.amount)), HORIZONTAL_ALIGNMENT_CENTER, bubble.size.x, 22, Color(tint, alpha))
		if not show_transfers or reduced or int(event.get("target", -1)) < 0: continue
		var transfer := resolve_transfer_rect if resolve_transfer_rect.is_valid() else resolve_rect
		var source: Rect2 = transfer.call(int(event.seat)); var destination: Rect2 = transfer.call(int(event.target))
		if not source.has_area() or not destination.has_area(): continue
		for note in 5:
			var travel := clampf(progress * 1.6 - note * .12, 0, 1)
			if travel <= 0 or travel >= 1: continue
			var center := source.get_center().lerp(destination.get_center(), travel)
			center.x += sin(travel * PI) * (62 + note * 5)
			draw_set_transform(center, sin(travel * TAU) * .2)
			var icon := icon_texture if icon_texture != null else cash_icon
			if icon != null:
				var dimensions := icon.get_size() * minf(48 / icon.get_size().x, 32 / icon.get_size().y)
				draw_texture_rect(icon, Rect2(-dimensions / 2, dimensions), false, Color(1, 1, 1, alpha))
			draw_set_transform(Vector2.ZERO)


func amount_text(amount: int) -> String:
	return ("+" if amount > 0 else "−") + amount_prefix + str(absi(amount))


static func amount_rect(balance: Rect2, amount: int, progress: float) -> Rect2:
	var distance := progress * 18
	var top := balance.position.y - 32 - distance if amount > 0 else balance.end.y + 4 + distance
	return Rect2(Vector2(balance.get_center().x - 46, top), Vector2(92, 28))
