extends SceneTree

const Rules = preload("res://Games/uno/host/rules.gd")
const Host = preload("res://Games/uno/host/main.tscn")
const Presentation = preload("res://Games/uno/host/presentation.gd")
var failures := 0
var checks := 0


func _init() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var icons: Array[String] = []
	for key: String in Presentation.catalog.options:
		var items := Presentation.rule_items({"gamemode":"no_mercy" if key == "allow_mercy" else "classic", "options":{key:true}})
		check(items.size() == 2 and not str(items[1].detail).is_empty(), "Only the enabled rule appears, with its explanation: " + key)
		check(FileAccess.file_exists(items[1].icon) and not icons.has(items[1].icon), "Every house rule has a distinct offline icon: " + key)
		check(items[0].section == "Game Mode" and items[1].section == "House Rules", "Mode and house rules have separate headings")
		check(items[1].keys().all(func(field: String) -> bool: return field in ["title", "detail", "icon", "section"]), "Rule presentation contains only public labels and artwork")
		icons.append(items[1].icon)
	var addon_items := Presentation.rule_items({"active_addons":Presentation.catalog.addons.keys()}).slice(1)
	for item: Dictionary in addon_items:
		check(item.section == "Add-Ons" and FileAccess.file_exists(item.icon) and not icons.has(item.icon), "Every add-on has a distinct offline icon under Add-Ons: " + str(item.title))
		icons.append(item.icon)
	var grouped := GameRulesPanel.new()
	root.add_child(grouped)
	grouped.set_items(Presentation.rule_items({"options":{"allow_stacking":true}, "active_addons":["Speed"]}))
	check(grouped.rows.get_children().filter(func(row: Node) -> bool: return row is Label).map(func(row: Label) -> String: return row.text) == ["GAME MODE", "HOUSE RULES", "ADD-ONS"], "Shared rules panel renders all three section headings in order")
	grouped.set_items([{"title":"Example", "detail":"Ungrouped", "icon":"res://ui/playful/table-cards.svg"}])
	check(grouped.rows.get_child_count() == 1 and grouped.rows.get_child(0) is HBoxContainer, "Existing ungrouped shared rules lists retain their layout")
	grouped.queue_free()
	var unsorted := [{"id":8,"color":"wild","kind":"draw10"},{"id":4,"color":"blue","kind":"2"},{"id":3,"color":"red","kind":"7"},{"id":2,"color":"red","kind":"2"},{"id":1,"color":"red","kind":"2"},{"id":5,"color":"green","kind":"reverse"},{"id":7,"color":"wild","kind":"draw6"},{"id":6,"color":"yellow","kind":"9"}]
	var original: Array = unsorted.duplicate(true)
	check(Rules.sorted_hand(unsorted).map(func(card: Dictionary) -> int: return card.id) == [1,2,3,6,5,4,7,8], "Grouped colors, numeric order, stable duplicates and Wilds last")
	check(unsorted == original, "Sorting does not change the authoritative hand or card identities")
	var dark := [{"id":3,"color":"purple","kind":"3"},{"id":1,"color":"pink","kind":"9"},{"id":2,"color":"teal","kind":"2"},{"id":4,"color":"wild","kind":"wild"}]
	check(Rules.sorted_hand(dark,Rules.DARK_COLORS).map(func(card: Dictionary) -> int: return card.id) == [1,2,3,4], "Flip sorts using the active side's palette")
	for mode in Rules.GAMEMODES:
		var rules := Rules.new()
		rules.set_gamemode(mode)
		rules.start(4)
		if mode == "flip":
			rules.side = "light"
			rules._activate_faces()
		rules.allow_seven_zero = true
		rules.phase = "play"
		rules.turn = 0
		rules.pending_draw = 0
		rules.pending_color = ""
		rules.drawn = -1
		rules.color = "red"
		var seven: int = rules.cards.filter(func(card: Dictionary) -> bool: return card.color == "red" and card.kind == "7")[0].id
		rules.hands[0] = [seven] + rules.hands[0].filter(func(id: int) -> bool: return id != seven).slice(0,4)
		check(rules.play(0,seven) and rules.swap_hands(0,1), "Seven exchanges hands in " + mode)
		var transfers: Array = rules.view_for(-1).motion.flights
		check(transfers.size() == 2 and transfers[0].start == transfers[1].start and is_equal_approx(Rules.motion_duration(rules.motion),.72), "Exchange animation duration is one simultaneous interval in " + mode)
		check(transfers.all(func(flight: Dictionary) -> bool: return flight.card.is_empty() and flight.hand_count > 1 and (not flight.has("backs") or flight.backs.all(func(back: Dictionary) -> bool: return not back.has("id")))), "Transfer fans expose counts and visible backs, never active opposing cards")
		if mode != "flip":
			var zero: int = rules.cards.filter(func(card: Dictionary) -> bool: return card.color == "red" and card.kind == "0")[0].id
			rules.turn = 0
			rules.color = "red"
			rules.hands[0].append(zero)
			check(rules.play(0,zero), "Zero rotates all hands in " + mode)
			transfers = rules.view_for(-1).motion.flights.slice(1)
			check(transfers.size() == 4 and transfers.all(func(flight: Dictionary) -> bool: return is_equal_approx(flight.start,.48)) and is_equal_approx(Rules.motion_duration(rules.motion),1.20), "All Zero fans share one start and settle after the played card in " + mode)
		for card in rules.cards:
			var key := Rules.card_art_prefix(card,mode) + "%s-%s" % [card.color,card.kind]
			check(ResourceLoader.exists("res://Games/uno/art/cards/%s.svg" % key), "Every mode's active card face is bundled offline: " + key)
	var host := Host.instantiate()
	root.add_child(host)
	var context := GameSessionContext.new("uno",[],{"id":"host","display_name":"Host","color":"#2463eb"},false)
	context.reduced_motion = true
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	host.initialize_session(context)
	host.start_game()
	for timer in [host.ai_timer,host.auto_timer,host.catch_timer,host.jump_timer]: timer.process_mode = Node.PROCESS_MODE_DISABLED
	var original_name: String = host.seats[0].display_name
	host.seats[0].display_name = "Host [b]literal[/b]"
	check(host._snapshot(0).players[0].display_name == "Host [b]literal[/b]", "Player names remain literal in authoritative snapshots")
	host.seats[0].display_name = original_name
	for definition in host.RULE_OPTIONS:
		var button: Button = host.rule_choices[definition[0]]
		for enabled in [true,false]:
			button.button_pressed = enabled
			host._refresh_options()
			for style in ["normal","hover","pressed","disabled"]:
				var surface: StyleBoxFlat = button.get_theme_stylebox(style)
				check(surface.border_color.g > surface.border_color.r if enabled else surface.border_color.r > surface.border_color.g, "Rule colors retain ON/OFF meaning in every button state")
	# Authoritative lock lasts one grouped interval, including tables with many cards.
	host.rules.allow_seven_zero = true
	host.rules.phase = "play"
	host.rules.turn = 0
	host.rules.color = "red"
	host.rules.pending_draw = 0
	host.rules.drawn = -1
	host.rules.hands = [[0,3,5,7],[27,29,31,33],[53,55,57,59],[79,81,83,85]]
	host.rules.discard = [17]
	host.rules.revision += 1
	host.session.reduced_motion = false
	host._publish()
	host._local_action({"action":"play","card":0})
	var revision: int = host.rules.revision
	check(host.animating and host.motion_timer.time_left <= 1.21 and host.motion_timer.time_left > 1.1, "Zero locks the host for the shared transfer timeline")
	host._local_action({"action":"draw"})
	check(host.rules.revision == revision, "Input during whole-hand rotation is discarded")
	host.shutdown_game()
	check(host.table.flights.is_empty() and host.table.swap_buttons.all(func(button: Button) -> bool: return not button.visible), "Exit cancels transfers and name targeting")
	host.queue_free()
	await process_frame
	await create_timer(.15).timeout
	print("UNO presentation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
