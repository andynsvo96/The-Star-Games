extends Control

signal seat_pressed(seat: int)
const Evaluator = preload("res://Games/poker/host/evaluator.gd")
var view: Dictionary = {}
var texture: Texture2D
var elapsed := 0.0
var local_motion := 0.0
var motion_revision := -1
var chip_icon: Texture2D
var dock_rect := Rect2()
var private_canvas: Control


func _ready() -> void:
	texture = RuntimeAssets.texture("res://Games/poker/art/table.png")
	chip_icon = RuntimeAssets.texture("res://Games/poker/art/chip.svg")
	resized.connect(queue_redraw); mouse_filter = Control.MOUSE_FILTER_STOP
	accessibility_name = "Poker table, community cards, pot and current bets"


func set_view(value: Dictionary) -> void:
	view = value
	var revision := int(view.get("motion", {}).get("revision", -1))
	if revision != motion_revision: motion_revision = revision; local_motion = float(view.get("motion", {}).get("elapsed", 0))
	else: local_motion = maxf(local_motion, float(view.get("motion", {}).get("elapsed", 0)))
	queue_redraw()
	if private_canvas != null: private_canvas.queue_redraw()


func _process(delta: float) -> void:
	if view.is_empty() or view.get("paused", true): return
	if not view.get("reduced_motion", false):
		elapsed += delta; local_motion += delta; queue_redraw()
		if private_canvas != null: private_canvas.queue_redraw()


func table_height() -> float:
	return maxf(100, (size.y - 16) / 1.3) if int(view.get("viewer", -1)) >= 0 else size.y


func private_layout() -> Dictionary:
	var count := 4 if view.get("variant") == "omaha" else 2
	var gap := 8.0
	var dock := dock_rect if dock_rect.has_area() else Rect2(Vector2(0, size.y + 8), Vector2(size.x, 168))
	if dock.size.x < 500:
		var card_width := minf(64, (dock.size.x - 28 - (count - 1) * gap) / count)
		var hand_width := card_width * count + gap * (count - 1)
		var compact_width := minf(148, (dock.size.x - 64) / 2)
		var left := dock.position.x + (dock.size.x - compact_width * 2 - 16) / 2
		return {"hand": Rect2(Vector2(dock.get_center().x - hand_width / 2, dock.position.y + 14), Vector2(hand_width, card_width * 1.5)), "left": Rect2(Vector2(left, dock.end.y - 139), Vector2(compact_width, 94)), "right": Rect2(Vector2(left + compact_width + 16, dock.end.y - 162), Vector2(compact_width, 140)), "stats": Rect2(dock.position + Vector2(24, 122), Vector2(dock.size.x - 48, 58))}
	var side_width := clampf(dock.size.x * .14, 108, 148)
	var stats_width := clampf(dock.size.x * .14, 110, 176)
	var hand_limit := dock.size.x - side_width * 2 - 64
	if dock.size.x >= 800: hand_limit = dock.size.x - 2 * (14 + stats_width + 16 + side_width + 16)
	var card_width := minf(88, (hand_limit - (count - 1) * gap) / count)
	var hand_width := card_width * count + (count - 1) * gap
	var center := Vector2(dock.get_center().x, dock.position.y + (84 if dock.size.x < 800 else dock.size.y / 2))
	var hand := Rect2(center - Vector2(hand_width, card_width * 1.5) / 2, Vector2(hand_width, card_width * 1.5))
	var stats := Rect2(Vector2(dock.position.x + 24, dock.end.y - 70), Vector2(dock.size.x - 48, 56)) if dock.size.x < 800 else Rect2(dock.position + Vector2(24, 18), Vector2(stats_width - 10, dock.size.y - 40))
	return {"hand": hand, "left": Rect2(Vector2(hand.position.x - 16 - side_width, center.y - 47), Vector2(side_width, 94)), "right": Rect2(Vector2(hand.end.x + 16, center.y - 70), Vector2(side_width, 140)), "stats": stats}


func seat_rect(seat: int) -> Rect2:
	if seat == int(view.get("viewer", -1)):
		var width := minf(280, size.x * .82)
		var height := clampf(table_height() * .16, 60, 68)
		return Rect2(Vector2((size.x - width) / 2, size.y - height - 6), Vector2(width, height))
	var angle := PI / 2 + TAU * seat / maxi(2, view.get("players", []).size())
	var dense: bool = view.get("players", []).size() > 4
	var badge := Vector2(minf(210, size.x * (.21 if size.x < 800 else .18)) if dense else minf(240, maxf(154, size.x * .25)), clampf(table_height() * (.13 if dense else .16), 60 if not dense and size.x >= 760 else 42, 68))
	var center := Vector2(size.x * .5 + cos(angle) * size.x * .40, table_height() * .5 + sin(angle) * table_height() * .34)
	if dense and table_height() < 230:
		badge.x = minf(140, size.x * .15)
		center.x = size.x * .5 + cos(angle) * size.x * .45
		center.y = table_height() * .5 + signf(sin(angle)) * sqrt(absf(sin(angle))) * (table_height() * .5 - badge.y * .5 - 4)
	return Rect2(center - badge / 2, badge)


