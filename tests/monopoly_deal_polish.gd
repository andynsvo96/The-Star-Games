extends SceneTree

var failures := 0
var checks := 0
var host: Node

func _init() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func take(key: String, seat: int, bank := false) -> int:
	var id: int = host.rules.deck.filter(func(value: int) -> bool: return host.rules.cards[value].key == key)[0]
	host.rules.deck.erase(id)
	if bank: host.rules.banks[seat].append(id)
	else: host.rules.hands[seat].append(id)
	return id

func _run() -> void:
	seed(471021)
	host = load("res://Games/monopoly-deal/host/main.tscn").instantiate(); root.add_child(host); host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	var players := [{"id":"a","display_name":"Alex","color":"#2463eb"},{"id":"b","display_name":"Sam","color":"#08a750"},{"id":"c","display_name":"Nina","color":"#e53935"}]
	var context := GameSessionContext.new("monopoly-deal", players, {}, true); context.reduced_motion = true; host.initialize_session(context); host.start_game()
	for seat in 3:
		host.rules.hands[seat].clear(); host.rules.banks[seat].clear(); host.rules.properties[seat].clear()
	host.rules.deck = range(host.rules.cards.size()); host.rules.discard.clear()
	for key in ["mediterranean-avenue","baltic-avenue"]:
		var id := take(key, 0); host.rules.hands[0].erase(id); host.rules._receive_property(0, id, "brown")
	var rent := take("rent-light-blue-brown", 0); var double := take("double-rent", 0); var debt := take("debt-collector", 1); var refusal := take("just-say-no", 0)
	take("money-10", 0, true)
	var payable_property := take("boardwalk", 2); host.rules.hands[2].erase(payable_property); host.rules._receive_property(2, payable_property, "dark-blue")
	var command := {"action":"rent","card":rent,"group":host.rules.properties[0][0].id,"double":[double]}
	var before := JSON.stringify(host.rules.view_for(-1)); var preview: Dictionary = host.rules.preview_for(0, command)
	check(preview.amount == 4 and preview.targets == [1,2] and preview.counterable, "Rent preview includes the exact multiplied charge and every affected opponent")
	check(JSON.stringify(host.rules.view_for(-1)) == before, "Previewing never consumes a card, changes a turn or resolves an action")
	var private_view: Dictionary = host._snapshot(0)
	check(private_view.actions.any(func(choice: Dictionary) -> bool: return choice.payload == command and choice.preview.amount == 4), "Private offered commands carry their authoritative preview")
	check(host._snapshot(-1).actions.is_empty() and not JSON.stringify(preview).contains("hands"), "Public packets never gain private legal options or hidden hands")
	host.host_plays = true; host._publish(); host._select_card(host.rules.cards[rent])
	check(host.reader.preview.visible and host.reader.preview.options[0].players.size() == 2, "An action reader shows the affected players before committing")
	var own_debt := take("debt-collector", 0)
	for index in 10: take("money-1" if index < 6 else "money-2", 1, true)
	host.rules.revision += 1; host._publish(); host._select_card(host.rules.cards[own_debt])
	var choices: GameActionPreview = host.reader.preview
	check(choices.presentation == "players" and not choices.selector.visible and choices.player_buttons.size() == 2, "Debt Collector shows every legal opponent directly without a dropdown")
	check(choices.options[0].players[0].bank_total == 14 and choices.options[0].items.size() == 10 and choices.options[1].players[0].bank_total == 0, "Debt options include exact bank totals, every bank card and empty-bank opponents")
	check(choices.options.all(func(option: Dictionary) -> bool: return option.summary.is_empty() and option.note.is_empty()), "Debt options omit request and counter instructions")
	choices.player_buttons[1].pressed.emit()
	check(choices.selected == 1 and host.rules.tap_choices(0, own_debt)[choices.selected].payload.target == 2 and host.rules.phase == "play", "Selecting an opponent changes only the offered target until Play")
	var fan: GameCardFan = choices.body.get_child(0).get_child(1)
	await process_frame; await process_frame
	var pointer := InputEventMouseButton.new(); pointer.button_index = MOUSE_BUTTON_LEFT; pointer.pressed = true; pointer.position = fan.next.get_global_rect().get_center(); pointer.global_position = pointer.position
	root.push_input(pointer, true); await process_frame; var first_offset: float = fan.offset
	await create_timer(0.35).timeout; pointer.pressed = false; root.push_input(pointer, true); await process_frame
	check(first_offset > 0 and fan.offset > first_offset and fan.visible_cards == 5, "Holding a bank's end stack repeatedly browses beyond five visible cards (%s -> %s, target %s, viewport %s)" % [first_offset, fan.offset, fan.next.get_global_rect(), root.get_visible_rect()])
	var settled: float = fan.offset; await create_timer(0.35).timeout
	check(fan.offset == settled and host.rules.phase == "play", "Releasing the bank stack stops scrolling without committing a debt")
	choices.player_buttons[0].pressed.emit()
	check(fan.offset == settled, "Changing the chosen player preserves the bank browsing position")
	host.reader.close(); host.rules.turn = 1; host.rules.revision += 1; host._publish()
	host._action(1, {"action":"debt", "card":debt, "target":0, "revision":host.rules.revision})
	check(host.rules.phase == "response", "Just Say No remains a real choice when available")
	host._action(0, {"action":"accept", "revision":host.rules.revision})
	check(host.rules.phase == "pay" and host.decision.heading.text == "Sam used Debt Collector", "Payment keeps only the sender/card heading")
	var grid: GameCardGrid = host.decision.body.get_child(1)
	check(grid.selectable and grid.entries.size() == host.rules.payment_assets(0).size() and grid.get_child(0).toggle_mode, "Payment is an actual grid of toggleable card faces")
	check(host.decision.body.get_child(0).get_theme_color("font_color") == GameLook.table_owed_color(), "The owed amount uses the shared red color")
	grid.get_child(0).pressed.emit()
	check(host.selected_payment.size() == 1 and not host.decision.actions.get_child(0).disabled, "Selecting a payment card highlights it and enables sufficient payment")
	grid.get_child(0).pressed.emit()
	check(host.selected_payment.is_empty() and host.decision.actions.get_child(0).disabled, "Selecting the same card again removes it")
	# A second valid debt tests the actual public Just Say No effect descriptor.
	host.decision.overlay.hide(); host.rules.pending.clear(); host.rules.phase = "play"; debt = take("debt-collector", 1); host.rules.revision += 1
	host._action(1, {"action":"debt","card":debt,"target":0,"revision":host.rules.revision}); host._action(0, {"action":"no","card":refusal,"revision":host.rules.revision})
	check(host._snapshot(-1).motion.effects[0].card.kind == "just-say-no" and host._snapshot(-1).motion.effects[0].label.contains("Alex"), "A cancellation spotlights the actual played Just Say No without hidden cards")
	var group: Dictionary = host.rules.properties[0][0]; group.cards.pop_back()
	var detail: Dictionary = host.table.inspector_data(0, host._snapshot(0).table[0].groups[0])
	check(detail.slots == 2 and detail.items.size() == 2 and detail.items[1].placeholder, "Incomplete sets reserve a dark card space instead of enlarging the remaining cards")
	host._show_public(0)
	check(not host.inspection.body.find_children("*","GameCardGrid",true,false).is_empty(), "Public table inspection uses actual card grids")
	host.shutdown_game(); host.queue_free(); await process_frame
	host = load("res://Games/monopoly-deal/host/main.tscn").instantiate(); root.add_child(host); host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	context = GameSessionContext.new("monopoly-deal", [], {"id":"host","display_name":"Host","color":"#2463eb"}); context.reduced_motion = true
	var starters: Array = []
	for index in 16:
		host.initialize_session(context)
		if not starters.has(host.rules.starter): starters.append(host.rules.starter)
		check(host.rules.hands[host.rules.starter].size() == 7 and host.rules.hands[(host.rules.starter + 1) % 3].size() == 5, "A random solo starter receives exactly the opening draw")
	check(starters.size() > 1 and starters.any(func(value: int) -> bool: return value > 0), "Solo can begin with different computer or human seats")
	var starter: int = host.rules.starter; host.rules.winner = 0; host._replay()
	check(host.rules.starter == (starter + 1) % 3, "Replay still rotates from the actual random starter")
	host.shutdown_game(); host.queue_free(); await process_frame
	print("Monopoly Deal polish: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
