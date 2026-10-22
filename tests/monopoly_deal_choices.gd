extends SceneTree

var checks := 0
var failures := 0
var host: Node

func _init() -> void: call_deferred("_run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)

func fixture() -> void:
	host.rules.start(4)
	for seat in 4:
		host.rules.hands[seat].clear(); host.rules.banks[seat].clear(); host.rules.properties[seat].clear(); host.rules.loose[seat].clear()
	host.rules.deck = range(host.rules.cards.size()); host.rules.discard.clear()
	host.animating = false; host.parallel_ready = false; host.motion_timer.stop(); host.ai_timer.stop(); host.decision_stamp = ""
	host._publish(); host.ai_timer.stop()

func take(key: String, seat: int, bank := false) -> int:
	var id: int = host.rules.deck.filter(func(candidate: int) -> bool: return host.rules.cards[candidate].key == key)[0]
	host.rules.deck.erase(id)
	if bank: host.rules.banks[seat].append(id)
	else: host.rules.hands[seat].append(id)
	return id

func property(key: String, seat: int, color: String) -> int:
	var id := take(key, seat); host.rules.hands[seat].erase(id); host.rules._receive_property(seat, id, color); return id

func act(seat: int, command: Dictionary) -> bool:
	var input := command.duplicate(true); input.revision = host.rules.revision; return host._action(seat, input)

func payment_from(seat: int, ids: Array) -> Dictionary:
	var view: Dictionary = host._snapshot(seat)
	var command: Dictionary = view.payment.command.duplicate(true); command.cards = ids; command.revision = view.revision; return command

func _run() -> void:
	host = load("res://Games/monopoly-deal/host/main.tscn").instantiate(); root.add_child(host)
	host.settings_store = preload("res://tests/game_settings_fixture.gd").new()
	var players: Array = []
	for index in 4: players.append({"id":"qa-%d" % index, "display_name":"Player %d" % index, "color":"#2463eb"})
	var context := GameSessionContext.new("monopoly-deal", players, {}, true); context.reduced_motion = true
	host.initialize_session(context); host.start_game(); fixture()
	var birthday := take("birthday", 0); var cash: Array = []
	for seat in range(1, 4): cash.append(take("money-2", seat, true))
	check(act(0, {"action":"birthday", "card":birthday}), "Birthday is accepted")
	check([1,2,3].all(func(seat: int) -> bool: return host._snapshot(seat).has("payment")), "All recipients can choose payment at once")
	var one := payment_from(1, [cash[0]]); var two := payment_from(2, [cash[1]]); var three := payment_from(3, [cash[2]])
	var forged := three.duplicate(true); forged.target = 1
	check(not host._action(3, forged), "A recipient cannot pay another player's branch")
	check(host._action(3, three) and host._action(1, one) and host._action(2, two), "Payments submitted from the same revision succeed in any arrival order")
	check(host.rules.phase == "play" and host.rules.banks[0].size() == 3, "The action finishes after every independent recipient resolves")
	check(not host._action(1, one), "A duplicated payment cannot transfer twice")
	check(host._snapshot(-1).actions.is_empty() and not host._snapshot(-1).has("payment"), "Public views never contain private decisions")

	fixture(); birthday = take("birthday", 0); var refusal := take("just-say-no", 1)
	for seat in [2,3]: take("money-2", seat, true)
	act(0, {"action":"birthday", "card":birthday})
	check(host._snapshot(1).phase == "response" and host._snapshot(2).phase == "pay" and host._snapshot(3).phase == "pay", "A counter choice never blocks other recipients' payments")
	two = payment_from(2, host.rules.banks[2].duplicate()); three = payment_from(3, host.rules.banks[3].duplicate())
	var counter: Dictionary = host._snapshot(1).actions.filter(func(choice: Dictionary) -> bool: return choice.payload.action == "no")[0].payload.duplicate(true)
	check(act(1, counter) and host.rules.decision_for(1).is_empty(), "An uncountered refusal cancels only its recipient's effect")
	check(host._action(3, three) and host._action(2, two) and host.rules.banks[0].size() == 2, "Unrelated payment tickets survive a cancellation and its automatic acknowledgement")

	fixture(); birthday = take("birthday", 0); refusal = take("just-say-no", 1); take("just-say-no", 0)
	take("money-2", 1, true); take("money-2", 2, true)
	act(0, {"action":"birthday", "card":birthday})
	counter = host._snapshot(1).actions.filter(func(choice: Dictionary) -> bool: return choice.payload.action == "no")[0].payload
	act(1, counter)
	check(host._snapshot(0).phase == "response" and host._snapshot(2).phase == "pay", "The sender's counter and another recipient's payment stay independent")
	var stale := counter.duplicate(true); stale.revision = host.rules.revision
	check(not host._action(1, stale), "A changed branch rejects its old response ticket even with the current global revision")
	two = payment_from(2, host.rules.banks[2].duplicate())
	counter = host._snapshot(0).actions.filter(func(choice: Dictionary) -> bool: return choice.payload.action == "no")[0].payload
	act(0, counter)
	check(host._snapshot(1).phase == "pay" and host._action(2, two), "Countering reopens only the original recipient's payment")
	check(host.rules.plays == 2, "The sender's counter still consumes a normal play")

	fixture(); context.reduced_motion = false; birthday = take("birthday", 0)
	for seat in range(1,4): take("money-2", seat, true)
	act(0, {"action":"birthday", "card":birthday}); one = payment_from(1, host.rules.banks[1].duplicate())
	check(host.animating and not host.parallel_ready and not host._action(1, one), "The initial played-card motion still locks decisions")
	host.motion_timer.stop(); host.animating = false; host._publish()
	one = payment_from(1, host.rules.banks[1].duplicate()); two = payment_from(2, host.rules.banks[2].duplicate())
	check(host._action(1, one) and host.animating and host._snapshot(2).decisions_ready, "Another recipient stays ready while a payment flies")
	var prior: Array = host.card_motion.flights.duplicate(true)
	check(host._action(2, two) and host.card_motion.flights.size() > prior.size() and host.card_motion.flights[0] == prior[0], "Concurrent payments append to the live timeline without replacing an earlier flight")
	context.reduced_motion = true
	fixture(); birthday = take("birthday", 0)
	for seat in range(1,4): take("money-2", seat, true)
	host.seats[1].ai = true; host.seats[2].ai = true; act(0, {"action":"birthday", "card":birthday}); host.ai_timer.stop(); host._computer_turn(); host.ai_timer.stop()
	check(host.rules.banks[0].size() == 2 and host.rules.decision_for(1).is_empty() and host.rules.decision_for(2).is_empty() and not host.rules.decision_for(3).is_empty(), "All ready computers respond together without waiting for a human recipient")
	host.seats[1].ai = false; host.seats[2].ai = false

	fixture(); host.host_plays = true
	var wild := property("wild-pink-orange", 0, "orange"); property("new-york-avenue", 0, "orange")
	var debt := take("debt-collector", 1); var money := take("money-10", 0, true)
	host.rules.turn = 1; act(1, {"action":"debt", "card":debt, "target":0})
	var grid: GameCardGrid = host.decision.body.get_child(1)
	check(grid.entries.any(func(entry: Dictionary) -> bool: return entry.card.id == wild and entry.card.face_side == 1), "Payment renders an orange-side-up wild exactly as it is on the table")
	var cash_index := 0
	for index in grid.entries.size():
		if grid.entries[index].card.id == money: cash_index = index
	grid.get_child(cash_index).pressed.emit()
	check(host.decision.body.get_child(0).get_theme_color("font_color") == host.screen.get_theme_color("success", "GamePalette"), "Overpayment turns the amount green and enables confirmation")
	host.decision.overlay.hide(); host._publish()
	check(not host.decision.overlay.visible, "A dismissed payment stays dismissed across unrelated publications")
	host._show_decision(true)
	check(host.decision.overlay.visible and host.selected_payment.size() == 1 and int(host.selected_payment[0]) == money, "A dismissed obligation can reopen with its selection intact")
	host.decision.overlay.hide(); host.rules.pending.clear(); host.rules.phase = "play"; host.rules.turn = 0; host.rules.revision += 1; host._publish()
	host._select_card(host.rules.public_card(wild, 0))
	check(host.reader.rotation_side == 1 and int(host.reader.card.card.face_side) == 0, "An owned public wild rotates once in the reader instead of double-flipping")

	fixture(); var sly := take("sly-deal", 0); var forced := take("forced-deal", 0)
	property("wild-pink-orange", 1, "orange"); property("new-york-avenue", 2, "orange"); property("mediterranean-avenue", 0, "brown"); property("boardwalk", 0, "dark-blue"); property("park-place", 0, "dark-blue")
	var choices: Array = host.rules.tap_choices(0, sly); var previews: Array = host._preview_options(host.rules.cards[sly], choices)
	check(previews.size() == 2 and previews.all(func(item: Dictionary) -> bool: return item.groups.size() == 1 and item.groups[0].items.size() == 1), "Sly Deal previews include every eligible property under its owner")
	host._select_card(host.rules.cards[forced])
	check(host.reader.preview.presentation == "cards" and not host.reader.preview.selector.visible and host.reader.preview.card_groups.size() == 5, "Forced Deal shows all give and take cards without a dropdown or duplicated combinations")
	var selection: Dictionary = host.reader.preview.card_groups.filter(func(group: Dictionary) -> bool: return group.key == "take" and group.owner == 2)[0]
	host.reader.preview._select_group(selection)
	var selected: int = host.reader.preview.selected
	check(host.rules.tap_choices(0, forced)[selected].payload.target == 2 and host.rules.phase == "play", "A public card selection maps to an offered action and never plays automatically")
	host.reader.close()
	var snapshot: Dictionary = host.rules.view_for(0)
	check(snapshot.table[0].groups[0].cards.size() == 2 and host.rules.properties[0][0].cards.size() == 1, "Public sets are sorted by card count without changing authoritative groups")
	host.shutdown_game(); host.queue_free(); await process_frame
	print("Monopoly Deal independent choices: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