func counter_scale() -> float:
	return clampf(minf(size.x / 1120, table_height() / 460), .5, 1.45)


func felt_rect() -> Rect2:
	return Rect2(Vector2(size.x * .25, table_height() * .22), Vector2(size.x * .50, table_height() * .56))


func bet_rect(seat: int) -> Rect2:
	var bounds := seat_rect(seat); var width := minf(64, bounds.size.x * .31)
	return Rect2(Vector2(bounds.end.x - width - 5, bounds.position.y + maxf(28, bounds.size.y * .57) - 12), Vector2(width, 16))


func revealed_hand(seat: int) -> Array:
	var result: Array = []
	if view.get("phase") != "runout" or seat == int(view.get("viewer", -1)): return result
	var player: Dictionary = view.players[seat]
	if player.folded or player.hand.is_empty(): return result
	var badge := seat_rect(seat)
	var pivot := Vector2(badge.get_center().x, badge.position.y + badge.size.y * .52)
	var height := minf(minf(56, badge.size.x * .28) * 1.5, maxf(12, pivot.y - 5) * .92)
	var width := height / 1.5
	for index in player.hand.size():
		var offset := float(index) - float(player.hand.size() - 1) / 2
		result.append({"pivot": pivot + Vector2(offset * width * .62, 0), "angle": offset * (.32 if player.hand.size() == 2 else .18), "rect": Rect2(Vector2(-width / 2, -height), Vector2(width, height)), "card": int(player.hand[index])})
	return result


func action_font_size(text: String, width: float, status_size: int) -> int:
	var font := get_theme_default_font()
	var fitted := status_size
	while fitted > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > width: fitted -= 1
	return fitted


func counter_rect(right := false) -> Rect2:
	var factor := counter_scale()
	var top := table_height() * .26
	for seat in view.get("players", []).size():
		if seat == int(view.get("viewer", -1)): continue
		var badge := seat_rect(seat)
		if badge.get_center().y < table_height() * .5 and badge.position.x < size.x * .5 + 158 * factor and badge.end.x > size.x * .5 - 158 * factor: top = maxf(top, badge.end.y + 8)
	return Rect2(Vector2(size.x * .5 + (8 if right else -158) * factor, top), Vector2(150, 74) * factor)


func resolve(zone: Dictionary) -> Rect2:
	var kind := str(zone.get("zone", "deck")); var index := int(zone.get("index", 0)); var seat := int(zone.get("seat", 0))
	if kind == "board":
		var top := maxf(table_height() * .44, counter_rect().end.y + 10)
		var width := minf(120, minf(size.x * .083, maxf(8, (felt_rect().end.y - top - 6) / 1.5)))
		for player in view.get("players", []).size():
			if player == int(view.get("viewer", -1)): continue
			var badge := seat_rect(player)
			if badge.end.y <= top - 8 or badge.position.y >= top + width * 1.5 + 8: continue
			var vertical_room := maxf(0, (badge.position.y - top - 8) / 1.5)
			var side_room := maxf(0, size.x * .5 - badge.end.x - 8) if badge.get_center().x < size.x * .5 else maxf(0, badge.position.x - size.x * .5 - 8)
			width = minf(width, maxf(vertical_room, side_room * 2 / 5.4))
		var gap := width * .10
		return Rect2(Vector2(size.x * .5 - (width * 5 + gap * 4) / 2 + index * (width + gap), top), Vector2(width, width * 1.5))
	if kind == "hand":
		if seat != int(view.get("viewer", -1)):
			var target := seat_rect(seat); var card_width := minf(34, target.size.y * .7)
			return Rect2(target.get_center() - Vector2(card_width, card_width * 1.5) / 2, Vector2(card_width, card_width * 1.5))
		var layout: Dictionary = private_layout(); var count := 4 if view.get("variant") == "omaha" else 2
		var width: float = (layout.hand.size.x - 8 * (count - 1)) / count
		return Rect2(layout.hand.position + Vector2(index * (width + 8), 0), Vector2(width, width * 1.5))
	var width := minf(48, size.x * .04)
	return Rect2(Vector2(counter_rect().position.x - width - 12, counter_rect().position.y), Vector2(width, width * 1.5))


