extends Control

var ui
var motion
var elapsed := 0.0
var active := false
var reduced := false
var paused := false
var feedback_revision := -1
var static_doubles := 0.0
var source_revision := -1
var source_cards: Dictionary = {}
var chest_base: Texture2D
var chest_lid: Texture2D
var card_effect := GameCardEffect.new()
var cash := GameMoneyEffect.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); z_index = 8
	add_child(card_effect); add_child(cash)
	cash.resolve_rect = money_rect; cash.resolve_transfer_rect = player_rect
	reload_assets()


func reload_assets() -> void:
	chest_base = RuntimeAssets.texture("res://Games/monopoly-classic/art/space-chest-base.svg")
	chest_lid = RuntimeAssets.texture("res://Games/monopoly-classic/art/space-chest-lid.svg")


func player_rect(seat: int) -> Rect2:
	if seat < 0 or seat >= ui.player_cards.size(): return Rect2()
	var label: Control = ui.player_cards[seat].player
	return label.get_global_rect() if label.is_visible_in_tree() else Rect2()


func money_rect(seat: int) -> Rect2:
	if seat < 0 or seat >= ui.player_cards.size(): return Rect2()
	var label: Control = ui.player_cards[seat].score
	return label.get_global_rect() if label.is_visible_in_tree() else Rect2()


func capture_sources() -> void:
	if motion == null or source_revision == motion.revision: return
	source_revision = motion.revision; source_cards.clear()
	for seat in ui.player_cards.size():
		for tile in ui.player_cards[seat].portfolio.get_children():
			source_cards["%d:%d" % [seat, int(tile.get_meta("grid_entry").card.id)]] = tile.get_global_rect()


func property_rect(seat: int, id: int, source := false) -> Rect2:
	var key := "%d:%d" % [seat, id]
	if source and source_cards.has(key): return source_cards[key]
	if seat >= 0 and seat < ui.player_cards.size():
		for tile in ui.player_cards[seat].portfolio.get_children():
			if int(tile.get_meta("grid_entry").card.id) == id: return tile.get_global_rect()
	return zone_rect({"zone":"player", "seat":seat})


func zone_rect(zone: Dictionary) -> Rect2:
	var board: Rect2 = ui.board.get_global_rect()
	match str(zone.zone):
		"player":
			var name := player_rect(int(zone.seat))
			return Rect2(name.get_center() - Vector2(22, 33), Vector2(44, 66))
		"reveal":
			var height := minf(230, size.y * .42)
			return Rect2(size * Vector2(.5, .43) - Vector2(height / 3, height / 2), Vector2(height * 2 / 3, height))
	var point := Vector2(230 if zone.zone == "community" else 640, 520)
	return Rect2(board.position + point * board.size / 1000, Vector2(105, 157) * board.size / 1000)


func update(is_paused: bool) -> void:
	if motion == null: return
	elapsed = ui.host.motion_elapsed; active = ui.host._animating(); reduced = ui.host.session.reduced_motion
	paused = is_paused
	if feedback_revision >= 0 and feedback_revision != motion.revision and reduced and motion.specials.any(func(effect: Dictionary) -> bool: return effect.kind == "doubles"): static_doubles = .85
	feedback_revision = motion.revision
	var snapshot: Dictionary = motion.view(elapsed, active)
	cash.update(snapshot, is_paused, reduced)
	var current: Array = snapshot.effects.filter(func(effect: Dictionary) -> bool: return elapsed >= float(effect.start) and elapsed < float(effect.start) + float(effect.duration))
	snapshot.effects = current if not reduced else snapshot.effects.slice(0, 1)
	card_effect.update(snapshot, is_paused, reduced)
	for seat in ui.player_cards.size():
		for tile in ui.player_cards[seat].portfolio.get_children():
			var id := int(tile.get_meta("grid_entry").card.id)
			tile.modulate.a = 0 if active and not reduced and motion.cards.flights.any(func(flight: Dictionary) -> bool: return flight.to.get("zone") == "player" and int(flight.to.seat) == seat and flight.card.get("id", -1) == id and elapsed < float(flight.delay) + float(flight.duration)) else 1
	queue_redraw()


func clear() -> void:
	active = false; static_doubles = 0; cash.clear(); card_effect.update({}, true, false); queue_redraw()