func _arrived(zone: String, index: int, seat := 0) -> bool:
	if view.get("reduced_motion", false): return true
	for flight in view.get("motion", {}).get("flights", []):
		if flight.to.zone == zone and int(flight.to.get("index", 0)) == index and int(flight.to.get("seat", 0)) == seat and local_motion < float(flight.delay) + float(flight.duration): return false
	return true


func _draw() -> void:
	if view.get("type") != "state": return
	var h := table_height()
	if texture != null: draw_texture_rect(texture, Rect2(Vector2(0, -.10 * h), Vector2(size.x, h * 1.40)), false)
	var scale_factor := clampf(size.x / 1120, .5, 1.45)
	for seat in view.players.size():
		for face in revealed_hand(seat):
			draw_set_transform(face.pivot, float(face.angle))
			GameCard.paint(self, face.rect, Evaluator.card_data(int(face.card)), null, Color.WHITE)
			draw_set_transform(Vector2.ZERO)
	for seat in view.players.size():
		var player: Dictionary = view.players[seat]; var identity: Dictionary = view.identities[seat]; var bounds := seat_rect(seat)
		var active: bool = int(view.turn) == seat and not view.paused and view.phase == "betting" and not player.out
		var avatar_width := minf(bounds.size.y - 4, bounds.size.x * .25)
		var avatar := Rect2(bounds.position + Vector2(0, (bounds.size.y - avatar_width) / 2), Vector2.ONE * avatar_width)
		var plaque_bounds := Rect2(bounds.position + Vector2(avatar_width * .40, 2), bounds.size - Vector2(avatar_width * .40, 4))
		draw_style_box(GameLook.casino_player_sheet(active), plaque_bounds)
		GameLook.draw_table_avatar(self, avatar, Color(identity.color), int(identity.pose))
		var x := avatar.end.x + 7; var text_width := bounds.end.x - x - 8
		var name_size := maxi(11, mini(int(20 * scale_factor), int(bounds.size.y * .29)))
		if bounds.size.x < 120: name_size = 10
		var status_size := maxi(10, mini(int(13 * scale_factor), int(bounds.size.y * .24)))
		GameLook.draw_table_text(self, str(identity.display_name), Vector2(x, bounds.position.y + maxf(15, bounds.size.y * .30)), text_width, name_size, Color("f4f5ef"))
		var status := "OUT" if player.out else "WINNER" if view.phase in ["hand_over", "finished"] and view.hand_winners.has(seat) else "FOLDED" if player.folded else "ALL IN" if player.all_in else "SMALL BLIND" if seat == int(view.small_seat) and view.stage == "preflop" else "BIG BLIND" if seat == int(view.big_seat) and view.stage == "preflop" else "IN HAND"
		var details_width: float = text_width - (bet_rect(seat).size.x + 4 if int(player.street) > 0 else 0)
		GameLook.draw_table_text(self, status, Vector2(x, bounds.position.y + maxf(28, bounds.size.y * .57)), details_width, status_size, get_theme_color("muted", "GamePalette"))
		var last_amount := int(player.get("last_amount", 0))
		var action := "RAISED +%d" % last_amount if player.last_action == "raise" and last_amount > 0 else "CALLED %d" % last_amount if player.last_action == "call" and last_amount > 0 else "CHECKED" if player.last_action == "check" else ""
		GameLook.draw_table_text(self, action, Vector2(x, bounds.position.y + maxf(40, bounds.size.y * .84)), text_width, action_font_size(action, text_width, status_size), get_theme_color("success", "GamePalette") if player.last_action == "raise" else get_theme_color("font_color", "Label"))
		if int(player.street) > 0:
			var bet := bet_rect(seat); var point := Vector2(bet.position.x + 6, bet.get_center().y)
			_chip(point, .6, Color("165a99")); GameLook.draw_table_text(self, _chips(int(player.street)), point + Vector2(12, 4), bet.size.x - 18, 10 if bet.size.x < 50 else 12, get_theme_color("gold", "GamePalette"))
		if player.out or player.folded: draw_style_box(GameLook.box(Color("11130fa6"), Color.TRANSPARENT, 12, 0), bounds)
	var plaque := counter_rect()
	_counter(plaque, "POT", int(view.pot), counter_scale())
	_counter(counter_rect(true), "BET TO MATCH", int(view.current_bet), counter_scale())
	var winning: Array = []
	for seat in view.hand_winners: winning.append_array(view.winning_cards.get(str(int(seat)), []))
	for index in 5:
		var shown: bool = index < view.board.size() and _arrived("board", index)
		var data := Evaluator.card_data(int(view.board[index])) if shown else {"layout": "standard", "back": true}
		GameCard.paint(self, resolve({"zone": "board", "index": index}), data, null, Color.WHITE, shown and winning.has(view.board[index]))
	if int(view.viewer) >= 0 and private_canvas == null:
		for index in view.hand.size():
			if _arrived("hand", index, int(view.viewer)): GameCard.paint(self, resolve({"zone": "hand", "seat": int(view.viewer), "index": index}), Evaluator.card_data(int(view.hand[index])), null, Color.WHITE, view.hand_winners.has(view.viewer) and winning.has(view.hand[index]))
	if not view.reduced_motion and not view.paused:
		if view.motion.active and not view.motion.flights.is_empty(): GameCard.paint(self, resolve({"zone":"deck"}), {"layout":"standard","back":true}, null, Color.WHITE)
		for flight in view.motion.flights:
			if private_canvas != null and flight.to.zone == "hand" and int(flight.to.get("seat", -1)) == int(view.viewer): continue
			var progress := GameCardMotion.progress(flight, local_motion)
			if progress <= 0 or progress >= 1: continue
			var tint := Color.WHITE
			if flight.to.zone == "hand" and int(flight.to.get("seat", -1)) != int(view.viewer): tint.a = minf(1, (1 - progress) * 4)
			GameCard.paint(self, GameCardMotion.travel(resolve(flight.from), resolve(flight.to), progress), flight.card, null, tint)
		for flight in view.motion.get("chips", []):
			var progress := clampf(local_motion / .6, 0, 1)
			if progress >= 1: continue
			var seat_point := bet_rect(int(flight.seat)).get_center(); var pot_point := plaque.get_center()
			var point := (pot_point if flight.award else seat_point).lerp(seat_point if flight.award else pot_point, 1 - pow(1 - progress, 3))
			_chip(point, scale_factor, Color("b72c30") if flight.award else Color("165a99"))


func draw_private_hand(canvas: Control) -> void:
	if view.get("type") != "state" or int(view.get("viewer", -1)) < 0: return
	var offset := global_position - canvas.global_position
	var winning: Array = view.winning_cards.get(str(int(view.viewer)), []) if view.hand_winners.has(view.viewer) else []
	for index in view.hand.size():
		if not _arrived("hand", index, int(view.viewer)): continue
		var bounds := resolve({"zone": "hand", "seat": int(view.viewer), "index": index})
		GameCard.paint(canvas, Rect2(bounds.position + offset, bounds.size), Evaluator.card_data(int(view.hand[index])), null, Color.WHITE, winning.has(view.hand[index]))
	if view.reduced_motion or view.paused: return
	for flight in view.motion.flights:
		if flight.to.zone != "hand" or int(flight.to.get("seat", -1)) != int(view.viewer): continue
		var progress := GameCardMotion.progress(flight, local_motion)
		if progress <= 0 or progress >= 1: continue
		var bounds := GameCardMotion.travel(resolve(flight.from), resolve(flight.to), progress)
		GameCard.paint(canvas, Rect2(bounds.position + offset, bounds.size), flight.card, null, Color.WHITE)


func _counter(bounds: Rect2, caption: String, amount: int, scale_factor: float) -> void:
	draw_style_box(GameLook.casino_frame(false, true), bounds)
	GameLook.draw_table_text(self, caption, bounds.position + Vector2(0, 23) * scale_factor, bounds.size.x, maxi(10, int(14 * scale_factor)), get_theme_color("font_color", "Label"), true)
	GameLook.draw_table_text(self, _chips(amount), bounds.position + Vector2(0, 58) * scale_factor, bounds.size.x, maxi(20, int(32 * scale_factor)), get_theme_color("gold", "GamePalette"), true)


func _chips(value: int) -> String: return String.num_int64(value).replace(",", "")


func _chip(point: Vector2, scale_factor: float, color: Color) -> void:
	for layer in 3:
		var center := point + Vector2(0, -layer * 3 * scale_factor)
		draw_circle(center, 10 * scale_factor, Color("e3bc72")); draw_circle(center, 8.5 * scale_factor, color)
		for index in 6:
			var angle := index * TAU / 6; draw_line(center + Vector2.from_angle(angle) * 6 * scale_factor, center + Vector2.from_angle(angle) * 9 * scale_factor, Color("fff0d2"), 2 * scale_factor)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and view.get("showdown", false):
		for seat in view.players.size():
			if seat_rect(seat).has_point(event.position) and not view.players[seat].hand.is_empty(): seat_pressed.emit(seat); accept_event(); return