func _process(delta: float) -> void:
	if not paused and static_doubles > 0:
		static_doubles = maxf(0, static_doubles - delta); queue_redraw()


func _draw() -> void:
	if motion == null: return
	for special in motion.specials:
		var progress := (elapsed - float(special.start)) / float(special.duration)
		if reduced:
			if special.kind != "doubles" or static_doubles <= 0: continue
			progress = .4
		elif not active or progress < 0 or progress >= 1: continue
		var center: Vector2 = ui.board.get_global_rect().get_center()
		var height := minf(180, ui.board.size.y * .42)
		var alpha := minf(1, progress * 8) * minf(1, (1 - progress) * 5)
		if special.kind == "doubles":
			var width := minf(230, ui.board.size.x * .65)
			var banner := Rect2(center - Vector2(width / 2, 28), Vector2(width, 56))
			draw_style_box(GameLook.modern_table_sheet(true), banner)
			GameLook.draw_table_text(self, "DOUBLES!", banner.position + Vector2(8, 38), width - 16, 27, Color("ffdf74"), true)
			if not reduced:
				for spark in 12:
					var angle := spark * TAU / 12
					var point := center + Vector2(cos(angle), sin(angle)) * (height * (.35 + progress * .5))
					draw_circle(point, 3.5, Color(1, .82, .24, alpha))
		elif special.kind == "chest":
			draw_circle(center, height * .7, Color(1, .8, .2, alpha * .25))
			draw_set_transform(center, 0, Vector2.ONE * height / 130)
			if chest_base != null: draw_texture_rect(chest_base, Rect2(-80, -65, 160, 130), false, Color(1, 1, 1, alpha))
			# The lid lifts around its rear hinge, rather than moving the whole chest.
			var opening := sin(minf(1, progress * 2.5) * PI / 2)
			draw_set_transform(center + Vector2(0, -opening * height * .3), -opening * .22, Vector2(height / 130, height / 130 * (1 - opening * .55)))
			if chest_lid != null: draw_texture_rect(chest_lid, Rect2(-80, -65, 160, 130), false, Color(1, 1, 1, alpha))
			draw_set_transform(Vector2.ZERO)
		else:
			var cell := Rect2(center - Vector2(height * .55, height * .6), Vector2(height * 1.1, height * 1.2))
			draw_style_box(GameLook.box(Color("223c46"), Color("a5b9ba"), 9, 5), cell)
			var seat := int(special.seat)
			draw_circle(center, height * .24, Color(str(ui.host.seats[seat].color)))
			if seat < ui.board.tokens.size(): draw_texture_rect(ui.board.tokens[seat], Rect2(center - Vector2.ONE * height * .28, Vector2.ONE * height * .56), false)
			var closed := smoothstep(0, 1, minf(1, progress / .46))
			for bar in 6:
				var x := cell.position.x + cell.size.x * (bar + .5) / 6 + (-1 if bar < 3 else 1) * (1 - closed) * height * .7
				if x >= cell.position.x and x <= cell.end.x:
					draw_line(Vector2(x + 2, cell.position.y + 5), Vector2(x + 2, cell.end.y - 5), Color("111d22"), 9)
					draw_line(Vector2(x, cell.position.y + 5), Vector2(x, cell.end.y - 5), Color("b6c7cd"), 5)
			GameLook.draw_table_text(self, "GO TO JAIL", Vector2(cell.position.x, cell.end.y + 27), cell.size.x, 20, Color("ffcf57"), true)
	for flight in motion.cards.flights:
		if not active or reduced: break
		var progress := GameCardMotion.progress(flight, elapsed)
		if elapsed < float(flight.delay) or progress >= 1: continue
		var rect := GameCardMotion.travel(zone_rect(flight.from), zone_rect(flight.to), progress)
		if flight.from.zone == "player" and flight.to.zone == "player":
			var id := int(flight.card.get("id", -1))
			rect = GameCardMotion.travel(property_rect(int(flight.from.seat), id, true), property_rect(int(flight.to.seat), id), progress)
			var center := rect.get_center(); rect.size *= 1 + sin(progress * PI) * .65; rect.position = center - rect.size / 2
		GameCard.paint(self, rect, flight.card, GameCard.artwork("res://Games/monopoly-classic/art/%s.svg" % flight.card.key), Color("9aafa1"))
